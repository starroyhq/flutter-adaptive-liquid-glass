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
  const retry = ValueKey('retry');
  const skip = ValueKey('skip');
  const done = ValueKey('done');

  Widget host(
    Widget child, {
    double width = 360,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    builder: (context, app) => Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: app!,
        ),
      ),
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  LiquidGlassAction action(String id, String label, {VoidCallback? press}) =>
      LiquidGlassAction(id: id, label: label, onPressed: press);

  testWidgets('the last action is prominent at the trailing edge, the rest '
      'share one capsule at the leading edge', (tester) async {
    var presses = <String>[];
    await tester.pumpWidget(
      host(
        LiquidGlassActionBar(
          actions: [
            action('retry', 'Retry', press: () => presses.add('retry')),
            action('skip', 'Skip', press: () => presses.add('skip')),
            action('done', 'Done', press: () => presses.add('done')),
          ],
        ),
      ),
    );
    // One capsule for the quieter actions and one prominent button.
    expect(find.byType(LiquidGlassButtonGroup), findsOneWidget);
    expect(find.byType(LiquidGlassButton), findsOneWidget);
    expect(
      tester
          .widget<LiquidGlassButton>(find.byType(LiquidGlassButton))
          .prominent,
      isTrue,
    );
    final group = tester.getRect(find.byType(LiquidGlassButtonGroup));
    final primary = tester.getRect(find.byKey(done));
    expect(group.left, lessThan(primary.left));
    expect(primary.right, 360);
    // They share a line: the prominent button is vertically centered on the capsule.
    expect(primary.center.dy, closeTo(group.center.dy, .5));
    // Ids are the widgets' keys, and each action reaches only its own callback.
    await tester.tap(find.byKey(retry));
    await tester.tap(find.byKey(skip));
    await tester.tap(find.byKey(done));
    expect(presses, ['retry', 'skip', 'done']);
  });

  testWidgets('a lone action is a prominent button at the end', (tester) async {
    await tester.pumpWidget(
      host(
        LiquidGlassActionBar(actions: [action('done', 'Done', press: () {})]),
      ),
    );
    expect(find.byType(LiquidGlassButtonGroup), findsNothing);
    expect(tester.getRect(find.byKey(done)).right, 360);
  });

  testWidgets('a disabled last action gives up its emphasis', (tester) async {
    await tester.pumpWidget(
      host(
        LiquidGlassActionBar(
          actions: [
            action('skip', 'Skip', press: () {}),
            action('done', 'Done'),
          ],
        ),
      ),
    );
    final button = tester.widget<Material>(
      find.descendant(of: find.byKey(done), matching: find.byType(Material)),
    );
    expect(button.color, Colors.transparent);
  });

  testWidgets('the actions stack at the trailing edge when they do not fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        width: 200,
        LiquidGlassActionBar(
          actions: [
            action('retry', 'Retry', press: () {}),
            action('skip', 'Skip', press: () {}),
            action('done', 'Done', press: () {}),
          ],
        ),
      ),
    );
    final group = tester.getRect(find.byType(LiquidGlassButtonGroup));
    final primary = tester.getRect(find.byKey(done));
    expect(primary.top, greaterThan(group.bottom - 1));
    expect(primary.right, 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text stacks the bar and keeps every action reachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        textScaler: const TextScaler.linear(2),
        LiquidGlassActionBar(
          actions: [
            action('retry', 'Retry the failed step', press: () {}),
            action('done', 'Done', press: () {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(done)).top,
      greaterThan(
        tester.getRect(find.byType(LiquidGlassButtonGroup)).bottom - 1,
      ),
    );
  });

  testWidgets('right to left mirrors the bar', (tester) async {
    await tester.pumpWidget(
      host(
        direction: TextDirection.rtl,
        LiquidGlassActionBar(
          actions: [
            action('skip', 'Skip', press: () {}),
            action('done', 'Done', press: () {}),
          ],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(done)).left, 0);
    expect(
      tester.getRect(find.byType(LiquidGlassButtonGroup)).right,
      greaterThan(300),
    );
  });

  testWidgets('padding is the visible space around the buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LiquidGlassActionBar(
          padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
          actions: [
            action('skip', 'Skip', press: () {}),
            action('done', 'Done', press: () {}),
          ],
        ),
      ),
    );
    // The bar keeps room for the capsule's shadow inside that space.
    final group = tester.getRect(find.byType(LiquidGlassButtonGroup));
    final primary = tester.getRect(find.byKey(done));
    expect(group.left, 20);
    expect(group.top, 16);
    expect(primary.right, 360 - 24);
    expect(
      tester.getSize(find.byType(LiquidGlassActionBar)).height,
      16 + 48 + 24,
    );
  });

  testWidgets('a lone action needs no room before it, and a small padding '
      'still leaves room for the shadow', (tester) async {
    await tester.pumpWidget(
      host(
        LiquidGlassActionBar(
          padding: const EdgeInsets.all(20),
          actions: [action('done', 'Done', press: () {})],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(done)).right, 340);
    expect(tester.getRect(find.byKey(done)).top, 20);
    await tester.pumpWidget(
      host(
        LiquidGlassActionBar(
          actions: [
            action('skip', 'Skip', press: () {}),
            action('done', 'Done', press: () {}),
          ],
        ),
      ),
    );
    // No padding at all: the shadow room is still reserved before and around
    // the capsule.
    expect(tester.getRect(find.byType(LiquidGlassButtonGroup)).left, 8);
    expect(tester.getRect(find.byType(LiquidGlassButtonGroup)).top, 8);
  });

  testWidgets(
    'the native bar names its buttons by action id',
    (tester) async {
      final created = <Map<Object?, Object?>>[];
      final binding = tester.binding;
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
                  call.method == 'intrinsicSize' ? {'width': 120.0} : null,
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
              body: LiquidGlassActionBar(
                actions: [
                  action('skip', 'Skip', press: () {}),
                  action('done', 'Done', press: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      List<Object?> ids(Map<Object?, Object?> params) => [
        for (final item in params['items'] as List) (item as Map)['id'],
      ];
      // One capsule for the quieter actions, one prominent button.
      expect(created.map(ids), [
        ['skip'],
        ['done'],
      ]);
      expect([for (final params in created) params['grouped']], [true, false]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test('actions are required and their ids unique', () {
    expect(() => LiquidGlassActionBar(actions: const []), throwsAssertionError);
    expect(
      () => LiquidGlassActionBar(
        actions: const [
          LiquidGlassAction(id: 'same', label: 'One'),
          LiquidGlassAction(id: 'same', label: 'Two'),
        ],
      ),
      throwsAssertionError,
    );
  });
}
