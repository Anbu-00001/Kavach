// kavach_engine.dart — the real on-device detection pipeline.
//
//   text → WordPiece tokenize → ONNX classifier → 8 tactic probs → fusion → Verdict
//
// This is the Dart mirror of core/kavach_engine.py and app/rust/kavach_core.
// Everything runs locally; the only inputs are bundled assets and the live
// transcript text, and nothing is written to disk or sent over the network.
import 'package:flutter/services.dart' show rootBundle;
import '../data.dart';
import 'wordpiece.dart';
import 'fusion.dart';
import 'classifier.dart';

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
  final WordPiece _tok;
  final Fusion _fusion;
  final OnnxClassifier _clf;
  static const int maxLen = 48; // matches core/kavach_engine.py MAX_LEN

  KavachEngine._(this._tok, this._fusion, this._clf);

  bool get ready => _clf.ready;
  List<String> get tacticOrder => _fusion.order;

  /// Load vocab + taxonomy + model from assets and warm up ORT.
  static Future<KavachEngine> load() async {
    final vocabTxt = await rootBundle.loadString('assets/model/vocab.txt');
    final taxonomy = await rootBundle.loadString('assets/model/taxonomy.json');
    final modelData = await rootBundle.load('assets/model/intent.int8.onnx');
    final clf = OnnxClassifier()
      ..init(modelData.buffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes));
    return KavachEngine._(
      WordPiece.fromVocabText(vocabTxt),
      Fusion.fromTaxonomyJson(taxonomy),
      clf,
    );
  }

  /// Analyze a single utterance/window of transcript text.
  EngineResult analyze(String text, {double acoustic = 0.0}) {
    final enc = _tok.encode(text, maxLen: maxLen);
    final probs = _clf.classify(enc.inputIds, enc.attentionMask);
    final v = _fusion.assess(probs, acoustic: acoustic);
    return EngineResult(v.level, v.score, v.tactics, probs);
  }

  /// For tests/diagnostics: tokenize only (no model needed).
  ({List<int> inputIds, List<int> attentionMask}) tokenize(String text) =>
      _tok.encode(text, maxLen: maxLen);

  void dispose() => _clf.dispose();

  /// Build a tokenizer+fusion engine from raw strings (no ONNX) — used by tests
  /// to verify the pure-Dart layers against the Python fixtures.
  static KavachEngine forParity(String vocabTxt, String taxonomyJson) =>
      KavachEngine._(WordPiece.fromVocabText(vocabTxt), Fusion.fromTaxonomyJson(taxonomyJson), OnnxClassifier());
}
