// sp_tokenizer.dart — Dart ↔ Rust bridge for the multilingual SentencePiece
// tokenizer. The XLM-R Unigram model (Precompiled normalizer + Metaspace) can't
// be tokenized correctly in Dart, so we call the bundled Rust `kavach_core`
// library (HF `tokenizers` crate) over dart:ffi. Same code path the host tests
// verify against Python — so on-device ids are identical.
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef _NewC = Pointer<Void> Function(Pointer<Uint8>, IntPtr);
typedef _NewD = Pointer<Void> Function(Pointer<Uint8>, int);
typedef _EncC = IntPtr Function(Pointer<Void>, Pointer<Uint8>, IntPtr, Pointer<Int64>, IntPtr);
typedef _EncD = int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Int64>, int);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeD = void Function(Pointer<Void>);

class SpTokenizer {
  static const int maxLen = 64; // matches the Rust MAX_LEN + model training

  final Pointer<Void> _handle;
  final _EncD _encode;
  final _FreeD _free;
  bool _disposed = false;

  SpTokenizer._(this._handle, this._encode, this._free);

  /// Load libkavach_core and build a tokenizer from raw tokenizer.json bytes.
  factory SpTokenizer.fromJson(Uint8List json) {
    final lib = DynamicLibrary.open('libkavach_core.so');
    final tokNew = lib.lookupFunction<_NewC, _NewD>('kavach_tok_new');
    final encode = lib.lookupFunction<_EncC, _EncD>('kavach_tok_encode');
    final free = lib.lookupFunction<_FreeC, _FreeD>('kavach_tok_free');

    final buf = malloc<Uint8>(json.length);
    try {
      buf.asTypedList(json.length).setAll(0, json);
      final handle = tokNew(buf, json.length);
      if (handle == nullptr) {
        throw StateError('kavach_tok_new failed (invalid tokenizer.json)');
      }
      return SpTokenizer._(handle, encode, free);
    } finally {
      malloc.free(buf); // Rust copied the bytes into its own Tokenizer
    }
  }

  /// Encode to `<s> … </s>` ids + an all-ones attention mask.
  ({List<int> inputIds, List<int> attentionMask}) encode(String text) {
    if (_disposed) throw StateError('tokenizer disposed');
    final bytes = utf8.encode(text);
    final textPtr = malloc<Uint8>(bytes.length);
    final outPtr = malloc<Int64>(maxLen);
    try {
      textPtr.asTypedList(bytes.length).setAll(0, bytes);
      final n = _encode(_handle, textPtr, bytes.length, outPtr, maxLen);
      if (n < 0) throw StateError('kavach_tok_encode failed');
      final ids = List<int>.generate(n, (i) => outPtr[i]);
      return (inputIds: ids, attentionMask: List<int>.filled(n, 1));
    } finally {
      malloc.free(textPtr);
      malloc.free(outPtr);
    }
  }

  void dispose() {
    if (_disposed) return;
    _free(_handle);
    _disposed = true;
  }
}
