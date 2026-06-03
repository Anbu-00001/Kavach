// main.dart — Kavach app: state, navigation, and the live demo timeline.
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'data.dart';
import 'screens.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'store.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;
import 'engine/kavach_engine.dart';
import 'engine/live_listener.dart';
import 'engine/whisper_listener.dart';
import 'engine/guardian_service.dart';
import 'native/call_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    so.initBindings(); // load sherpa-onnx native bindings (Whisper multilingual ASR)
    debugPrint('KAVACH_SHERPA_INIT: ok');
  } catch (e, st) {
    debugPrint('KAVACH_SHERPA_INIT_FAILED: $e\n$st');
  }
  await configureGuardian(); // set up the background guardian service (not started)
  final store = await Store.load();
  runApp(KavachApp(store: store));
}

class KavachApp extends StatefulWidget {
  final Store store;
  const KavachApp({super.key, required this.store});
  @override
  State<KavachApp> createState() => _KavachAppState();
}

class _KavachAppState extends State<KavachApp> {
  late String screen;
  late bool dark;
  double scale = 1.0;
  final Color accent = hx('#0E7C86');
  late String watchword;
  late String? guardian;
  late bool armed;
  bool demoActive = false;
  bool minimal = false;
  Verdict live = buildVerdict('HIGH');

  Store get _store => widget.store;

  // Real on-device detection engine (ONNX + tokenizer + fusion). Loaded async;
  // null until ready. The demo falls back to canned beats if it isn't loaded.
  KavachEngine? engine;
  String? engineError;
  bool get engineReady => engine?.ready ?? false;

  // Multilingual tier (118MB XLM-R + Rust SentencePiece). Loaded lazily on demand.
  KavachEngine? mlEngine;
  bool mlLoading = false;
  String? mlError;
  bool get mlReady => mlEngine?.ready ?? false;

  // Live mic → ASR → engine (Layer 1). English uses Vosk (streaming); every other
  // language uses Whisper (sherpa-onnx). Both implement CallAudioListener.
  CallAudioListener? liveListener;
  bool liveStarting = false;
  String? liveError;
  String liveLang = 'en'; // 'en' = Vosk+MiniLM; others = Whisper+multilingual tier

  // Background guardian (Layer 2): foreground service streaming verdicts to the UI.
  bool guarding = false;
  StreamSubscription<Map<String, dynamic>?>? _guardSub;

  @override
  void initState() {
    super.initState();
    // Hydrate from disk: returning users skip onboarding and keep their setup.
    watchword = _store.watchword;
    guardian = _store.guardian;
    armed = _store.armed;
    dark = _store.dark;
    screen = _store.onboarded ? 'home' : 'onboarding';
    _loadEngine();
    _initCallGuard();
  }

  /// Layer 0: when "Shield this call" is tapped on the unknown-call overlay, the
  /// native side either launches us cold with a durable flag or invokes
  /// startGuard warm. Honour both so the guard actually starts.
  Future<void> _initCallGuard() async {
    CallGuard.onStartGuard(() {
      if (mounted) startGuard();
    });
    if (await CallGuard.consumePendingGuard() && mounted) startGuard();
  }

  Future<void> _loadEngine() async {
    final sw = Stopwatch()..start();
    try {
      final e = await KavachEngine.load();
      debugPrint('KAVACH_ENGINE_READY in ${sw.elapsedMilliseconds}ms');
      if (mounted) setState(() => engine = e);
    } catch (err, st) {
      debugPrint('KAVACH_ENGINE_LOAD_FAILED after ${sw.elapsedMilliseconds}ms: $err\n$st');
      if (mounted) setState(() => engineError = '$err');
    }
  }

  /// Lazy-load the multilingual tier the first time it's requested.
  Future<void> _loadMultilingual() async {
    if (mlEngine != null || mlLoading) return;
    setState(() => mlLoading = true);
    try {
      final e = await KavachEngine.loadMultilingual();
      if (mounted) setState(() => mlEngine = e);
    } catch (err, st) {
      debugPrint('KAVACH_ML_LOAD_FAILED: $err\n$st');
      if (mounted) setState(() => mlError = '$err');
    } finally {
      if (mounted) setState(() => mlLoading = false);
    }
  }

  /// Run the real model on [text] (English or multilingual tier); null if not
  /// ready. Uses analyzeDetailed so the result card can show the words the model
  /// actually keyed on (occlusion attribution) — not latency-critical here.
  EngineResult? analyzeWith(String text, bool multilingual) {
    if (multilingual) return mlReady ? mlEngine!.analyzeDetailed(text) : null;
    return engineReady ? engine!.analyzeDetailed(text) : null;
  }

  /// Start REAL live capture: mic → Vosk → engine → live shield.
  Future<void> startLive({String lang = 'en'}) async {
    if (liveStarting) return;
    // Resolve the detection engine for this language: English uses the MiniLM
    // tier; any other language uses the multilingual XLM-R tier (lazy-loaded).
    KavachEngine? eng;
    if (lang == 'en') {
      if (!engineReady) return;
      eng = engine;
    } else {
      setState(() {
        liveStarting = true;
        liveError = null;
      });
      if (!mlReady) await _loadMultilingual();
      if (!mlReady) {
        if (mounted) {
          setState(() {
            liveStarting = false;
            liveError = 'Couldn’t load the multilingual model for live voice.';
          });
        }
        return;
      }
      eng = mlEngine;
    }
    // Switching language needs a fresh listener (engine + ASR backend change:
    // English → Vosk streaming, any other language → Whisper).
    if (liveListener != null && liveLang != lang) {
      await liveListener!.stop();
      liveListener = null;
    }
    liveLang = lang;
    var ll = liveListener;
    if (ll == null) {
      ll = lang == 'en' ? LiveListener(eng!) : WhisperListener(eng!, language: lang);
      ll.onUpdate = _onLiveUpdate;
      ll.onError = (e) {
        if (mounted) setState(() => liveError = e);
      };
      liveListener = ll;
    }
    setState(() {
      liveError = null;
      liveStarting = true;
    });
    final granted = await ll.ensurePermission();
    if (!granted) {
      if (mounted) {
        setState(() {
          liveStarting = false;
          liveError = 'Microphone permission is needed to listen to the call.';
        });
      }
      return;
    }
    try {
      armed = true;
      _store.armed = true;
      await ll.start(); // unzips + loads the Vosk model on first run
      _onLiveUpdate();
      if (mounted) {
        setState(() {
          liveStarting = false;
          demoActive = false;
          screen = 'live';
        });
      }
    } catch (e, st) {
      debugPrint('KAVACH_LIVE_START_FAILED: $e\n$st');
      if (mounted) {
        setState(() {
          liveStarting = false;
          liveError = '$e';
        });
      }
    }
  }

  /// Start the always-on background guardian (foreground service).
  Future<void> startGuard() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) setState(() => liveError = 'Microphone permission is needed to guard your calls.');
      return;
    }
    // Android 13+/OEM ROMs REQUIRE a postable notification for a foreground
    // service — without POST_NOTIFICATIONS the service crashes on startForeground.
    final notif = await Permission.notification.request();
    if (!notif.isGranted) {
      if (mounted) setState(() => liveError = 'Please allow notifications — the always-on guard needs a visible notice to keep running.');
      return;
    }
    final svc = FlutterBackgroundService();
    _guardSub ??= svc.on('verdict').listen(_onGuardVerdict);
    await svc.startService();
    armed = true;
    _store.armed = true;
    if (mounted) {
      setState(() {
        liveError = null;
        guarding = true;
        demoActive = false;
        live = Verdict('SAFE', const [], const [], deriveExp('SAFE', const []), 'idle', 0.0, live: true);
        screen = 'live';
      });
    }
  }

  void stopGuard() {
    FlutterBackgroundService().invoke('stop');
    _guardSub?.cancel();
    _guardSub = null;
    if (mounted) setState(() => guarding = false);
  }

  /// Update the live shield from a verdict pushed by the background isolate.
  void _onGuardVerdict(Map<String, dynamic>? data) {
    if (data == null || !mounted) return;
    final level = data['level'] as String? ?? 'SAFE';
    final score = (data['score'] as num?)?.toDouble() ?? 0.0;
    final tactics = (data['tactics'] as List?)?.cast<String>() ?? const <String>[];
    final tr = (data['transcript'] as List?)?.cast<String>() ?? const <String>[];
    final lines = [for (final u in tr) {'who': 'them', 'line': u}];
    if (kDebugMode) debugPrint('KAVACH_UI guard verdict: $level ${score.toStringAsFixed(2)} beat=${data['beat']}');
    setState(() => live = Verdict(level, lines, tactics, deriveExp(level, tactics), level == 'HIGH' ? 'sent' : 'idle', score, live: true));
  }

  /// Rebuild the live shield from the listener's rolling-peak verdict + transcript.
  void _onLiveUpdate() {
    final ll = liveListener;
    if (ll == null) return;
    final r = ll.peak;
    final lines = <Map<String, String>>[
      for (final u in ll.transcript) {'who': 'them', 'line': u},
      if (ll.partial != null && ll.partial!.isNotEmpty) {'who': 'them', 'line': ll.partial!},
    ];
    final level = r?.level ?? 'SAFE';
    final tactics = r?.tactics ?? const <String>[];
    final guardian = level == 'HIGH' ? 'sent' : 'idle';
    if (mounted) {
      setState(() => live = Verdict(level, lines, tactics, deriveExp(level, tactics), guardian, r?.score ?? 0.0, live: true));
    }
  }

  String sumLevel = 'HIGH';
  List<String> sumTactics = kVerdicts['HIGH']!.tactics;
  String sumGuardian = 'sent';

  final List<Timer> _timers = [];
  void _clear() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void go(String s) {
    if (s != 'live') {
      _clear();
      demoActive = false;
    }
    setState(() => screen = s);
  }

  /// Play the cloned-voice "grandson in trouble" demo: SAFE → CAUTION → HIGH.
  void startDemo() {
    _clear();
    demoActive = true;
    armed = true;
    _store.armed = true;
    setState(() => screen = 'live');
    final acc = <Map<String, String>>[];
    // Running peak: a call only ever escalates within itself (advisory behaviour),
    // which also keeps the shield monotonic during the staged playback.
    var peakScore = -1.0;
    var peakLevel = 'SAFE';
    var peakTactics = const <String>[];
    for (final beat in kDemoBeats) {
      _timers.add(Timer(Duration(milliseconds: beat.at), () {
        if (beat.who == 'them') acc.add({'who': beat.who, 'line': beat.line});
        // REAL on-device inference on each caller line when the model is loaded;
        // fall back to the scripted beat values otherwise (e.g. headless tests).
        var level = beat.level;
        var tactics = beat.tactics;
        var score = beat.score;
        if (engineReady && beat.who == 'them') {
          final r = engine!.analyze(beat.line);
          level = r.level;
          tactics = r.tactics;
          score = r.score;
        }
        if (score > peakScore) {
          peakScore = score;
          peakLevel = level;
          peakTactics = tactics;
        }
        setState(() {
          live = Verdict(
            peakLevel,
            acc.where((l) => l['who'] == 'them').toList(),
            peakTactics,
            deriveExp(peakLevel, peakTactics),
            beat.guardian, // alert narration stays on the scripted timeline
            peakScore,
            live: true,
          );
        });
      }));
    }
  }

  void onHangup() {
    _clear();
    liveListener?.stop();
    if (guarding) stopGuard();
    demoActive = false;
    setState(() {
      sumLevel = live.level;
      sumTactics = live.tactics;
      sumGuardian = live.guardian;
      screen = 'summary';
    });
  }

  void onSafe() {
    _clear();
    liveListener?.stop();
    if (guarding) stopGuard();
    demoActive = false;
    armed = true;
    _store.armed = true;
    setState(() => screen = 'home');
  }

  @override
  void dispose() {
    _clear();
    liveListener?.stop();
    _guardSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = palette(dark, accent);
    Widget body;
    switch (screen) {
      case 'watchword':
        body = WatchwordScreen(
            watchword: watchword,
            onChanged: (v) => setState(() {
                  watchword = v;
                  _store.watchword = v;
                }),
            onBack: () => go('onboarding'),
            onSave: () => go('guardian'));
        break;
      case 'guardian':
        body = GuardianScreen(
            guardian: guardian,
            onSelect: (v) => setState(() {
                  guardian = v;
                  _store.guardian = v;
                }),
            onBack: () => go('watchword'),
            onFinish: () {
              _store.onboarded = true;
              go('home');
            });
        break;
      case 'home':
        body = HomeScreen(
            armed: armed,
            watchword: watchword,
            guardian: guardian,
            onArm: () => setState(() {
                  armed = true;
                  _store.armed = true;
                }),
            onStop: () => setState(() {
                  armed = false;
                  _store.armed = false;
                }),
            onDemo: startDemo,
            onTry: () => go('analyze'),
            onLive: () => startLive(lang: liveLang),
            liveLang: liveLang,
            onLiveLang: (l) => setState(() => liveLang = l),
            onGuard: startGuard,
            guarding: guarding,
            liveStarting: liveStarting,
            liveError: liveError,
            onCallShield: () => go('callshield'),
            onProfile: () => go('onboarding'));
        break;
      case 'analyze':
        body = AnalyzeScreen(
          engineReady: engineReady,
          engineError: engineError,
          mlReady: mlReady,
          mlLoading: mlLoading,
          mlError: mlError,
          loadMultilingual: _loadMultilingual,
          analyze: analyzeWith,
          onBack: () => go('home'),
        );
        break;
      case 'callshield':
        body = CallShieldScreen(onBack: () => go('home'));
        break;
      case 'live':
        body = LiveShieldScreen(v: live, watchword: watchword, guardianName: guardian, minimal: minimal, onHangup: onHangup, onSafe: onSafe);
        break;
      case 'summary':
        body = SummaryScreen(level: sumLevel, guardianStatus: sumGuardian, tactics: sumTactics, guardianName: guardian, onHome: () => go('home'));
        break;
      default:
        body = OnboardingScreen(onTurnOn: () => go('watchword'));
    }

    final lightIcons = dark || (screen == 'live' && live.level != 'CAUTION');
    return MaterialApp(
      title: 'Kavach',
      debugShowCheckedModeBanner: false,
      home: KavachTheme(
        pal: pal,
        scale: scale,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: lightIcons
              ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
              : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: pal.bg,
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(screen), child: body),
            ),
          ),
        ),
      ),
    );
  }
}
