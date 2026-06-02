// fusion.dart — risk fusion, a 1:1 Dart port of app/rust/kavach_core/src/lib.rs
// (itself a port of core/reference_detector.py). The single source of truth for
// "how do we turn 8 tactic probabilities into a risk verdict" lives in
// taxonomy.json, which we bundle as an asset and parse here — so the phone, the
// Rust host tests, and the Python reference all compute the identical score.
import 'dart:convert';

class FusionVerdict {
  final double score;
  final String level; // SAFE | CAUTION | HIGH
  final List<String> tactics; // fired tactic ids, most decisive first
  const FusionVerdict(this.score, this.level, this.tactics);
}

typedef _Combo = ({List<String> tactics, double boost});
typedef _Level = ({String id, double minScore});

/// Loads tactic weights, combo boosts and risk thresholds from taxonomy.json.
class Fusion {
  static const double threshold = 0.5; // a tactic counts as "present" at p >= 0.5

  final List<String> order; // tactic ids in model-output order (public: engine reads it)
  final Map<String, double> _weight;
  final List<_Combo> _combos;
  final double _acousticWeight;
  final List<_Level> _levelsDesc; // sorted by minScore, high → low

  Fusion._(this.order, this._weight, this._combos, this._acousticWeight, this._levelsDesc);

  factory Fusion.fromTaxonomyJson(String jsonStr) {
    final d = json.decode(jsonStr) as Map<String, dynamic>;
    final tactics = (d['tactics'] as List).cast<Map<String, dynamic>>();
    final order = <String>[];
    final weight = <String, double>{};
    for (final t in tactics) {
      order.add(t['id'] as String);
      weight[t['id'] as String] = (t['weight'] as num).toDouble();
    }
    final fusion = d['fusion'] as Map<String, dynamic>;
    final combos = (fusion['combo_boosts'] as List)
        .cast<Map<String, dynamic>>()
        .map<_Combo>((c) => (tactics: (c['tactics'] as List).cast<String>(), boost: (c['boost'] as num).toDouble()))
        .toList();
    final acoustic = (fusion['acoustic_weight'] as num).toDouble();
    final levels = (d['risk_levels'] as List)
        .cast<Map<String, dynamic>>()
        .map<_Level>((l) => (id: l['id'] as String, minScore: (l['min_score'] as num).toDouble()))
        .toList()
      ..sort((a, b) => b.minScore.compareTo(a.minScore));
    return Fusion._(order, weight, combos, acoustic, levels);
  }

  /// `probs`: per-tactic probabilities in [order]. `acoustic`: synth-voice cue [0,1].
  /// Noisy-OR over weight·prob for present tactics + dangerous-combo boosts +
  /// acoustic, clamped to [0,1], mapped to a risk level by threshold.
  FusionVerdict assess(List<double> probs, {double acoustic = 0.0}) {
    final present = <int>[];
    for (var i = 0; i < order.length && i < probs.length; i++) {
      if (probs[i] >= threshold) present.add(i);
    }

    var prod = 1.0;
    for (final i in present) {
      prod *= 1.0 - _weight[order[i]]! * probs[i];
    }
    var score = 1.0 - prod;

    for (final c in _combos) {
      if (c.tactics.every((id) => present.any((i) => order[i] == id))) {
        score += c.boost;
      }
    }
    score += _acousticWeight * acoustic.clamp(0.0, 1.0);
    score = score.clamp(0.0, 1.0);

    final ordered = [...present]..sort((a, b) => _weight[order[b]]!.compareTo(_weight[order[a]]!));
    return FusionVerdict(score, _levelFor(score), ordered.map((i) => order[i]).toList());
  }

  String _levelFor(double score) {
    for (final l in _levelsDesc) {
      if (score >= l.minScore) return l.id;
    }
    return _levelsDesc.last.id;
  }
}
