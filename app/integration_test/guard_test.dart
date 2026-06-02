// guard_test.dart — Step 1 validation for the background guardian (Layer 2).
// Confirms the foreground service starts on-device and bridges heartbeats to
// the UI isolate. (Step 2 swaps the heartbeat for the real Vosk+engine loop.)
//   adb shell pm grant dev.kavach.kavach android.permission.RECORD_AUDIO
//   adb shell pm grant dev.kavach.kavach android.permission.POST_NOTIFICATIONS
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/main.dart';
import 'package:kavach/store.dart';

Future<void> waitFor(WidgetTester tester, Finder f, {int timeoutSec = 30}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSec));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for: $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('background guardian service starts + bridges to UI', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'armed': true});
    final store = await Store.load();
    await tester.pumpWidget(KavachApp(store: store));
    await tester.pump(const Duration(seconds: 6));

    await tester.tap(find.text('Guard in background'));
    await tester.pump();
    await waitFor(tester, find.text('LIVE · ON CALL')); // navigated to the live shield

    // Let heartbeats flow from the background isolate (logged as KAVACH_GUARDIAN /
    // received as KAVACH_UI). ~12s = ~6 beats.
    final end = DateTime.now().add(const Duration(seconds: 14));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('LIVE · ON CALL'), findsOneWidget); // still alive, no crash
  }, timeout: const Timeout(Duration(minutes: 2)));
}
