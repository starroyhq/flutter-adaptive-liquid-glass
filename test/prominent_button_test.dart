import 'package:flutter/foundation.dart';
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

  Widget host(Widget child, {LiquidGlassThemeData? glass}) => MaterialApp(
    themeAnimationDuration: Duration.zero,
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
  });
}
