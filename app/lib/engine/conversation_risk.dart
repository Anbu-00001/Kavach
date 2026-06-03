// conversation_risk.dart — the conversation-level (slow-burn) risk accumulator.
//
// The per-window classifier answers "is THIS sentence manipulative?". That misses
// the scams that win by patience: the "digital arrest" script deploys authority
// early, isolation in the middle, and the money demand only much later — no single
// window looks decisive, so a hottest-window verdict under-reads the whole call.
//
// This keeps a *decaying memory* of every tactic across the call. When a tactic
// fires it stays "warm" for a few turns, then fades. We re-fuse the accumulated
// vector every window with the SAME taxonomy fusion, so tactics deployed minutes
// apart still combine (and earn their dangerous-combo boost), while a single stray
// detection decays away instead of branding the whole conversation a scam.
//
// 1:1 mirror of core/eval_external.py:call_cumulative — same decay, same fusion,
// so the phone and the host evaluation compute the identical conversation risk.
import 'fusion.dart';

class ConversationRisk {
  final Fusion fusion;

  /// Per-window decay of each tactic's confidence. 0.85 ≈ a tactic stays "present"
  /// (>= the 0.5 fusion threshold) for ~4 windows after a strong hit, then fades —
  /// long enough to bridge a slow-burn script, short enough that one stray window
  /// doesn't linger. Validated against the external eval (see docs/EVALUATION.md).
  final double decay;

  final List<double> _acc; // decaying-max confidence per tactic, in fusion.order

  ConversationRisk(this.fusion, {this.decay = 0.85})
      : _acc = List<double>.filled(fusion.order.length, 0.0);

  FusionVerdict _peak = const FusionVerdict(0.0, 'SAFE', <String>[]);

  /// Highest conversation-level verdict reached so far this call.
  FusionVerdict get peak => _peak;

  /// How many distinct tactics are currently held "warm" in memory at once.
  int get distinctActive {
    var n = 0;
    for (final c in _acc) {
      if (c >= Fusion.threshold) n++;
    }
    return n;
  }

  /// Feed one window's raw 8-tactic probabilities; returns the CONVERSATION-LEVEL
  /// verdict (accumulated), which the live shield surfaces as the call's risk.
  FusionVerdict update(List<double> probs, {double acoustic = 0.0}) {
    for (var i = 0; i < _acc.length && i < probs.length; i++) {
      final decayed = _acc[i] * decay;
      _acc[i] = probs[i] > decayed ? probs[i] : decayed;
    }
    final v = fusion.assess(_acc, acoustic: acoustic);
    if (v.score > _peak.score) _peak = v;
    return v;
  }

  void reset() {
    for (var i = 0; i < _acc.length; i++) {
      _acc[i] = 0.0;
    }
    _peak = const FusionVerdict(0.0, 'SAFE', <String>[]);
  }
}
