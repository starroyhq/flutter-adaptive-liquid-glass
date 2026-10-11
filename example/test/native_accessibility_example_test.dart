import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass_example/native_accessibility_example.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accessibility probe tracks actions and controlled resets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LiquidGlassTheme(
          data: LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: NativeAccessibilityExample(),
        ),
      ),
    );
    expect(find.text('Navigation calls: 0'), findsOneWidget);
    await tester.tap(find.text('Toggle theme'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation calls: 1'), findsOneWidget);
    expect(find.text('Appearance: dark'), findsOneWidget);
    await tester.tap(find.text('Rename controls'));
    await tester.pumpAndSettle();
    expect(find.text('Switch appearance'), findsOneWidget);
    expect(
      tester
          .widget<LiquidGlassColorPicker>(find.byType(LiquidGlassColorPicker))
          .semanticLabel,
      'Accent color',
    );
    await tester.tap(find.text('Switch appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation calls: 2'), findsOneWidget);
    await tester.tap(find.text('Set red programmatically'));
    await tester.pumpAndSettle();
    expect(find.text('Color value: ffff0000'), findsOneWidget);
    expect(find.text('Color calls: 0'), findsOneWidget);
    await tester.tap(find.text('Disable color'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LiquidGlassColorPicker>(find.byType(LiquidGlassColorPicker))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Activate color accessibility'),
          )
          .onPressed,
      isNull,
    );
  });
}
