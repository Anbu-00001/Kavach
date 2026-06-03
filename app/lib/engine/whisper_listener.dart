// whisper_listener.dart — the universal-language live path (Layer 1, non-English).
//
//   mic (record PCM16) → Silero VAD → Whisper (sherpa-onnx) → KavachEngine
//
// Whisper-tiny multilingual covers Tamil + every Indian language + ~99 more, so
// one model handles any language Vosk can't. It's non-streaming, so we segment
// speech with Silero VAD and transcribe each utterance when the speaker pauses.
// Still 100% offline — sherpa-onnx runs the ONNX model on-device; nothing leaves.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;
import 'kavach_engine.dart';
import 'live_listener.dart' show CallAudioListener;

class WhisperListener implements CallAudioListener {
  final KavachEngine engine; // multilingual XLM-R tier
  final String language; // Whisper language code: 'hi','ta','te',… ('' = auto)
  WhisperListener(this.engine, {required this.language});

  static const _assets = ['encoder.int8.onnx', 'decoder.int8.onnx', 'tokens.txt', 'silero_vad.onnx'];
  static const _sampleRate = 16000;

  final _rec = AudioRecorder();
  so.OfflineRecognizer? _recognizer;
  so.VoiceActivityDetector? _vad;
  StreamSubscription<Uint8List>? _audioSub;
  bool _running = false;

  // ── live outputs (read by the UI on each onUpdate) ──
  @override
  final List<String> transcript = [];
  @override
  String? partial;
  @override
  EngineResult? peak;
  @override
  void Function()? onUpdate;
  @override
  void Function(String error)? onError;

  @override
  bool get running => _running;

  @override
  Future<bool> ensurePermission() async => (await Permission.microphone.request()).isGranted;

  @override
  Future<void> start() async {
    if (_running) return;
    reset();
    final dir = await _ensureModels();

    _recognizer = so.OfflineRecognizer(so.OfflineRecognizerConfig(
      model: so.OfflineModelConfig(
        whisper: so.OfflineWhisperModelConfig(
          encoder: '$dir/encoder.int8.onnx',
          decoder: '$dir/decoder.int8.onnx',
          language: language,
          task: 'transcribe',
        ),
        tokens: '$dir/tokens.txt',
        numThreads: 2,
        debug: false,
      ),
    ));
    _vad = so.VoiceActivityDetector(
      config: so.VadModelConfig(
        sileroVad: so.SileroVadModelConfig(
          model: '$dir/silero_vad.onnx',
          minSilenceDuration: 0.4,
          minSpeechDuration: 0.25,
          maxSpeechDuration: 8.0,
        ),
        sampleRate: _sampleRate,
        numThreads: 1,
      ),
      bufferSizeInSeconds: 30,
    );

    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));
    _audioSub = stream.listen(_onAudio, onError: (e) => onError?.call('$e'));
    _running = true;
    if (kDebugMode) debugPrint('KAVACH_WHISPER_READY: listening ($language)');
    onUpdate?.call();
  }

  void _onAudio(Uint8List bytes) {
    if (!_running || _vad == null) return;
    _vad!.acceptWaveform(_toFloat32(bytes));
    // Whisper is non-streaming: transcribe each completed utterance.
    while (!_vad!.isEmpty()) {
      final seg = _vad!.front();
      _vad!.pop();
      _decode(seg.samples);
    }
  }

  void _decode(Float32List samples) {
    if (_recognizer == null || samples.isEmpty) return;
    try {
      final s = _recognizer!.createStream();
      s.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      _recognizer!.decode(s);
      final text = _recognizer!.getResult(s).text.trim();
      s.free();
      if (text.isEmpty) return;
      transcript.add(text);
      while (transcript.length > 6) {
        transcript.removeAt(0);
      }
      final r = engine.analyze(text);
      final isPeak = peak == null || r.score > peak!.score;
      if (isPeak) peak = r;
      if (kDebugMode) {
        debugPrint('KAVACH_WHISPER "$text" -> ${r.level} ${r.score.toStringAsFixed(2)} ${r.tactics}${isPeak ? '  [PEAK]' : ''}');
      }
      onUpdate?.call();
    } catch (e) {
      onError?.call('$e');
    }
  }

  // PCM16 little-endian bytes → Float32 samples in [-1, 1].
  Float32List _toFloat32(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final n = bytes.lengthInBytes ~/ 2;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  // Copy the bundled Whisper + VAD models to a file path sherpa-onnx can read.
  Future<String> _ensureModels() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/whisper');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final name in _assets) {
      final f = File('${dir.path}/$name');
      if (!f.existsSync() || f.lengthSync() == 0) {
        final data = await rootBundle.load('assets/models/whisper/$name');
        await f.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
    }
    return dir.path;
  }

  @override
  void reset() {
    transcript.clear();
    partial = null;
    peak = null;
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _rec.stop();
    } catch (_) {}
    _vad?.free();
    _vad = null;
    _recognizer?.free();
    _recognizer = null;
  }
}
