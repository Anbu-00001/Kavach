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
  // The actual words the MODEL relied on for each fired tactic, surfaced by
  // on-device occlusion attribution (see analyzeDetailed). Grounds the verdict
  // in what was really said — not a canned line, never an LLM. May be empty.
  final Map<String, List<String>> evidence; // tacticId -> supporting phrase(s)
  const EngineResult(this.level, this.score, this.tactics, this.probs,
      [this.evidence = const {}]);

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

  /// Like [analyze], but also grounds each fired tactic in the words the MODEL
  /// actually relied on — via *occlusion attribution*: remove one word at a
  /// time, re-score, and see how far that tactic's probability falls. The words
  /// whose removal hurts the score most are the model's evidence. This is the
  /// model's own reasoning made visible — deterministic, language-agnostic
  /// (operates on whatever words the transcript has), and never an LLM.
  ///
  /// Costs a handful of extra forward passes (bounded by [maxWords]), so it's
  /// for settled verdicts / result cards — not the live hot path.
  EngineResult analyzeDetailed(String text, {double acoustic = 0.0, int maxWords = 20}) {
    final enc = _encode(text);
    final probs = _clf.classify(enc.inputIds, enc.attentionMask);
    final v = _fusion.assess(probs, acoustic: acoustic);
    if (v.tactics.isEmpty) return EngineResult(v.level, v.score, v.tactics, probs);

    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return EngineResult(v.level, v.score, v.tactics, probs);
    final n = words.length < maxWords ? words.length : maxWords;

    // One occluded forward pass per word, reused across all fired tactics.
    final occluded = <List<double>>[];
    for (var j = 0; j < n; j++) {
      final without = (<String>[...words.sublist(0, j), ...words.sublist(j + 1)]).join(' ');
      final e = _encode(without);
      occluded.add(_clf.classify(e.inputIds, e.attentionMask));
    }

    final evidence = <String, List<String>>{};
    for (final tid in v.tactics) {
      final idx = _fusion.order.indexOf(tid);
      if (idx < 0) continue;
      final spans = _salientSpans(words, n, occluded, idx, probs[idx]);
      if (spans.isNotEmpty) evidence[tid] = spans;
    }
    return EngineResult(v.level, v.score, v.tactics, probs, evidence);
  }

  /// For tactic [idx]: saliency[j] = base − prob(text without word j). Words with
  /// high saliency are merged into contiguous phrases and ranked; top 2 returned.
  List<String> _salientSpans(
      List<String> words, int n, List<List<double>> occluded, int idx, double base) {
    final sal = List<double>.generate(n, (j) => base - occluded[j][idx]);
    // Adaptive threshold: keep words that are clearly the most influential
    // *relative to the strongest one*, with a small absolute floor so we never
    // surface noise. If nothing actually moves the score (e.g. fully redundant
    // phrasing), maxSal stays below the floor and we honestly return nothing.
    var maxSal = 0.0;
    for (final s in sal) {
      if (s > maxSal) maxSal = s;
    }
    if (maxSal < 0.04) return const [];
    final thresh = (0.45 * maxSal).clamp(0.04, 0.5);
    final spans = <({String text, double score})>[];
    var j = 0;
    while (j < n) {
      if (sal[j] < thresh) {
        j++;
        continue;
      }
      final buf = <String>[];
      var s = 0.0;
      while (j < n && sal[j] >= thresh) {
        buf.add(words[j]);
        s += sal[j];
        j++;
      }
      spans.add((text: buf.join(' '), score: s));
    }
    spans.sort((a, b) => b.score.compareTo(a.score));
    return spans.take(2).map((e) => e.text).toList();
  }

  void dispose() {
    _clf.dispose();
    _sp?.dispose();
  }
}
