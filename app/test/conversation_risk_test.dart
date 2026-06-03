// Proves the conversation-level accumulator catches the slow-burn ("digital
// arrest") script that the per-window verdict misses: when a caller deploys
// authority early and isolation only minutes later, no single window is HIGH —
// but the decaying memory fuses them across windows and crosses into HIGH.
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/engine/fusion.dart';
import 'package:kavach/engine/conversation_risk.dart';

// Minimal taxonomy mirroring the shipped one's relevant tactics/weights/levels.
const _tax = '''
{
  "tactics": [
    {"id":"URGENCY","weight":0.7},
    {"id":"SECRECY","weight":0.85},
    {"id":"UNTRACEABLE_PAYMENT","weight":0.95},
    {"id":"AUTHORITY_IMPERSONATION","weight":0.75},
    {"id":"DISTRESS_HOOK","weight":0.8},
    {"id":"ISOLATION","weight":0.8},
    {"id":"IDENTITY_PROBE","weight":0.9},
    {"id":"RELATIONSHIP_SPOOF","weight":0.6}
  ],
  "risk_levels":[
    {"id":"SAFE","min_score":0.0},
    {"id":"CAUTION","min_score":0.45},
    {"id":"HIGH","min_score":0.75}
  ],
  "fusion":{"combo_boosts":[],"acoustic_weight":0.15}
}
''';

// Index order matches the taxonomy above.
const _authority = 3, _isolation = 5, _payment = 2;

List<double> _probs(Map<int, double> hits) {
  final p = List<double>.filled(8, 0.0);
  hits.forEach((i, v) => p[i] = v);
  return p;
}

void main() {
  final fusion = Fusion.fromTaxonomyJson(_tax);

  test('slow-burn: per-window stays CAUTION, cumulative reaches HIGH', () {
    // The caller says authority now, then nothing alarming for a few turns,
    // then isolation — the two never land in the same window.
    final windowsProbs = <List<double>>[
      _probs({_authority: 0.9}), // "this is the CBI..."
      _probs({}), // chit-chat / narrative building
      _probs({}),
      _probs({_isolation: 0.9}), // "...do not disconnect, stay on the line"
    ];

    // Per-window: best single-window fused score.
    var perWindowPeak = 0.0;
    for (final p in windowsProbs) {
      final v = fusion.assess(p);
      if (v.score > perWindowPeak) perWindowPeak = v.score;
    }

    // Cumulative: decaying memory fused across windows.
    final convo = ConversationRisk(fusion);
    for (final p in windowsProbs) {
      convo.update(p);
    }

    expect(perWindowPeak, lessThan(0.75),
        reason: 'no single window has both tactics, so per-window never hits HIGH');
    expect(convo.peak.level, 'HIGH',
        reason: 'authority (decayed) + isolation fuse across windows into HIGH');
    expect(convo.peak.tactics,
        containsAll(<String>['AUTHORITY_IMPERSONATION', 'ISOLATION']));
  });

  test('decay: a single stray tactic long ago does NOT linger into a verdict', () {
    final convo = ConversationRisk(fusion);
    convo.update(_probs({_authority: 0.9})); // one stray hit
    for (var i = 0; i < 8; i++) {
      convo.update(_probs({})); // many benign windows
    }
    // After enough decay the lone tactic falls below the present-threshold and
    // the *current* fused verdict is back to SAFE (the peak is remembered though).
    final now = convo.update(_probs({}));
    expect(now.level, 'SAFE');
    expect(convo.distinctActive, 0);
  });

  test('a single decisive payment tactic is still HIGH on its own', () {
    final convo = ConversationRisk(fusion);
    final v = convo.update(_probs({_payment: 0.95})); // "buy gift cards"
    expect(v.level, 'HIGH');
  });
}
