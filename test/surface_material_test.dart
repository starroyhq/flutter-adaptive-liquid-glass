import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_selection_track.dart';

void main() {
  testWidgets('light and dark materials let the actual backdrop show through', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      final samples = <Color>[];
      for (final background in const [Color(0xffff0000), Color(0xff0000ff)]) {
        await tester.pumpWidget(_host(dark: dark, background: background));
        await tester.pumpAndSettle();
        final pixels = await _sample(tester);
        samples.add(pixels.center);
        // Both blur and rim stay inside the surface; distant pixels are intact.
        expect(pixels.outside.toARGB32(), background.toARGB32());
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(
          tester.getSize(find.byType(BackdropFilter)),
          tester.getSize(find.byType(LiquidGlassSurface)),
        );
      }
      expect(samples[0].r - samples[1].r, greaterThan(.15));
      expect(samples[1].b - samples[0].b, greaterThan(.15));
    }
  });

  testWidgets('switching appearance lifts the dark material above black', (
    tester,
  ) async {
    await tester.pumpWidget(_host(background: Colors.black));
    await tester.pumpAndSettle();
    final light = (await _sample(tester)).center;
    await tester.pumpWidget(_host(dark: true, background: Colors.black));
    await tester.pumpAndSettle();
    final dark = (await _sample(tester)).center;
    expect(light.computeLuminance(), greaterThan(0));
    expect(dark.computeLuminance(), greaterThan(0));
    expect(dark, isNot(light));
    expect(dark.r, closeTo(dark.g, .01));
    expect(dark.g, closeTo(dark.b, .01));
  });

  testWidgets('explicit tint survives the translucent material', (
    tester,
  ) async {
    await tester.pumpWidget(_host(background: Colors.grey, tint: Colors.red));
    await tester.pumpAndSettle();
    final red = (await _sample(tester)).center;
    await tester.pumpWidget(_host(background: Colors.grey, tint: Colors.blue));
    await tester.pumpAndSettle();
    final blue = (await _sample(tester)).center;
    expect(red.r, greaterThan(red.b));
    expect(blue.b, greaterThan(blue.r));
  });

  testWidgets('opaque and high contrast modes block background interference', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      for (final highContrast in [false, true]) {
        final samples = <Color>[];
        for (final background in [Colors.red, Colors.blue]) {
          await tester.pumpWidget(
            _host(
              dark: dark,
              background: background,
              highContrast: highContrast,
              mode: highContrast
                  ? LiquidGlassMode.fallback
                  : LiquidGlassMode.opaque,
            ),
          );
          await tester.pumpAndSettle();
          samples.add((await _sample(tester)).center);
          expect(find.byType(BackdropFilter), findsNothing);
          final decoration =
              tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(LiquidGlassSurface),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration;
          expect(decoration.boxShadow, isNull);
          if (highContrast) {
            final edge = (decoration.border! as Border).top;
            final painted = Color.alphaBlend(edge.color, decoration.color!);
            final luminances = [
              painted.computeLuminance(),
              decoration.color!.computeLuminance(),
            ]..sort();
            final contrast = (luminances.last + .05) / (luminances.first + .05);
            expect(contrast, greaterThanOrEqualTo(3));
          }
        }
        expect(samples.first, samples.last);
      }
    }
  });

  testWidgets('material and rim do not intercept adjacent action hits', (
    tester,
  ) async {
    var first = 0;
    var second = 0;
    await tester.pumpWidget(
      _host(
        child: SizedBox(
          width: 160,
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => first++,
                  child: const Center(child: Text('First')),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => second++,
                  child: const Center(child: Text('Second')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('First'));
    await tester.tap(find.text('Second'));
    expect([first, second], [1, 1]);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full width buttons preserve centered content and edge hits', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: LiquidGlassButton(
                  label: 'Continue',
                  onPressed: () => taps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(LiquidGlassButton));
    expect(bounds.width, 300);
    expect(tester.getCenter(find.text('Continue')).dx, bounds.center.dx);
    await tester.tapAt(Offset(bounds.left + 12, bounds.center.dy));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(bounds.right - 12, bounds.center.dy));
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'neutral materials protect text on opposite brightness backdrops',
    (tester) async {
      for (final colors in [
        const ColorScheme.light(),
        const ColorScheme.dark(),
        ThemeData(brightness: Brightness.light).colorScheme,
        ThemeData(brightness: Brightness.dark).colorScheme,
      ]) {
        final dark = colors.brightness == Brightness.dark;
        for (final style in LiquidGlassSurfaceStyle.values) {
          for (final background in [Colors.black, Colors.white]) {
            for (final selected in [false, true]) {
              await tester.pumpWidget(
                _host(
                  dark: dark,
                  background: background,
                  style: style,
                  colors: colors,
                  // Render the real selection layer rather than duplicating its
                  // palette: the text protection must survive both materials.
                  child: SizedBox(
                    width: 160,
                    height: 64,
                    child: selected
                        ? FallbackSelectionTrack(
                            selectedIndex: 0,
                            children: const [SizedBox(height: 64)],
                          )
                        : null,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final material = (await _sample(tester)).center;
              final luminances = [
                material.computeLuminance(),
                colors.onSurface.computeLuminance(),
              ]..sort();
              final contrast =
                  (luminances.last + .05) / (luminances.first + .05);
              expect(
                contrast,
                greaterThanOrEqualTo(4.5),
                reason:
                    '$dark / $style / $background / selected: $selected / '
                    'material: $material',
              );
            }
          }
        }
      }
    },
  );
}

const _captureKey = ValueKey('material-capture');

Widget _host({
  bool dark = false,
  Color background = Colors.white,
  Color? tint,
  ColorScheme? colors,
  bool highContrast = false,
  LiquidGlassMode mode = LiquidGlassMode.fallback,
  LiquidGlassSurfaceStyle style = LiquidGlassSurfaceStyle.floating,
  Widget child = const SizedBox(width: 160, height: 64),
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: ThemeData(
    colorScheme:
        colors ??
        (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
          surface: dark ? Colors.black : Colors.white,
          onSurface: dark ? Colors.white : Colors.black,
        ),
  ),
  home: MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: LiquidGlassTheme(
      data: LiquidGlassThemeData(mode: mode),
      child: Center(
        child: RepaintBoundary(
          key: _captureKey,
          child: SizedBox(
            width: 240,
            height: 160,
            child: ColoredBox(
              color: background,
              child: Center(
                child: LiquidGlassSurface(
                  tint: tint,
                  style: style,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<({Color center, Color outside})> _sample(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      Color pixel(int x, int y) {
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      }

      return (center: pixel(120, 80), outside: pixel(10, 10));
    } finally {
      image.dispose();
    }
  });
  return result!;
}
