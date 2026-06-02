// asr_test.dart — full ASR→engine proof ON THE DEVICE, deterministically.
// Feeds real 16kHz speech clips straight into the phone's Vosk recognizer
// (the ARM build, same model the live mic uses), then runs the transcript
// through KavachEngine — so we verify the real chain without needing a human
// to speak. Run: flutter test integration_test/asr_test.dart -d <deviceId>
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:kavach/engine/kavach_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on-device Vosk transcribes speech → engine verdict', (tester) async {
    final vosk = VoskFlutterPlugin.instance();
    final modelPath = await ModelLoader().loadFromAssets('assets/models/vosk-model-small-en-us-0.15.zip');
    final model = await vosk.createModel(modelPath);
    final engine = await KavachEngine.load();

    Future<String> transcribe(String asset) async {
      final rec = await vosk.createRecognizer(model: model, sampleRate: 16000);
      final wav = (await rootBundle.load(asset)).buffer.asUint8List();
      final pcm = wav.sublist(44); // strip the WAV header → raw PCM16
      const chunk = 8000;
      for (var i = 0; i < pcm.length; i += chunk) {
        final end = (i + chunk < pcm.length) ? i + chunk : pcm.length;
        await rec.acceptWaveformBytes(Uint8List.sublistView(pcm, i, end));
      }
      final text = (jsonDecode(await rec.getFinalResult()) as Map)['text'] as String? ?? '';
      rec.dispose();
      return text.trim();
    }

    // ── scam clip → HIGH ──
    final scamText = await transcribe('assets/test/scam_en.wav');
    // ignore: avoid_print
    print('ASR[scam] heard: "$scamText"');
    expect(scamText, isNotEmpty, reason: 'Vosk produced no transcript');
    final scam = engine.analyze(scamText);
    // ignore: avoid_print
    print('ASR[scam] verdict: ${scam.level} ${scam.score.toStringAsFixed(2)} ${scam.tactics}');
    expect(scam.level, 'HIGH');

    // ── legit clip → SAFE ──
    final legitText = await transcribe('assets/test/legit_en.wav');
    // ignore: avoid_print
    print('ASR[legit] heard: "$legitText"');
    final legit = engine.analyze(legitText);
    // ignore: avoid_print
    print('ASR[legit] verdict: ${legit.level} ${legit.score.toStringAsFixed(2)}');
    expect(legit.level, 'SAFE');

    engine.dispose();
  });
}
