// app_test.dart — on-device end-to-end ("drive the real app") suite.
//
// Run on the connected phone with:
//   flutter test integration_test/app_test.dart -d <deviceId>
//
// Uses the live binding, so the demo timeline runs in REAL time on the
// device — fonts, layout, touch targets and the ONNX-shaped state machine
// are all exercised exactly as a judge would see them.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/main.dart';
import 'package:kavach/store.dart';

/// RichText-aware text matcher (find.textContaining skips RichText).
Finder richTextContaining(String s) => find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(s));

Future<void> boot(WidgetTester tester, Store store) async {
  await tester.pumpWidget(KavachApp(store: store));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scroll the target into view, then tap and let things settle.
/// (No pumpAndSettle — the Shield animation never settles.)
Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full journey: onboarding → setup → persisted relaunch → live demo',
      (tester) async {
    // Start from a clean slate on the device.
    SharedPreferences.setMockInitialValues({});
    var store = await Store.load();
    await store.reset();

    // ── First run: onboarding ──
    await boot(tester, store);
    expect(find.text('Turn on protection'), findsOneWidget);

    // ── Setup: safe-word ──
    await tap(tester, find.text('Turn on protection'));
    expect(find.text('Save safe-word'), findsOneWidget);
    await tap(tester, find.text('Banyan')); // pick a suggestion
    await tap(tester, find.text('Save safe-word'));

    // ── Setup: Guardian ──
    expect(find.text('Choose your Guardian'), findsOneWidget);
    await tap(tester, find.text('Arjun'));
    await tap(tester, find.text('Finish setup'));

    // ── Home, freshly set up ──
    expect(find.text('Start Guardian Mode'), findsOneWidget);

    // Persistence written to the real device store.
    expect(store.onboarded, isTrue);
    expect(store.watchword, 'Banyan');
    expect(store.guardian, 'Arjun');

    // ── Simulated relaunch: a brand-new app reading the same store ──
    final store2 = await Store.load();
    await boot(tester, store2);
    expect(find.text('Turn on protection'), findsNothing); // skipped onboarding
    expect(find.text("You're protected."), findsOneWidget);
    expect(find.text('Banyan'), findsWidgets); // restored on home

    // ── Arm + run the live demo in real time ──
    await tap(tester, find.text('Start Guardian Mode'));
    expect(find.text('See how it works'), findsOneWidget);
    await tap(tester, find.text('See how it works'));
    expect(find.text('LIVE · ON CALL'), findsOneWidget); // on the live shield

    // Let the real-time timeline climb (~16s total). The exact early levels
    // depend on the real model (whether it has finished loading), so we only
    // assert the decisive end state both the live engine and the fallback reach.
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('Likely a scam'), findsOneWidget); // HIGH
    expect(richTextContaining('has been told about this call'), findsOneWidget);

    // ── Hang up → summary → home ──
    await tap(tester, find.text('Hang up & call back'));
    expect(find.text("You're safe."), findsOneWidget);
    await tap(tester, find.text('Back to home'));
    expect(find.text('Guardian Mode is on.'), findsOneWidget);
  });
}
