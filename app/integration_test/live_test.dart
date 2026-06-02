// live_test.dart — on-device smoke test for the live mic pipeline (Layer 1).
// Verifies that tapping "Go live" loads the Vosk model, starts the speech
// service, and reaches the live shield without crashing. (Real transcription
// accuracy is exercised by hand with actual call audio; this guards the wiring.)
//
//   adb shell pm grant dev.kavach.kavach android.permission.RECORD_AUDIO
//   flutter test integration_test/live_test.dart -d <deviceId>
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

  testWidgets('Go live: mic → Vosk → live shield initializes on-device', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'armed': true});
    final store = await Store.load();
    await tester.pumpWidget(KavachApp(store: store));

    // Let the English ONNX engine finish loading (startLive needs it ready).
    await tester.pump(const Duration(seconds: 8));

    await tester.tap(find.text('Go live now'));
    await tester.pump();
    // Vosk model unzips (~40MB) + speech service starts on first run.
    await waitFor(tester, find.text('LIVE · ON CALL'));

    // We're on the live shield with the real pipeline running (no crash).
    expect(find.text('LIVE · ON CALL'), findsOneWidget);
    // With a quiet room it should be SAFE/listening, not a false HIGH.
    expect(find.text('Likely a scam'), findsNothing);
  });
}
