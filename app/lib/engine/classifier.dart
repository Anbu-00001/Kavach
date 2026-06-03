// classifier.dart — the on-device ONNX scam-tactic model.
//
// Loads the quantized int8 MiniLM classifier (bundled asset, ~22MB) into
// ONNX Runtime and maps (input_ids, attention_mask) → 8 per-tactic
// probabilities. Runs fully offline; the model never leaves the device and no
// audio/text is transmitted anywhere.
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxClassifier {
  OrtSession? _session;
  bool get ready => _session != null;

  /// Initialize ORT and load the model from raw bytes (read from assets).
  void init(Uint8List modelBytes) {
    // We ship ONE onnxruntime — sherpa-onnx's 1.13.0 (so Whisper's native lib
    // links) — and this plugin defaults to requesting API v14, which 1.13.0
    // doesn't provide. Pin it to v13 so the classifier runs on the same runtime.
    // Must be set BEFORE the first OrtEnv.instance access (it caps the version).
    OrtEnv.setApiVersion(OrtApiVersion.api13);
    OrtEnv.instance.init();
    _session = OrtSession.fromBuffer(modelBytes, OrtSessionOptions());
  }

  /// Returns 8 probabilities (sigmoid of the multi-label logits), in label order.
  List<double> classify(List<int> inputIds, List<int> attentionMask) {
    final session = _session;
    if (session == null) throw StateError('classifier not initialized');
    final shape = [1, inputIds.length];
    final ids = OrtValueTensor.createTensorWithDataList([Int64List.fromList(inputIds)], shape);
    final mask = OrtValueTensor.createTensorWithDataList([Int64List.fromList(attentionMask)], shape);
    List<OrtValue?> outs = const [];
    try {
      outs = session.run(OrtRunOptions(), {'input_ids': ids, 'attention_mask': mask});
      final raw = (outs.first!.value as List).first as List; // [1,8] → [8]
      return [for (final l in raw) _sigmoid((l as num).toDouble())];
    } finally {
      ids.release();
      mask.release();
      for (final o in outs) {
        o?.release();
      }
    }
  }

  void dispose() {
    _session?.release();
    _session = null;
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));
}
