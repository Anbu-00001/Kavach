// live_session.dart — opens the live mic shield and holds it for ~4 minutes so
// a human can speak into the room while KAVACH_LIVE verdicts are logged. Not a
// pass/fail test; it's a driver for the real-voice session.
//   adb shell pm grant dev.kavach.kavach android.permission.RECORD_AUDIO
//   flutter test integration_test/live_session.dart -d <deviceId>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/main.dart';
import 'package:kavach/store.dart';

Future<void> waitFor(WidgetTester tester, Finder f, {int timeoutSec = 60}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSec));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for: $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live mic session (speak into the room)', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'armed': true});
    final store = await Store.load();
    await tester.pumpWidget(KavachApp(store: store));

    await tester.pump(const Duration(seconds: 8)); // let the English engine load
    await tester.tap(find.text('Go live'));
    await tester.pump();
    await waitFor(tester, find.text('LIVE · ON CALL'));
    debugPrint('KAVACH_LIVE_SESSION_OPEN: speak now');

    // Hold the live shield open ~4 minutes; the mic keeps streaming to Vosk.
    final end = DateTime.now().add(const Duration(minutes: 4));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    debugPrint('KAVACH_LIVE_SESSION_DONE');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
