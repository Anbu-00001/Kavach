// engine_test.dart — proves the pure-Dart engine layers match the Python/Rust
// reference exactly. Fixtures (token ids + the resulting verdicts) were generated
// from core/kavach_engine.py against the SAME model — so green here means the
// phone tokenizes and fuses identically to the trained reference.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/engine/wordpiece.dart';
import 'package:kavach/engine/fusion.dart';

void main() {
  // Load the real bundled assets straight from disk (no Flutter binding needed).
  final vocabTxt = File('assets/model/vocab.txt').readAsStringSync();
  final taxonomyJson = File('assets/model/taxonomy.json').readAsStringSync();
  final tok = WordPiece.fromVocabText(vocabTxt);
  final fusion = Fusion.fromTaxonomyJson(taxonomyJson);

  group('WordPiece tokenizer parity (vs HuggingFace/Python)', () {
    // [CLS]=101 … [SEP]=102, ids captured from core/model/intent tokenizer.
    final cases = {
      'Buy gift cards now': [101, 4965, 5592, 5329, 2085, 102],
      'Hi, is this a good time to talk?': [101, 7632, 1010, 2003, 2023, 1037, 2204, 2051, 2000, 2831, 1029, 102],
      "Don't tell anyone, it's urgent": [101, 2123, 1005, 1056, 2425, 3087, 1010, 2009, 1005, 1055, 13661, 102],
    };
    cases.forEach((text, expected) {
      test('"$text"', () {
        expect(tok.encode(text).inputIds, expected);
      });
    });

    test('attention mask matches token count', () {
      final e = tok.encode('Buy gift cards now');
      expect(e.attentionMask, List.filled(e.inputIds.length, 1));
    });

    test('lowercasing + punctuation split are applied', () {
      // Upper/lower must collapse to the same ids (BertNormalizer.lowercase).
      expect(tok.encode('BUY GIFT CARDS NOW').inputIds, tok.encode('buy gift cards now').inputIds);
    });
  });

  group('Fusion parity (vs Rust kavach_core / Python)', () {
    // Helper: build a full prob vector from a sparse {tactic: prob} map.
    List<double> probs(Map<String, double> set) =>
        [for (final id in fusion.order) set[id] ?? 0.0];

    test('legit call → SAFE, no tactics', () {
      final v = fusion.assess(probs({}));
      expect(v.level, 'SAFE');
      expect(v.score, lessThan(1e-6));
      expect(v.tactics, isEmpty);
    });

    test('classic gift-card scam → HIGH, payment surfaces first', () {
      final v = fusion.assess(probs({
        'UNTRACEABLE_PAYMENT': 0.99,
        'SECRECY': 0.95,
        'DISTRESS_HOOK': 0.94,
      }));
      expect(v.level, 'HIGH');
      expect(v.score, greaterThan(0.9));
      expect(v.tactics.first, 'UNTRACEABLE_PAYMENT');
    });

    test('single moderate tactic → CAUTION, not HIGH', () {
      // 1-(1-0.7*0.9) = 0.63 → between 0.45 and 0.75.
      final v = fusion.assess(probs({'URGENCY': 0.9}));
      expect(v.level, 'CAUTION');
      expect(v.score, closeTo(0.63, 1e-6));
    });

    test('below-threshold probs are ignored (noise floor)', () {
      final v = fusion.assess(probs({'URGENCY': 0.49, 'SECRECY': 0.40}));
      expect(v.level, 'SAFE');
      expect(v.tactics, isEmpty);
    });

    test('combo boost: payment + urgency adds 0.20', () {
      final base = fusion.assess(probs({'UNTRACEABLE_PAYMENT': 0.8})).score;
      final combo = fusion.assess(probs({'UNTRACEABLE_PAYMENT': 0.8, 'URGENCY': 0.8})).score;
      // urgency alone contributes via noisy-OR too, but the +0.20 boost must push
      // the combined score well above a plain noisy-OR of the two.
      expect(combo, greaterThan(base + 0.20));
    });

    test('acoustic signal contributes acoustic_weight (0.15)', () {
      final dry = fusion.assess(probs({'URGENCY': 0.9}), acoustic: 0.0).score;
      final wet = fusion.assess(probs({'URGENCY': 0.9}), acoustic: 1.0).score;
      expect(wet - dry, closeTo(0.15, 1e-6));
    });
  });
}
