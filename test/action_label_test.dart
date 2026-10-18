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
  Widget fallback(Widget child) => MaterialApp(
    home: LiquidGlassTheme(
      data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  LiquidGlassAction save({bool showLabel = true, VoidCallback? press}) =>
      LiquidGlassAction(
        id: 'save',
        label: 'Save',
        icon: Icons.download,
        sfSymbol: 'square.and.arrow.down',
        showLabel: showLabel,
        onPressed: press ?? () {},
      );
  LiquidGlassAction share({bool showLabel = true}) => LiquidGlassAction(
    id: 'share',
    label: 'Share',
    icon: Icons.ios_share,
    sfSymbol: 'square.and.arrow.up',
    showLabel: showLabel,
    onPressed: () {},
  );

  Finder inGroup(Finder matching) => find.descendant(
    of: find.byType(LiquidGlassButtonGroup),
    matching: matching,
  );

  testWidgets('a grouped action shows its label after the icon on request', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var saves = 0;
    await tester.pumpWidget(
      fallback(
        LiquidGlassButtonGroup(
          actions: [
            save(press: () => saves++),
            share(showLabel: false),
          ],
        ),
      ),
    );
    expect(inGroup(find.byIcon(Icons.download)), findsOneWidget);
    expect(inGroup(find.text('Save')), findsOneWidget);
    // The label follows the icon on the same line.
    final icon = tester.getRect(inGroup(find.byIcon(Icons.download)));
    final label = tester.getRect(inGroup(find.text('Save')));
    expect(label.left, greaterThan(icon.right));
    expect(label.center.dy, closeTo(icon.center.dy, 1));
    // Without the option an action with an icon stays icon-only.
    expect(inGroup(find.byIcon(Icons.ios_share)), findsOneWidget);
    expect(inGroup(find.text('Share')), findsNothing);
    // The visible label is not announced twice.
    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save')));
    expect(saves, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('the option widens the action and leaves others unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      fallback(LiquidGlassButtonGroup(actions: [save(showLabel: false)])),
    );
    final iconOnly = tester.getSize(find.byType(LiquidGlassButtonGroup));
    expect(iconOnly, const Size(56, 48));
    await tester.pumpWidget(
      fallback(LiquidGlassButtonGroup(actions: [save()])),
    );
    final labelled = tester.getSize(find.byType(LiquidGlassButtonGroup));
    expect(labelled.width, greaterThan(iconOnly.width));
    expect(labelled.height, 48);
  });

  testWidgets('toolbars and action bars pass the option to their capsules', (
    tester,
  ) async {
    await tester.pumpWidget(
      fallback(
        LiquidGlassToolbar(
          groups: [
            [save(), share()],
          ],
        ),
      ),
    );
    expect(inGroup(find.text('Save')), findsOneWidget);
    expect(inGroup(find.text('Share')), findsOneWidget);
    await tester.pumpWidget(
      fallback(
        SizedBox(
          width: 360,
          child: LiquidGlassActionBar(
            actions: [
              share(),
              const LiquidGlassAction(id: 'done', label: 'Done'),
            ],
          ),
        ),
      ),
    );
    expect(inGroup(find.byIcon(Icons.ios_share)), findsOneWidget);
    expect(inGroup(find.text('Share')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation bars show an icon or a label, never both', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: Scaffold(
            appBar: LiquidGlassNavigationBar(
              title: 'Preview',
              actions: [save(), share()],
            ),
          ),
        ),
      ),
    );
    expect(inGroup(find.byIcon(Icons.download)), findsOneWidget);
    expect(inGroup(find.text('Save')), findsNothing);
    expect(inGroup(find.text('Share')), findsNothing);
  });

  testWidgets(
    'on iOS 26 the native capsule item gets the label as its title',
    (tester) async {
      final binding = TestDefaultBinaryMessengerBinding.instance;
      final created = <Map<Object?, Object?>>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          if (call.method == 'create') {
            final arguments = call.arguments as Map;
            created.add(
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(arguments['params'] as Uint8List),
                  )
                  as Map<Object?, Object?>,
            );
            binding.defaultBinaryMessenger.setMockMethodCallHandler(
              MethodChannel(
                'flutter_adaptive_liquid_glass/capsule/${arguments['id']}',
              ),
              (call) async =>
                  call.method == 'intrinsicSize' ? {'width': 160.0} : null,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassTheme(
            data: const _NativeTheme(),
            child: Scaffold(
              body: Center(
                child: LiquidGlassButtonGroup(
                  actions: [save(), share(showLabel: false)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final items = [
        for (final item in created.last['items'] as List) item as Map,
      ];
      expect([for (final item in items) item['title']], ['Save', null]);
      expect([for (final item in items) item['label']], ['Save', 'Share']);
      expect(
        [for (final item in items) item['symbol']],
        ['square.and.arrow.down', 'square.and.arrow.up'],
      );
      expect(created.last['grouped'], isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
