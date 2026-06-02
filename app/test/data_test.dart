// data_test.dart — pure-logic coverage of the risk/taxonomy/verdict layer.
// No widgets, no device: fast guards against the IP drifting out of shape.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data.dart';

void main() {
  group('taxonomy', () {
    // Must stay in lock-step with core/taxonomy.json (the source of truth).
    const expectedIds = {
      'URGENCY', 'SECRECY', 'UNTRACEABLE_PAYMENT', 'AUTHORITY_IMPERSONATION',
      'DISTRESS_HOOK', 'ISOLATION', 'IDENTITY_PROBE', 'RELATIONSHIP_SPOOF',
    };

    test('exposes exactly the 8 canonical tactics', () {
      expect(kTactics.keys.toSet(), expectedIds);
    });

    test('every tactic has a sane weight, chip and explanation', () {
      for (final e in kTactics.entries) {
        expect(e.value.weight, greaterThan(0.0), reason: '${e.key} weight');
        expect(e.value.weight, lessThanOrEqualTo(1.0), reason: '${e.key} weight');
        expect(e.value.chip.trim(), isNotEmpty, reason: '${e.key} chip');
        expect(e.value.explain.trim().length, greaterThan(20), reason: '${e.key} explain');
      }
    });

    test('UNTRACEABLE_PAYMENT is the heaviest signal', () {
      final maxW = kTactics.values.map((t) => t.weight).reduce((a, b) => a > b ? a : b);
      expect(kTactics['UNTRACEABLE_PAYMENT']!.weight, maxW);
    });
  });

  group('risk levels', () {
    test('SAFE/CAUTION/HIGH all defined with banners', () {
      for (final id in ['SAFE', 'CAUTION', 'HIGH']) {
        expect(kRisk[id], isNotNull, reason: id);
        expect(kRisk[id]!.banner.trim(), isNotEmpty, reason: id);
      }
    });

    test('HIGH banner matches the on-phone "Likely a scam" copy', () {
      expect(kRisk['HIGH']!.banner, 'Likely a scam');
    });
  });

  group('deriveExp', () {
    test('SAFE returns the single reassurance line', () {
      final exp = deriveExp('SAFE', []);
      expect(exp, hasLength(1));
      expect(exp.first.toLowerCase(), contains('listening'));
    });

    test('HIGH returns the top 3 tactics by weight, highest first', () {
      final tactics = ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'];
      final exp = deriveExp('HIGH', tactics);
      expect(exp, hasLength(3));
      // 0.95 > 0.85 > 0.80 → payment, secrecy, distress.
      expect(exp, [
        kTactics['UNTRACEABLE_PAYMENT']!.explain,
        kTactics['SECRECY']!.explain,
        kTactics['DISTRESS_HOOK']!.explain,
      ]);
    });

    test('CAUTION surfaces only the single strongest tactic', () {
      final exp = deriveExp('CAUTION', ['DISTRESS_HOOK', 'URGENCY']);
      expect(exp, hasLength(1));
      expect(exp.first, kTactics['DISTRESS_HOOK']!.explain); // 0.80 > 0.70
    });
  });

  group('buildVerdict', () {
    test('round-trips canned verdicts and is not flagged live', () {
      for (final id in ['SAFE', 'CAUTION', 'HIGH']) {
        final v = buildVerdict(id);
        expect(v.level, id);
        expect(v.live, isFalse);
        expect(v.score, kVerdicts[id]!.score);
      }
    });

    test('scores climb SAFE < CAUTION < HIGH', () {
      expect(buildVerdict('SAFE').score, lessThan(buildVerdict('CAUTION').score));
      expect(buildVerdict('CAUTION').score, lessThan(buildVerdict('HIGH').score));
    });
  });

  group('demo arc (kDemoBeats)', () {
    test('risk only ever escalates — never silently de-escalates mid-call', () {
      const rank = {'SAFE': 0, 'CAUTION': 1, 'HIGH': 2};
      var lastRank = -1;
      var lastScore = -1.0;
      for (final b in kDemoBeats) {
        expect(rank[b.level], greaterThanOrEqualTo(lastRank), reason: 'level regressed at ${b.at}ms');
        expect(b.score, greaterThanOrEqualTo(lastScore), reason: 'score regressed at ${b.at}ms');
        lastRank = rank[b.level]!;
        lastScore = b.score;
      }
    });

    test('arc starts SAFE and ends HIGH with the Guardian alert sent', () {
      expect(kDemoBeats.first.level, 'SAFE');
      expect(kDemoBeats.last.level, 'HIGH');
      expect(kDemoBeats.last.guardian, 'sent');
    });

    test('every tactic referenced in a beat exists in the taxonomy', () {
      for (final b in kDemoBeats) {
        for (final id in b.tactics) {
          expect(kTactics.containsKey(id), isTrue, reason: 'unknown tactic $id @${b.at}ms');
        }
      }
    });

    test('beat timestamps are strictly increasing', () {
      for (var i = 1; i < kDemoBeats.length; i++) {
        expect(kDemoBeats[i].at, greaterThan(kDemoBeats[i - 1].at));
      }
    });
  });

  group('color helpers', () {
    test('risk colors differ across levels and light/dark', () {
      expect(riskColor('SAFE', false), isNot(riskColor('HIGH', false)));
      expect(riskColor('HIGH', false), isNot(riskColor('HIGH', true)));
    });

    test('CAUTION banner ink is dark; SAFE/HIGH ink is white', () {
      expect(bannerInk('CAUTION'), isNot(Colors.white));
      expect(bannerInk('SAFE'), Colors.white);
      expect(bannerInk('HIGH'), Colors.white);
    });
  });
}
