import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass_example/native_modal_example.dart';

Finder control(int depth, String name) =>
    find.byKey(ValueKey('probe-$depth-$name'));

Future<void> tapControl(WidgetTester tester, int depth, String name) async {
  final finder = control(depth, name);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mixed modal retains draft and controls through theme and nesting',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const NativeModalExample());
      await tapControl(tester, 0, 'sheet');
      expect(control(1, 'title'), findsOneWidget);

      await tester.enterText(control(1, 'draft'), '中文 👩🏽‍💻 draft');
      await tapControl(tester, 1, 'switch');
      await tapControl(tester, 1, 'increment');
      expect(find.text('Flutter text C — taps: 1'), findsOneWidget);

      await tapControl(tester, 1, 'dark');
      await tapControl(tester, 1, 'palette');
      final field = tester.widget<TextField>(control(1, 'draft'));
      expect(field.controller!.text, '中文 👩🏽‍💻 draft');
      expect(tester.widget<SwitchListTile>(control(1, 'switch')).value, isTrue);
      expect(
        Theme.of(tester.element(control(1, 'draft'))).brightness,
        Brightness.dark,
      );

      await tapControl(tester, 1, 'dialog');
      expect(control(2, 'title'), findsOneWidget);
      await tapControl(tester, 2, 'close');
      expect(
        tester.widget<TextField>(control(1, 'draft')).controller!.text,
        '中文 👩🏽‍💻 draft',
      );
      expect(find.text('Flutter text C — taps: 1'), findsOneWidget);
      await tapControl(tester, 1, 'close');
      expect(control(1, 'title'), findsNothing);
      expect(control(0, 'title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('composition factors can be isolated in a visible dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NativeModalExample());
    await tapControl(tester, 0, 'dialog');

    for (final factor in ['segment', 'capsule', 'surface']) {
      expect(control(1, 'native-$factor'), findsOneWidget);
      await tapControl(tester, 1, '$factor-factor');
      expect(control(1, 'native-$factor'), findsNothing);
    }
    expect(find.text('Flutter text B — selected: 0'), findsWidgets);
    expect(control(1, 'draft'), findsOneWidget);

    // Recreate one factor while the route remains presented.
    await tapControl(tester, 1, 'capsule-factor');
    await tapControl(tester, 1, 'increment');
    expect(find.text('Flutter text C — taps: 1'), findsOneWidget);
    expect(control(1, 'native-segment'), findsNothing);
    expect(control(1, 'native-surface'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
