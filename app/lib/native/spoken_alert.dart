import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays a bundled, pre-recorded spoken safety warning in the user's own language
/// (and buzzes the phone) through the native layer — the channel an illiterate,
/// low-vision or hard-of-hearing elder can actually receive. Most of India's
/// fraud victims can't read our on-screen verdict; this is for them.
///
/// Offline + deterministic (one of a few fixed clips, never synthesised). No-ops
/// off-Android and in tests, and swallows every error, so an advisory warning can
/// never break the live shield.
class SpokenAlert {
  static const _ch = MethodChannel('dev.kavach/calls');

  /// [level] is 'HIGH' or 'CAUTION'; [lang] is the live language ('en','hi','ta','te').
  Future<void> alert(String level, String lang) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _ch.invokeMethod('speakAlert', {'level': level, 'lang': lang});
    } catch (_) {
      // advisory only — never throw into the UI
    }
  }
}
