// overflow_test.dart — reproduces device layout at the A18's real width (360dp)
// with the real Hanken Grotesk font loaded, so text metrics match the phone.
// Any RenderFlex overflow throws and names the offending widget.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/main.dart';
import 'package:kavach/store.dart';

Future<void> loadRealFont() async {
  final bytes = await File('assets/fonts/HankenGrotesk.ttf').readAsBytes();
  final loader = FontLoader('Hanken Grotesk')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(loadRealFont);

  Future<Store> boot(WidgetTester tester, Map<String, Object> prefs) async {
    // A18: 720x1600 @ dpr 2 → 360x800 logical.
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(prefs);
    final store = await Store.load();
    await tester.pumpWidget(KavachApp(store: store));
    await tester.pump(const Duration(milliseconds: 50));
    return store;
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('no overflow across setup screens at 360dp', (tester) async {
    await boot(tester, {});
    await tapLabel(tester, 'Turn on protection'); // watchword
    await tapLabel(tester, 'Save safe-word'); // guardian
    await tapLabel(tester, 'Finish setup'); // home
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow across live demo + summary at 360dp', (tester) async {
    await boot(tester, {'onboarded': true, 'armed': true});
    await tapLabel(tester, 'See how it works');
    await tester.pump(const Duration(milliseconds: 7200)); // CAUTION
    await tester.pump(const Duration(milliseconds: 8200)); // HIGH
    await tapLabel(tester, 'Hang up & call back'); // summary
    expect(tester.takeException(), isNull);
  });
}
