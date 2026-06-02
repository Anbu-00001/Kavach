// ml_test.dart — on-device proof the MULTILINGUAL tier works: the Rust
// SentencePiece tokenizer (FFI) + the 118MB XLM-R model classify Hindi text
// on the phone. Run: flutter test integration_test/ml_test.dart -d <deviceId>
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

Future<void> waitFor(WidgetTester tester, Finder f, {int timeoutSec = 70}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSec));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for: $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multilingual tier classifies Hindi on-device', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'armed': true});
    final store = await Store.load();
    await tester.pumpWidget(KavachApp(store: store));
    await tester.pump(const Duration(milliseconds: 400));

    await tap(tester, find.text('Try it yourself'));
    // Switch to the multilingual tier → triggers the lazy 118MB load.
    await tap(tester, find.text('12 languages'));
    await waitFor(tester, find.text('Analyze on this phone')); // ml model ready

    Future<void> analyze(String text) async {
      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 300));
      await tap(tester, find.text('Analyze on this phone'));
    }

    // Hindi gift-card scam → HIGH.
    await analyze('अभी गिफ्ट कार्ड खरीदो और नंबर बताओ, किसी को मत बताना');
    expect(find.text('MODEL CONFIDENCE PER TACTIC'), findsOneWidget);
    expect(find.text('Likely a scam'), findsOneWidget);

    // Hindi legit delivery note → SAFE.
    await analyze('आपकी डिलीवरी कल सुबह आ जाएगी, धन्यवाद');
    expect(find.text('Looks normal'), findsOneWidget);
    expect(find.text('Likely a scam'), findsNothing);
  });
}
