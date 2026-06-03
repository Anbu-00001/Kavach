// widget_test.dart — boot, navigation, persistence and the demo timeline,
// driven entirely in-process with a fake clock (no device needed).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/main.dart';
import 'package:kavach/store.dart';

/// find.textContaining only matches Text/EditableText, not RichText —
/// several status lines are RichText, so match their flattened text.
Finder richTextContaining(String s) => find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(s));

/// Boot the app with a given persisted state and let the first frame render.
Future<Store> bootWith(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await Store.load();
  await tester.pumpWidget(KavachApp(store: store));
  await tester.pump(const Duration(milliseconds: 50));
  return store;
}

/// Tap a button by its label and let the screen transition settle.
/// (pumpAndSettle is unusable here — the Shield has an infinite animation.)
Future<void> tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Like [tapLabel] but first scrolls the target into view — several controls
/// (e.g. "See how it works", the live-shield actions) sit below the fold in a
/// scroll body, exactly as a real user would scroll to reach them.
Future<void> tapInBody(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tapLabel(tester, label);
}

void main() {
  group('first run', () {
    testWidgets('fresh install boots to onboarding', (tester) async {
      await bootWith(tester, {});
      expect(find.text('Turn on protection'), findsOneWidget);
      expect(find.text('See how it works'), findsNothing);
    });

    testWidgets('full setup walkthrough reaches a protected home', (tester) async {
      await bootWith(tester, {});

      await tapLabel(tester, 'Turn on protection'); // → watchword
      expect(find.text('Save safe-word'), findsOneWidget);
      expect(find.text('Marigold'), findsWidgets); // pre-filled default

      await tapLabel(tester, 'Save safe-word'); // → guardian
      expect(find.text('Choose your Guardian'), findsOneWidget);

      await tapLabel(tester, 'Finish setup'); // → home (unarmed)
      expect(find.text('Start Guardian Mode'), findsOneWidget);
    });
  });

  group('persistence', () {
    testWidgets('returning user skips onboarding and lands on home', (tester) async {
      await bootWith(tester, {'onboarded': true, 'armed': true, 'watchword': 'Banyan'});
      expect(find.text('Turn on protection'), findsNothing);
      expect(find.text('Guardian Mode is on.'), findsOneWidget);
      expect(find.text('Banyan'), findsWidgets); // restored safe-word shown on home
    });

    testWidgets('finishing setup writes onboarded + safe-word to disk', (tester) async {
      final store = await bootWith(tester, {});
      await tapLabel(tester, 'Turn on protection');

      // Change the safe-word via a suggestion chip, then save.
      await tester.tap(find.text('Jubilee'));
      await tester.pump(const Duration(milliseconds: 50));
      await tapLabel(tester, 'Save safe-word');
      await tapLabel(tester, 'Finish setup');

      expect(store.onboarded, isTrue);
      expect(store.watchword, 'Jubilee');
      // A freshly loaded Store sees the same persisted values.
      final reloaded = await Store.load();
      expect(reloaded.onboarded, isTrue);
      expect(reloaded.watchword, 'Jubilee');
    });

    testWidgets('arming on home persists across a cold reload', (tester) async {
      final store = await bootWith(tester, {'onboarded': true});
      expect(find.text("You're protected."), findsOneWidget); // unarmed copy

      await tapLabel(tester, 'Start Guardian Mode');
      expect(store.armed, isTrue);
      expect((await Store.load()).armed, isTrue);
    });
  });

  group('live demo timeline', () {
    testWidgets('climbs SAFE → CAUTION → HIGH and alerts the Guardian', (tester) async {
      await bootWith(tester, {'onboarded': true, 'armed': true});

      await tapInBody(tester, 'See how it works'); // → live shield, t=0 (SAFE)
      expect(find.text('Listening'), findsOneWidget);

      // t≈7s — distress + urgency tip it to CAUTION.
      await tester.pump(const Duration(milliseconds: 7200));
      expect(find.text('Be careful'), findsOneWidget);

      // t≈15s — gift-card demand → HIGH, Guardian alert fired.
      await tester.pump(const Duration(milliseconds: 8200));
      expect(find.text('Likely a scam'), findsOneWidget);
      expect(richTextContaining('has been told about this call'), findsOneWidget);

      // Hang up → summary.
      await tapInBody(tester, 'Hang up & call back');
      expect(find.text("You're safe."), findsOneWidget);
      await tapInBody(tester, 'Back to home');
      expect(find.text('Guardian Mode is on.'), findsOneWidget);
    });

    testWidgets('"I\'m safe" dismiss returns to an armed home', (tester) async {
      await bootWith(tester, {'onboarded': true, 'armed': true});
      await tapInBody(tester, 'See how it works');
      await tester.pump(const Duration(milliseconds: 8000)); // into CAUTION/HIGH

      await tapInBody(tester, "I'm safe — dismiss");
      expect(find.text('Guardian Mode is on.'), findsOneWidget);
    });
  });
}
