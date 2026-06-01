// main.dart — Kavach app: state, navigation, and the live demo timeline.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'data.dart';
import 'screens.dart';

void main() => runApp(const KavachApp());

class KavachApp extends StatefulWidget {
  const KavachApp({super.key});
  @override
  State<KavachApp> createState() => _KavachAppState();
}

class _KavachAppState extends State<KavachApp> {
  String screen = 'onboarding';
  bool dark = false;
  double scale = 1.0;
  final Color accent = hx('#0E7C86');
  String watchword = 'Marigold';
  String? guardian = 'Priya';
  bool armed = false;
  bool demoActive = false;
  bool minimal = false;
  Verdict live = buildVerdict('HIGH');

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
    setState(() => screen = 'live');
    final acc = <Map<String, String>>[];
    for (final beat in kDemoBeats) {
      _timers.add(Timer(Duration(milliseconds: beat.at), () {
        if (beat.who == 'them') acc.add({'who': beat.who, 'line': beat.line});
        setState(() {
          live = Verdict(
            beat.level,
            acc.where((l) => l['who'] == 'them').toList(),
            beat.tactics,
            deriveExp(beat.level, beat.tactics),
            beat.guardian,
            beat.score,
            live: true,
          );
        });
      }));
    }
  }

  void onHangup() {
    _clear();
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
    demoActive = false;
    armed = true;
    setState(() => screen = 'home');
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = palette(dark, accent);
    Widget body;
    switch (screen) {
      case 'watchword':
        body = WatchwordScreen(watchword: watchword, onChanged: (v) => setState(() => watchword = v), onBack: () => go('onboarding'), onSave: () => go('guardian'));
        break;
      case 'guardian':
        body = GuardianScreen(guardian: guardian, onSelect: (v) => setState(() => guardian = v), onBack: () => go('watchword'), onFinish: () => go('home'));
        break;
      case 'home':
        body = HomeScreen(armed: armed, watchword: watchword, guardian: guardian, onArm: () => setState(() => armed = true), onStop: () => setState(() => armed = false), onDemo: startDemo, onProfile: () => go('onboarding'));
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
