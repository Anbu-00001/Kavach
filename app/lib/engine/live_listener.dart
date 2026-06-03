// live_listener.dart — the real call-audio pipeline (Layer 1).
//
//   mic (AudioRecord) → Vosk offline ASR → KavachEngine → rolling-peak verdict
//
// Fully offline: Vosk runs from a bundled model, the classifier is on-device,
// nothing is recorded to disk or sent anywhere. Drives the live shield with the
// same engine the "Try it yourself" screen uses — so the live call is real, not
// scripted. (Android mutes the remote party during a telephony call, so this is
// an *ambient* guardian: the call is on speaker and the mic hears both sides.)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'kavach_engine.dart';

/// Shared surface for the two live-audio backends so the UI can hold either:
///   • [LiveListener]    — Vosk streaming (English + the guardian)
///   • WhisperListener   — sherpa-onnx Whisper (every other language)
abstract class CallAudioListener {
  List<String> get transcript;
  String? get partial;
  EngineResult? get peak;
  bool get running;
  set onUpdate(void Function()? cb);
  set onError(void Function(String error)? cb);
  Future<bool> ensurePermission();
  Future<void> start();
  Future<void> stop();
  void reset();
}

class LiveListener implements CallAudioListener {
  final KavachEngine engine; // detection tier (English MiniLM, or multilingual XLM-R)
  // The offline Vosk ASR model for this language. English by default; pass a
  // bundled per-language model (e.g. Hindi) for genuine multilingual live voice.
  final String modelAsset;
  LiveListener(this.engine,
      {this.modelAsset = 'assets/models/vosk-model-small-en-us-0.15.zip'});

  static const _partialThrottle = Duration(milliseconds: 500);

  final _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speech;
  StreamSubscription<String>? _resSub, _partSub;
  bool _running = false;
  DateTime _lastPartialClassify = DateTime.fromMillisecondsSinceEpoch(0);

  // ── live outputs (read by the UI on each onUpdate) ──
  final List<String> transcript = []; // recent finalized caller utterances
  String? partial; // in-progress utterance
  EngineResult? peak; // highest-risk verdict seen this session
  void Function()? onUpdate;
  void Function(String error)? onError;

  bool get running => _running;

  /// Ask for the mic permission (shows the system dialog the first time).
  Future<bool> ensurePermission() async => (await Permission.microphone.request()).isGranted;

  /// Load the Vosk model (unzips ~40MB on first run) and start streaming.
  Future<void> start() async {
    if (_running) return;
    reset();
    final modelPath = await ModelLoader().loadFromAssets(modelAsset);
    _model = await _vosk.createModel(modelPath);
    _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
    _speech = await _vosk.initSpeechService(_recognizer!);
    _partSub = _speech!.onPartial().listen(_onPartial);
    _resSub = _speech!.onResult().listen(_onResult);
    await _speech!.start();
    _running = true;
    if (kDebugMode) debugPrint('KAVACH_LIVE_READY: listening');
    onUpdate?.call();
  }

  void _onPartial(String json) {
    final text = _field(json, 'partial');
    if (text.isEmpty) return;
    partial = text;
    // Throttle inference on partials — they fire many times per second.
    final now = DateTime.now();
    if (now.difference(_lastPartialClassify) >= _partialThrottle) {
      _lastPartialClassify = now;
      _classify(text);
    } else {
      onUpdate?.call();
    }
  }

  void _onResult(String json) {
    final text = _field(json, 'text');
    partial = null;
    if (text.isEmpty) {
      onUpdate?.call();
      return;
    }
    transcript.add(text);
    while (transcript.length > 6) {
      transcript.removeAt(0);
    }
    _classify(text);
  }

  void _classify(String text) {
    try {
      final r = engine.analyze(text);
      final isPeak = peak == null || r.score > peak!.score;
      if (isPeak) peak = r;
      if (kDebugMode) {
        debugPrint('KAVACH_LIVE "$text" -> ${r.level} ${r.score.toStringAsFixed(2)} ${r.tactics}${isPeak ? '  [PEAK]' : ''}');
      }
      onUpdate?.call();
    } catch (e) {
      onError?.call('$e');
    }
  }

  String _field(String json, String key) {
    try {
      return ((jsonDecode(json) as Map)[key] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  void reset() {
    transcript.clear();
    partial = null;
    peak = null;
  }

  Future<void> stop() async {
    _running = false;
    await _partSub?.cancel();
    await _resSub?.cancel();
    _partSub = null;
    _resSub = null;
    try {
      await _speech?.stop();
      await _speech?.dispose();
    } catch (_) {}
    _recognizer?.dispose();
    _speech = null;
    _recognizer = null;
    _model = null;
  }
}
