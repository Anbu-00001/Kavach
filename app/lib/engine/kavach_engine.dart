// kavach_engine.dart — the real on-device detection pipeline.
//
//   text → tokenize → ONNX classifier → 8 tactic probs → fusion → Verdict
//
// Two tiers share this pipeline:
//   • English  — WordPiece (pure Dart) + the 22MB MiniLM model.
//   • Multi    — SentencePiece via the Rust FFI lib + the 118MB XLM-R model
//                (12 languages incl. Hindi/Tamil), loaded lazily.
//
// This is the Dart mirror of core/kavach_engine.py and app/rust/kavach_core.
// Everything runs locally; nothing is written to disk or sent over the network.
import 'package:flutter/services.dart' show rootBundle;
import '../data.dart';
import 'wordpiece.dart';
import 'fusion.dart';
import 'classifier.dart';
import 'sp_tokenizer.dart';

/// A tokenize step: text → (input_ids, attention_mask).
typedef Encode = ({List<int> inputIds, List<int> attentionMask}) Function(String text);

/// One real model verdict: the fused risk plus the raw probabilities behind it
/// (kept so the UI can be transparent about *why* — never fabricated).
class EngineResult {
  final String level; // SAFE | CAUTION | HIGH
  final double score;
  final List<String> tactics; // fired ids, most decisive first
  final List<double> probs; // all 8, label order
  const EngineResult(this.level, this.score, this.tactics, this.probs);

  /// Adapt to the UI's Verdict (explanations are pre-vetted, never generated).
  Verdict toVerdict(List<Map<String, String>> transcript, String guardian, {bool live = true}) =>
      Verdict(level, transcript, tactics, deriveExp(level, tactics), guardian, score, live: live);
}

class KavachEngine {
  final Encode _encode;
  final Fusion _fusion;
  final OnnxClassifier _clf;
  final SpTokenizer? _sp; // non-null only for the multilingual tier (for disposal)

  KavachEngine._(this._encode, this._fusion, this._clf, {SpTokenizer? sp}) : _sp = sp;

  bool get ready => _clf.ready;
  List<String> get tacticOrder => _fusion.order;

  /// English tier: WordPiece + 22MB MiniLM. Fast; loaded at startup.
  static Future<KavachEngine> load() async {
    final vocabTxt = await rootBundle.loadString('assets/model/vocab.txt');
    final taxonomy = await rootBundle.loadString('assets/model/taxonomy.json');
    final modelData = await rootBundle.load('assets/model/intent.int8.onnx');
    final wp = WordPiece.fromVocabText(vocabTxt);
    final clf = OnnxClassifier()
      ..init(modelData.buffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes));
    return KavachEngine._((t) => wp.encode(t, maxLen: 48), Fusion.fromTaxonomyJson(taxonomy), clf);
  }

  /// Multilingual tier: Rust SentencePiece tokenizer + 118MB XLM-R model.
  /// Bigger + slower → loaded lazily, only when the user asks for it.
  static Future<KavachEngine> loadMultilingual() async {
    final taxonomy = await rootBundle.loadString('assets/model/taxonomy.json');
    final tokJson = await rootBundle.load('assets/model/intent_ml.tokenizer.json');
    final modelData = await rootBundle.load('assets/model/intent_ml.int8.onnx');
    final sp = SpTokenizer.fromJson(
        tokJson.buffer.asUint8List(tokJson.offsetInBytes, tokJson.lengthInBytes));
    final clf = OnnxClassifier()
      ..init(modelData.buffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes));
    return KavachEngine._(sp.encode, Fusion.fromTaxonomyJson(taxonomy), clf, sp: sp);
  }

  /// Analyze a single utterance/window of transcript text.
  EngineResult analyze(String text, {double acoustic = 0.0}) {
    final enc = _encode(text);
    final probs = _clf.classify(enc.inputIds, enc.attentionMask);
    final v = _fusion.assess(probs, acoustic: acoustic);
    return EngineResult(v.level, v.score, v.tactics, probs);
  }

  void dispose() {
    _clf.dispose();
    _sp?.dispose();
  }
}
