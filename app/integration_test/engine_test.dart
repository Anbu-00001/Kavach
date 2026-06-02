// engine_test.dart — on-device proof the REAL model runs (not scripted).
// Loads the bundled ONNX classifier on the phone, drives the "Try it yourself"
// screen, and checks the live verdicts on fresh text the app has never seen.
//
//   flutter test integration_test/engine_test.dart -d <deviceId>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/main.dart';
import 'package:kavach/store.dart';

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Pump until [f] appears (the model load is async + takes a moment on-device).
Future<void> waitFor(WidgetTester tester, Finder f, {int timeoutSec = 25}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSec));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 400));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for: $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real on-device model classifies fresh text', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'armed': true});
    final store = await Store.load();
    await tester.pumpWidget(KavachApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));

    await tap(tester, find.text('Try it yourself'));
    // Button reads "Loading model…" until the ONNX session is ready.
    await waitFor(tester, find.text('Analyze on this phone'));

    // Focus the field, type, then analyze (focus-first so a prior value clears).
    Future<void> analyze(String text) async {
      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 300));
      await tap(tester, find.text('Analyze on this phone'));
    }

    // 1) A blatant scam line the app never had canned → must flag HIGH.
    await analyze('Buy gift cards now and read me the numbers, hurry');
    expect(find.text('MODEL CONFIDENCE PER TACTIC'), findsOneWidget); // result rendered
    expect(find.text('Likely a scam'), findsOneWidget); // real verdict = HIGH
    expect(find.text('Looks normal'), findsNothing);

    // 2) A clean legit line → must stay SAFE (no over-firing).
    await analyze('Your appointment is confirmed for Tuesday at 3pm');
    expect(find.text('Looks normal'), findsOneWidget); // real verdict = SAFE
    expect(find.text('Likely a scam'), findsNothing);
  });
}
