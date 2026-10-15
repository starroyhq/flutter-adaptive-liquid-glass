import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Color?> barrier(
    WidgetTester tester,
    Brightness brightness,
    Future<void> Function(BuildContext) open,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        themeAnimationDuration: Duration.zero,
        home: const LiquidGlassTheme(
          data: LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    open(context);
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.text('Content').first))!
            as PopupRoute;
    final color = route.barrierColor;
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    return color;
  }

  Future<void> sheet(BuildContext context, {Color? color}) =>
      showLiquidGlassSheet<void>(
        context: context,
        fitContent: true,
        barrierColor: color,
        builder: (_) => const Text('Content'),
      );
  Future<void> alert(BuildContext context, {Color? color}) =>
      showLiquidGlassAlert<void>(
        context: context,
        title: const Text('Content'),
        barrierColor: color,
        actions: const [LiquidGlassAlertAction(value: null, label: 'OK')],
      );

  testWidgets('a dark theme dims more deeply than a light one', (tester) async {
    for (final open in [sheet, alert]) {
      final light = await barrier(tester, Brightness.light, (c) => open(c));
      final dark = await barrier(tester, Brightness.dark, (c) => open(c));
      expect(light, Colors.black.withValues(alpha: .2));
      expect(dark, Colors.black.withValues(alpha: .48));
    }
  });

  testWidgets('barrierColor replaces the default scrim', (tester) async {
    const custom = Color(0x38000000);
    expect(
      await barrier(tester, Brightness.light, (c) => sheet(c, color: custom)),
      custom,
    );
    expect(
      await barrier(tester, Brightness.dark, (c) => alert(c, color: custom)),
      custom,
    );
  });
}
