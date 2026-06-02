// guardian_service.dart — the always-on background guardian (Layer 2).
//
// Runs a foreground service (microphone type) hosting a dedicated Dart isolate
// that keeps the FULL pipeline alive with the screen off:
//   mic → Vosk (offline ASR) → KavachEngine → rolling-peak verdict
// Verdicts are pushed to the UI isolate; the persistent notification flips to a
// warning on HIGH. Still 100% on-device — no network.
import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'kavach_engine.dart';
import 'live_listener.dart';

const guardianChannelId = 'kavach_guardian';

/// Configure the service once at app startup (does not start it).
Future<void> configureGuardian() async {
  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: guardianOnStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: guardianChannelId,
      initialNotificationTitle: 'Kavach',
      initialNotificationContent: 'Starting guard…',
      foregroundServiceTypes: const [AndroidForegroundType.microphone],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

/// Entry point that runs INSIDE the background isolate.
@pragma('vm:entry-point')
void guardianOnStart(ServiceInstance service) async {
  // The background isolate has no plugins registered until we do this.
  DartPluginRegistrant.ensureInitialized();
  if (kDebugMode) debugPrint('KAVACH_GUARDIAN: isolate started');

  KavachEngine? engine;
  LiveListener? listener;

  Future<void> shutdown() async {
    try {
      await listener?.stop();
      engine?.dispose();
    } catch (_) {}
    await service.stopSelf();
  }

  service.on('stop').listen((_) {
    if (kDebugMode) debugPrint('KAVACH_GUARDIAN: stop requested');
    shutdown();
  });

  try {
    engine = await KavachEngine.load();
    if (kDebugMode) debugPrint('KAVACH_GUARDIAN: engine loaded');
    final ll = listener = LiveListener(engine);
    ll.onError = (e) {
      if (kDebugMode) debugPrint('KAVACH_GUARDIAN listener error: $e');
    };
    ll.onUpdate = () {
      final r = ll.peak;
      final level = r?.level ?? 'SAFE';
      service.invoke('verdict', {
        'level': level,
        'score': r?.score ?? 0.0,
        'tactics': r?.tactics ?? const <String>[],
        'transcript': ll.transcript,
      });
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: level == 'HIGH' ? '⚠️ Possible scam on this call' : 'Kavach is guarding',
          content: level == 'HIGH'
              ? "Don't send money or codes — ask your safe-word"
              : 'Listening for scams · on-device only',
        );
      }
    };
    await ll.start(); // unzips Vosk + begins streaming
    if (kDebugMode) debugPrint('KAVACH_GUARDIAN: listening');
  } catch (e, st) {
    if (kDebugMode) debugPrint('KAVACH_GUARDIAN_FAILED: $e\n$st');
    service.invoke('guard_error', {'error': '$e'});
  }
}
