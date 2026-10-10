import 'package:flutter_adaptive_liquid_glass/src/fallback_activity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

void main() {
  testWidgets(
    'owned activity stops in background and resumes without resetting state',
    (tester) async {
      await tester.pumpWidget(_host(const LiquidGlassActivityIndicator()));
      FallbackActivityPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<FallbackActivityPainter>()
          .single;
      await tester.pump(const Duration(milliseconds: 200));
      final animation = painter().animation;
      final before = animation.value;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 500));
      expect(animation.value, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(animation.value, isNot(before));
      await tester.pumpWidget(
        _host(const LiquidGlassActivityIndicator(), reduceMotion: true),
      );
      final staticPhase = painter().animation.value;
      await tester.pump(const Duration(seconds: 2));
      expect(painter().animation.value, staticPhase);
      expect(painter().animating, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'stopped status hides; reduced motion retains static busy status',
    (tester) async {
      await tester.pumpWidget(
        _host(const LiquidGlassActivityIndicator(animating: false)),
      );
      expect(find.byType(FallbackGlassActivityIndicator), findsNothing);
      await tester.pumpWidget(
        _host(
          const LiquidGlassActivityIndicator(semanticLabel: 'Loading'),
          reduceMotion: true,
        ),
      );
      final spinner = tester.widget<FallbackGlassActivityIndicator>(
        find.byType(FallbackGlassActivityIndicator),
      );
      expect(spinner.animating, isFalse);
      expect(find.byType(LiquidGlassSurface), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('progress honors custom roles and reports one percentage', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const LiquidGlassProgressView(progress: .42, semanticLabel: 'Download'),
      ),
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, .42);
    expect(progress.color, Colors.teal);
    expect(progress.backgroundColor, Colors.amber);
    expect(
      tester.getSemantics(find.byType(LiquidGlassProgressView)).value,
      '42%',
    );
    expect(find.bySemanticsLabel('Download'), findsOneWidget);
    semantics.dispose();
  });

  test('invalid progress is rejected', () {
    expect(
      () => LiquidGlassProgressView(progress: double.nan),
      throwsAssertionError,
    );
    expect(() => LiquidGlassProgressView(progress: 1.1), throwsAssertionError);
  });

  testWidgets('status color precedence resets across appearance changes', (
    tester,
  ) async {
    Future<void> show(
      Brightness brightness,
      LiquidGlassColors colors, {
      Color? explicit,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: LiquidGlassTheme(
          data: LiquidGlassThemeData(
            mode: LiquidGlassMode.fallback,
            colors: colors,
          ),
          child: Scaffold(
            body: Column(
              children: [
                LiquidGlassActivityIndicator(
                  animating: false,
                  hidesWhenStopped: false,
                  color: explicit,
                ),
                LiquidGlassProgressView(
                  progress: .5,
                  color: explicit,
                  trackColor: explicit,
                  semanticValue: 'Half complete',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    const palette = LiquidGlassColors(
      foreground: Colors.purple,
      accent: Colors.teal,
      selection: Colors.amber,
    );
    await show(Brightness.light, palette);
    expect(
      tester
          .widget<FallbackGlassActivityIndicator>(
            find.byType(FallbackGlassActivityIndicator),
          )
          .color,
      Colors.purple,
    );
    await show(Brightness.dark, palette, explicit: Colors.red);
    expect(
      tester
          .widget<FallbackGlassActivityIndicator>(
            find.byType(FallbackGlassActivityIndicator),
          )
          .color,
      Colors.red,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .color,
      Colors.red,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .backgroundColor,
      Colors.red,
    );
    await show(Brightness.dark, const LiquidGlassColors());
    final scheme = Theme.of(
      tester.element(find.byType(LiquidGlassProgressView)),
    ).colorScheme;
    expect(
      tester
          .widget<FallbackGlassActivityIndicator>(
            find.byType(FallbackGlassActivityIndicator),
          )
          .color,
      scheme.onSurface,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .color,
      scheme.primary,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .backgroundColor,
      scheme.surfaceContainerHighest,
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(LiquidGlassProgressView)).value,
      'Half complete',
    );
    semantics.dispose();
  });

  testWidgets(
    'toolbar uses one surface per group and scrolls without shrinking actions',
    (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 160,
            child: LiquidGlassToolbar(
              groups: [
                [
                  for (final id in ['Undo', 'Redo'])
                    LiquidGlassAction(
                      id: id,
                      label: id,
                      onPressed: () => pressed.add(id),
                    ),
                ],
                [
                  LiquidGlassAction(
                    id: 'last',
                    label: 'Final action',
                    onPressed: () => pressed.add('last'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      expect(find.byType(LiquidGlassButtonGroup), findsNWidgets(2));
      expect(find.byType(LiquidGlassSurface), findsNWidgets(2));
      await tester.tap(find.text('Undo'));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Final action'));
      expect(pressed, ['Undo', 'last']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('icon convenience entry retains accessible button behavior', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(
      _host(
        LiquidGlassButton.icon(
          icon: Icons.add,
          semanticLabel: 'Create',
          onPressed: () => presses++,
        ),
      ),
    );
    expect(find.bySemanticsLabel('Create'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    expect(presses, 1);
    expect(
      tester.getSize(find.byType(LiquidGlassButton)).shortestSide,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });
}

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: LiquidGlassTheme(
    data: LiquidGlassThemeData(
      mode: LiquidGlassMode.fallback,
      reduceMotion: reduceMotion,
      colors: const LiquidGlassColors(
        accent: Colors.teal,
        selection: Colors.amber,
      ),
    ),
    child: Scaffold(body: Center(child: child)),
  ),
);
