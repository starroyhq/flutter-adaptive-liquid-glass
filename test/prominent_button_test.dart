import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the native branch on a Dart host without pretending that its real
// operating system has native Liquid Glass support.
class _NativeTheme extends LiquidGlassThemeData {
  const _NativeTheme();

  @override
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) => LiquidGlassMode.native;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final created = <Map<Object?, Object?>>[];

  setUp(() {
    created.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          if (arguments['viewType'] ==
              'flutter_adaptive_liquid_glass/capsule') {
            created.add(
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(arguments['params'] as Uint8List),
                  )
                  as Map<Object?, Object?>,
            );
            final id = arguments['id'] as int;
            binding.defaultBinaryMessenger.setMockMethodCallHandler(
              MethodChannel('flutter_adaptive_liquid_glass/capsule/$id'),
              (call) async =>
                  call.method == 'intrinsicSize' ? {'width': 120.0} : null,
            );
          }
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
  });

  Widget host(
    Widget child, {
    LiquidGlassThemeData? glass,
    ColorScheme? scheme,
  }) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: scheme == null ? null : ThemeData(colorScheme: scheme),
    home: LiquidGlassTheme(
      data: glass ?? const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  Color? fill(WidgetTester tester, String label) => tester
      .widget<Material>(
        find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(LiquidGlassButton),
          ),
          matching: find.byType(Material),
        ),
      )
      .color;

  Color? labelColor(WidgetTester tester, String label) =>
      DefaultTextStyle.of(tester.element(find.text(label))).style.color;

  const lightFill = Color(0xfff5f5f7);
  const darkFill = Color(0xff241b3d);
  const explicit = Color(0xff223c51);
  ColorScheme scheme(Brightness brightness, bool light) =>
      ColorScheme.fromSeed(
        seedColor: darkFill,
        brightness: brightness,
      ).copyWith(
        primary: light ? lightFill : darkFill,
        onPrimary: light ? darkFill : lightFill,
      );

  group('fallback', () {
    testWidgets('a disabled prominent button gives up its accent fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlassButton(
                label: 'Enabled',
                prominent: true,
                onPressed: () {},
              ),
              const LiquidGlassButton(label: 'Disabled', prominent: true),
              const LiquidGlassButton(
                label: 'Loading',
                prominent: true,
                loading: true,
              ),
            ],
          ),
        ),
      );
      final accent = Theme.of(tester.element(find.text('Enabled'))).colorScheme;
      expect(fill(tester, 'Enabled'), accent.primary);
      expect(fill(tester, 'Disabled'), Colors.transparent);
      // Loading is not disabled: its fill is what shows that work is going on.
      expect(fill(tester, 'Loading'), accent.primary);
      // The demoted button sits on the same control surface as any other
      // disabled button, and its label is not drawn for an accent fill.
      expect(
        find.ancestor(
          of: find.text('Disabled'),
          matching: find.byType(LiquidGlassSurface),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('Disabled'),
                    matching: find.byType(DefaultTextStyle),
                  )
                  .first,
            )
            .style
            .color,
        accent.onSurface,
      );
    });

    testWidgets('a foreground override applies while pressed or loading', (
      tester,
    ) async {
      final colors = scheme(Brightness.dark, true);
      await tester.pumpWidget(
        host(
          scheme: colors,
          glass: const LiquidGlassThemeData(
            mode: LiquidGlassMode.fallback,
            colors: LiquidGlassColors(onAccent: Color(0xff7b2254)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlassButton(
                label: 'Send',
                prominent: true,
                foregroundColor: explicit,
                onPressed: () {},
              ),
              LiquidGlassButton.icon(
                icon: Icons.arrow_upward,
                semanticLabel: 'Send icon',
                prominent: true,
                foregroundColor: explicit,
                onPressed: () {},
              ),
              const LiquidGlassButton(
                label: 'Loading',
                prominent: true,
                foregroundColor: explicit,
                loading: true,
              ),
              const LiquidGlassButton(
                label: 'Disabled',
                prominent: true,
                foregroundColor: explicit,
              ),
            ],
          ),
        ),
      );
      expect(labelColor(tester, 'Send'), explicit);
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.arrow_upward))).color,
        explicit,
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        explicit,
      );
      expect(labelColor(tester, 'Disabled'), colors.onSurface);
      final press = await tester.startGesture(
        tester.getCenter(find.text('Send')),
      );
      await tester.pump(kPressTimeout);
      expect(labelColor(tester, 'Send'), explicit);
      await press.up();
      await tester.pump();
    });

    testWidgets('it regains its emphasis once it can be pressed', (
      tester,
    ) async {
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (_, value, _) => LiquidGlassButton(
              label: 'Submit',
              prominent: true,
              onPressed: value ? () {} : null,
            ),
          ),
        ),
      );
      expect(fill(tester, 'Submit'), Colors.transparent);
      enabled.value = true;
      await tester.pump();
      expect(
        fill(tester, 'Submit'),
        Theme.of(tester.element(find.text('Submit'))).colorScheme.primary,
      );
    });
  });

  group('native', () {
    testWidgets(
      'the id is the capsule item identifier, button by default',
      (tester) async {
        await tester.pumpWidget(
          host(
            glass: const _NativeTheme(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlassButton(label: 'Named', id: 'save', onPressed: () {}),
                LiquidGlassButton(label: 'Plain', onPressed: () {}),
              ],
            ),
          ),
        );
        await tester.pump();
        String itemId(Map<Object?, Object?> params) =>
            ((params['items'] as List).single as Map)['id'] as String;
        expect(
          [for (final params in created) itemId(params)],
          ['save', 'button'],
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'a disabled prominent capsule is drawn as an ordinary one',
      (tester) async {
        await tester.pumpWidget(
          host(
            glass: const _NativeTheme(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlassButton(
                  label: 'Enabled',
                  prominent: true,
                  onPressed: () {},
                ),
                const LiquidGlassButton(label: 'Disabled', prominent: true),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(created, hasLength(2));
        final enabled = created.first, disabled = created.last;
        final scheme = Theme.of(
          tester.element(find.byType(Scaffold)),
        ).colorScheme;
        expect(enabled['tint'], scheme.primary.toARGB32());
        expect(enabled['foreground'], scheme.onPrimary.toARGB32());
        expect(disabled['tint'], isNull);
        expect(disabled['foreground'], scheme.onSurface.toARGB32());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    for (final brightness in Brightness.values) {
      for (final light in [true, false]) {
        testWidgets('${brightness.name} appearance resolves onPrimary for a '
            '${light ? 'bright' : 'dark'} fill', (tester) async {
          final colors = scheme(brightness, light);
          await tester.pumpWidget(
            host(
              glass: const _NativeTheme(),
              scheme: colors,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidGlassButton(
                    label: 'Send',
                    prominent: true,
                    onPressed: () {},
                  ),
                  LiquidGlassButton.icon(
                    icon: Icons.arrow_upward,
                    sfSymbol: 'arrow.up',
                    semanticLabel: 'Send icon',
                    prominent: true,
                    onPressed: () {},
                  ),
                  const LiquidGlassButton(
                    label: 'Loading',
                    prominent: true,
                    loading: true,
                  ),
                  const LiquidGlassButton(
                    label: 'Disabled',
                    prominent: true,
                    foregroundColor: explicit,
                  ),
                ],
              ),
            ),
          );
          await tester.pump();
          expect(created, hasLength(4));
          final byLabel = {
            for (final params in created)
              ((params['items'] as List).single as Map)['label']: params,
          };
          for (final label in ['Send', 'Send icon', 'Loading']) {
            expect(byLabel[label]!['prominent'], isTrue);
            expect(byLabel[label]!['tint'], colors.primary.toARGB32());
            expect(byLabel[label]!['foreground'], colors.onPrimary.toARGB32());
          }
          expect(byLabel['Loading']!['loading'], isTrue);
          expect(byLabel['Disabled']!['prominent'], isFalse);
          expect(
            byLabel['Disabled']!['foreground'],
            colors.onSurface.toARGB32(),
          );
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
      }
    }
  });
}
