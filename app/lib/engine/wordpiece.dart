// wordpiece.dart — pure-Dart BERT WordPiece tokenizer.
//
// Faithful port of the HuggingFace pipeline baked into the trained model's
// tokenizer.json: BertNormalizer (clean_text + lowercase + strip_accents) →
// BertPreTokenizer (whitespace + punctuation split) → WordPiece (greedy
// longest-match with the '##' continuation prefix). It must reproduce the
// Python token ids exactly — see test/engine_test.dart for locked fixtures.
//
// No native code, no network: this is what keeps inference 100% on-device.

class WordPiece {
  final Map<String, int> vocab;
  final int clsId, sepId, unkId, padId;
  static const String contPrefix = '##';
  static const int maxInputCharsPerWord = 100;

  WordPiece(this.vocab)
      : clsId = vocab['[CLS]']!,
        sepId = vocab['[SEP]']!,
        unkId = vocab['[UNK]']!,
        padId = vocab['[PAD]'] ?? 0;

  /// Build from a vocab.txt asset (one token per line; id == line index).
  factory WordPiece.fromVocabText(String text) {
    final vocab = <String, int>{};
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final tok = lines[i].endsWith('\r') ? lines[i].substring(0, lines[i].length - 1) : lines[i];
      if (tok.isEmpty && i == lines.length - 1) continue; // trailing newline
      vocab[tok] = i;
    }
    return WordPiece(vocab);
  }

  /// Encode to `[CLS] … [SEP]`, truncated to [maxLen] tokens total.
  /// Returns parallel input_ids / attention_mask (no padding; the caller pads).
  ({List<int> inputIds, List<int> attentionMask}) encode(String text, {int maxLen = 48}) {
    final ids = <int>[clsId];
    for (final word in _preTokenize(_normalize(text))) {
      if (ids.length >= maxLen - 1) break;
      for (final id in _wordpiece(word)) {
        if (ids.length >= maxLen - 1) break;
        ids.add(id);
      }
    }
    ids.add(sepId);
    return (inputIds: ids, attentionMask: List<int>.filled(ids.length, 1));
  }

  // ── BertNormalizer: clean control chars, strip accents, lowercase ──
  String _normalize(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      // clean_text: drop NUL / replacement char, normalize whitespace to space.
      if (rune == 0 || rune == 0xFFFD || _isControl(rune)) continue;
      if (_isWhitespace(rune)) {
        out.write(' ');
        continue;
      }
      // handle_chinese_chars: pad CJK so each becomes its own token.
      if (_isChinese(rune)) {
        out..write(' ')..writeCharCode(rune)..write(' ');
        continue;
      }
      out.writeCharCode(rune);
    }
    // lowercase, then strip accents (Mn marks) on the lowercased form.
    return _stripAccents(out.toString().toLowerCase());
  }

  // ── BertPreTokenizer: split on whitespace, then break off punctuation ──
  List<String> _preTokenize(String text) {
    final words = <String>[];
    for (final chunk in text.split(RegExp(r'\s+'))) {
      if (chunk.isEmpty) continue;
      final buf = StringBuffer();
      for (final rune in chunk.runes) {
        if (_isPunct(rune)) {
          if (buf.isNotEmpty) {
            words.add(buf.toString());
            buf.clear();
          }
          words.add(String.fromCharCode(rune));
        } else {
          buf.writeCharCode(rune);
        }
      }
      if (buf.isNotEmpty) words.add(buf.toString());
    }
    return words;
  }

  // ── WordPiece greedy longest-match ──
  List<int> _wordpiece(String word) {
    if (word.length > maxInputCharsPerWord) return [unkId];
    final chars = word.runes.toList();
    final tokens = <int>[];
    var start = 0;
    while (start < chars.length) {
      var end = chars.length;
      int? curId;
      while (start < end) {
        var sub = String.fromCharCodes(chars.sublist(start, end));
        if (start > 0) sub = contPrefix + sub;
        final id = vocab[sub];
        if (id != null) {
          curId = id;
          break;
        }
        end--;
      }
      if (curId == null) return [unkId]; // any unmatched piece ⇒ whole word UNK
      tokens.add(curId);
      start = end;
    }
    return tokens;
  }

  // ── unicode helpers (mirroring HF's BasicTokenizer) ──
  static String _stripAccents(String s) {
    // Drop combining marks. We approximate NFD by removing the common Latin
    // combining diacritical block; sufficient for the languages we tokenize.
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x0300 && r <= 0x036F) continue; // combining diacritical marks
      b.writeCharCode(r);
    }
    return b.toString();
  }

  static bool _isControl(int c) {
    if (c == 0x09 || c == 0x0A || c == 0x0D) return false; // tab/newline kept as ws
    return (c >= 0 && c < 0x20) || (c >= 0x7F && c <= 0x9F);
  }

  static bool _isWhitespace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 || c == 0x2028 || c == 0x2029;

  static bool _isChinese(int c) =>
      (c >= 0x4E00 && c <= 0x9FFF) ||
      (c >= 0x3400 && c <= 0x4DBF) ||
      (c >= 0x20000 && c <= 0x2A6DF) ||
      (c >= 0xF900 && c <= 0xFAFF);

  static bool _isPunct(int c) {
    // ASCII punctuation + the unicode P* categories (approximated by ranges).
    if ((c >= 33 && c <= 47) || (c >= 58 && c <= 64) || (c >= 91 && c <= 96) || (c >= 123 && c <= 126)) {
      return true;
    }
    return (c >= 0x2000 && c <= 0x206F) || // general punctuation
        (c >= 0x3000 && c <= 0x303F) || // CJK symbols & punctuation
        (c >= 0xFF00 && c <= 0xFFEF); // fullwidth forms
  }
}
