// Smoke test: the app boots to the onboarding screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/main.dart';

void main() {
  testWidgets('Kavach boots to onboarding', (tester) async {
    await tester.pumpWidget(const KavachApp());
    await tester.pump();
    expect(find.text('Turn on protection'), findsOneWidget);
  });
}
