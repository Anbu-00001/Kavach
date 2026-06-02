// store.dart — persistent settings, backed by SharedPreferences.
// Everything stays on-device (no cloud), matching Kavach's privacy promise.
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, synchronous-after-load wrapper over SharedPreferences.
///
/// Load once at startup (`await Store.load()`), then read/write fields freely;
/// writes are fire-and-forget to disk. Tests can inject state via
/// `SharedPreferences.setMockInitialValues({...})` before calling `load()`.
class Store {
  static const _kOnboarded = 'onboarded';
  static const _kWatchword = 'watchword';
  static const _kGuardian = 'guardian';
  static const _kArmed = 'armed';
  static const _kDark = 'dark';

  static const defaultWatchword = 'Marigold';
  static const defaultGuardian = 'Priya';

  final SharedPreferences _p;
  Store(this._p);

  static Future<Store> load() async => Store(await SharedPreferences.getInstance());

  /// Has the user finished first-run setup? Decides onboarding vs. home.
  bool get onboarded => _p.getBool(_kOnboarded) ?? false;
  set onboarded(bool v) => _p.setBool(_kOnboarded, v);

  String get watchword => _p.getString(_kWatchword) ?? defaultWatchword;
  set watchword(String v) => _p.setString(_kWatchword, v);

  /// The chosen Guardian contact name, or null if none picked yet.
  String? get guardian => _p.getString(_kGuardian) ?? defaultGuardian;
  set guardian(String? v) =>
      v == null ? _p.remove(_kGuardian) : _p.setString(_kGuardian, v);

  bool get armed => _p.getBool(_kArmed) ?? false;
  set armed(bool v) => _p.setBool(_kArmed, v);

  bool get dark => _p.getBool(_kDark) ?? false;
  set dark(bool v) => _p.setBool(_kDark, v);

  /// Wipe everything — used by the "start over" path and tests.
  Future<void> reset() => _p.clear();
}
