// call_guard.dart — Dart bridge to the native call-screening + floating overlay
// (Layer 0). All methods are defensive: on host/test or a platform without the
// channel they no-op instead of throwing, so widget tests stay green.
import 'package:flutter/services.dart';

class CallGuard {
  static const _ch = MethodChannel('dev.kavach/calls');

  static Future<bool> _b(String m, [dynamic args]) async {
    try {
      return (await _ch.invokeMethod<bool>(m, args)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _v(String m, [dynamic args]) async {
    try {
      await _ch.invokeMethod(m, args);
    } catch (_) {}
  }

  /// Does the app hold the system call-screening role?
  static Future<bool> hasRole() => _b('hasRole');
  static Future<void> requestRole() => _v('requestRole');

  /// Can we draw the floating overlay over other apps?
  static Future<bool> hasOverlay() => _b('hasOverlay');
  static Future<void> requestOverlay() => _v('requestOverlay');

  /// Master switch: auto-shield unknown callers (read by the native service).
  static Future<bool> getAutoShield() => _b('getAutoShield');
  static Future<void> setAutoShield(bool on) => _v('setAutoShield', on);

  /// Fire the whole unknown-call path WITHOUT a real call (demo/test).
  static Future<void> simulateUnknownCall([String? number]) =>
      _v('simulateUnknownCall', {'number': number ?? '+91 98765 43210'});

  /// Launched via "Shield this call"? (durable flag, consumed once)
  static Future<bool> consumePendingGuard() => _b('consumePendingGuard');

  /// Native asks us to start the guard (the warm "Shield this call" path).
  static void onStartGuard(void Function() cb) {
    try {
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'startGuard') cb();
      });
    } catch (_) {}
  }
}
