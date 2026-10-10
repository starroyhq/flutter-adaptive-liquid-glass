import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass_example/component_catalog.dart';

import '../integration_test/components_test.dart'
    show dismissKeyboard, exerciseFallbackControls, reveal;

void main() {
  testWidgets('catalog exposes every component family with real contents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ComponentCatalogApp(initialMode: LiquidGlassMode.fallback),
    );
    await tester.pump(const Duration(milliseconds: 400));
    for (final type in [
      LiquidGlassSurface,
      LiquidGlassButton,
      LiquidGlassToolbar,
      LiquidGlassSlider,
      LiquidGlassSwitch,
      LiquidGlassStepper,
      LiquidGlassActivityIndicator,
      LiquidGlassProgressView,
      LiquidGlassNavigationBar,
      LiquidGlassTabBar,
      LiquidGlassSegmentedControl<int>,
    ]) {
      expect(find.byType(type), findsWidgets);
    }
    tester
        .widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar))
        .onSelected(1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LiquidGlassDatePicker), findsOneWidget);
    expect(find.byType(LiquidGlassColorPicker), findsOneWidget);
    tester
        .widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar))
        .onSelected(2);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LiquidGlassMenuButton<String>), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('catalog-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Mixed layer 1'), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const ValueKey('popup-draft-1')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '中文 👩🏽‍💻');
    await dismissKeyboard(tester);
    await reveal(tester, find.byKey(const ValueKey('popup-nest-1')));
    await tester.tap(find.byKey(const ValueKey('popup-nest-1')));
    await tester.pumpAndSettle();
    expect(find.text('Mixed layer 2'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('popup-close-2')));
    await tester.tap(find.byKey(const ValueKey('popup-close-2')));
    await tester.pumpAndSettle();
    await reveal(tester, field, delta: -150);
    expect(tester.widget<TextField>(field).controller!.text, '中文 👩🏽‍💻');
    await reveal(tester, find.byKey(const ValueKey('popup-close-1')));
    await tester.tap(find.byKey(const ValueKey('popup-close-1')));
    await tester.pumpAndSettle();
    tester
        .widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar))
        .onSelected(3);
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlassSearchField), findsOneWidget);
    await tester.tap(find.text('Open search scaffold'));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlassSearchScaffold), findsOneWidget);
    expect(find.text('First application page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final height in [568.0, 844.0]) {
    testWidgets('fallback device scenario at a 390×$height viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(390, height));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseFallbackControls(tester);
    });
  }
}
