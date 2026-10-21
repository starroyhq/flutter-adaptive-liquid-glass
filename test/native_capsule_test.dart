import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_capsule.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
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
  final calls = <int, List<MethodCall>>{};
  final params = <int, Map>{};
  late int id;
  setUp(() {
    calls.clear();
    params.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          id = arguments['id'] as int;
          final viewId = id;
          final encoded = arguments['params'] as Uint8List;
          params[id] =
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(encoded),
                  )
                  as Map;
          calls[id] = [];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel('flutter_adaptive_liquid_glass/capsule/$viewId'),
            (call) async {
              calls[viewId]!.add(call);
              return call.method == 'intrinsicSize' ? {'width': 140.0} : null;
            },
          );
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
    for (final viewId in calls.keys) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('flutter_adaptive_liquid_glass/capsule/$viewId'),
        null,
      );
    }
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  // Both messages carry the epoch that the view's events must use.
  int epoch(int viewId) =>
      (calls[viewId]!
                  .lastWhere(
                    (call) =>
                        call.method == 'setSuppressed' ||
                        call.method == 'update',
                  )
                  .arguments
              as Map)['epoch']
          as int;
  List<Map> updates(int viewId) => [
    for (final call in calls[viewId]!)
      if (call.method == 'update') call.arguments as Map,
  ];
  Future<void> event(
    String method,
    String action, {
    int? viewId,
    int? eventEpoch,
    int sequence = 1,
  }) async {
    final target = viewId ?? id;
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter_adaptive_liquid_glass/capsule/$target',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, {
          'id': action,
          'epoch': eventEpoch ?? epoch(target),
          'sequence': sequence,
        }),
      ),
      (_) {},
    );
  }

  Widget host(List<NativeCapsuleItem> items) => MaterialApp(
    home: Scaffold(
      body: Center(child: NativeCapsule(grouped: true, items: items)),
    ),
  );

  testWidgets(
    'long-only native action is enabled with one forwarding recognizer',
    (tester) async {
      var holds = 0;
      await tester.pumpWidget(
        host([
          NativeCapsuleItem(
            id: 'one',
            label: 'Options',
            onLongPress: () => holds++,
            longPressSemanticLabel: 'Show options',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      final item = (params[id]!['items'] as List).single as Map;
      expect(item['enabled'], isTrue);
      expect(item['tapEnabled'], isFalse);
      expect(item['longPressEnabled'], isTrue);
      expect(item['longPressLabel'], 'Show options');
      final recognizers = tester
          .widget<UiKitView>(find.byType(UiKitView))
          .gestureRecognizers!;
      expect(
        recognizers
            .map((factory) => factory.type)
            .where((type) => type == LongPressGestureRecognizer)
            .length,
        1,
      );
      await event('longPressed', 'one');
      await event('longPressed', 'one');
      await event('pressed', 'one', sequence: 2);
      expect(holds, 1);
    },
  );

  testWidgets('tap-only capsule does not claim Flutter long press', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      host([
        NativeCapsuleItem(id: 'one', label: 'Open', onPressed: () => presses++),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<UiKitView>(find.byType(UiKitView))
          .gestureRecognizers!
          .map((factory) => factory.type),
      [TapGestureRecognizer],
    );
    await event('pressed', 'one');
    expect(presses, 1);
  });

  testWidgets('replaced and disabled native actions reject old view events', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      host([
        NativeCapsuleItem(
          id: 'one',
          label: 'Open',
          onLongPress: () => actions++,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    final old = id, oldEpoch = epoch(id);
    await tester.pumpWidget(
      host([const NativeCapsuleItem(id: 'one', label: 'Open')]),
    );
    await tester.pumpAndSettle();
    expect(id, isNot(old));
    await event('longPressed', 'one', viewId: old, eventEpoch: oldEpoch);
    await event('longPressed', 'one');
    expect(actions, 0);
  });

  testWidgets('covered and restored route rejects an old interaction epoch', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      host([
        NativeCapsuleItem(id: 'one', label: 'Open', onLongPress: () => holds++),
      ]),
    );
    await tester.pumpAndSettle();
    final previousEpoch = epoch(id);
    final token = Object();
    final route = ModalRoute.of(tester.element(find.byType(NativeCapsule)))!;
    nativeRouteCoverage.retain(token, [route]);
    await tester.pumpAndSettle();
    await event('longPressed', 'one', eventEpoch: previousEpoch);
    expect(holds, 0);
    nativeRouteCoverage.release(token);
    await tester.pumpAndSettle();
    await event('longPressed', 'one', eventEpoch: previousEpoch);
    expect(holds, 0);
    await event('longPressed', 'one', sequence: 2);
    expect(holds, 1);
  });

  Widget iconButton({
    IconData icon = Icons.add,
    String? symbol,
    bool hold = false,
    String? label,
  }) => MaterialApp(
    home: LiquidGlassTheme(
      data: const _NativeTheme(),
      child: Scaffold(
        body: Center(
          child: label == null
              ? LiquidGlassButton.icon(
                  icon: icon,
                  sfSymbol: symbol,
                  semanticLabel: 'Add',
                  onPressed: () {},
                  onLongPress: hold ? () {} : null,
                )
              : LiquidGlassButton(
                  icon: icon,
                  sfSymbol: symbol,
                  label: label,
                  semanticLabel: 'Add',
                  onPressed: () {},
                  onLongPress: hold ? () {} : null,
                ),
        ),
      ),
    ),
  );

  testWidgets(
    'an icon-only button is standalone with or without a long press',
    (tester) async {
      await tester.pumpWidget(iconButton(symbol: 'plus'));
      await tester.pumpAndSettle();
      expect(params[id]!['standaloneIcon'], isTrue);
      final item = (params[id]!['items'] as List).single as Map;
      expect(item['id'], 'button');
      expect(item['label'], 'Add');
      expect(item['symbol'], 'plus');
      expect(item['title'], isNull);
      final tapOnly = id;
      await tester.pumpWidget(iconButton(symbol: 'plus', hold: true));
      await tester.pumpAndSettle();
      // The long press needs a native recognizer, so the view is new; it
      // keeps the same look.
      expect(id, isNot(tapOnly));
      expect(params[id]!['standaloneIcon'], isTrue);
      final held = (params[id]!['items'] as List).single as Map;
      expect(held['longPressEnabled'], isTrue);
      expect(held['symbol'], 'plus');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a standalone bitmap icon is created once its glyph is drawn',
    (tester) async {
      await tester.pumpWidget(iconButton(icon: Icons.close));
      expect(find.byType(UiKitView), findsNothing);
      expect(
        tester.getSize(find.byType(LiquidGlassButton)),
        const Size(48, 48),
      );
      for (
        var i = 0;
        i < 50 && find.byType(UiKitView).evaluate().isEmpty;
        ++i
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byType(UiKitView), findsOneWidget);
      expect(params[id]!['standaloneIcon'], isTrue);
      final png = ((params[id]!['items'] as List).single as Map)['png'];
      // The padded 64-point glyph square, at the test view's pixel ratio of 3.
      expect(ByteData.sublistView(png as Uint8List).getUint32(16), 192);
      expect(
        tester.getSize(find.byType(LiquidGlassButton)),
        const Size(48, 48),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a bitmap icon is redrawn when its button stops being standalone',
    (tester) async {
      Object? png() => ((params[id]!['items'] as List).single as Map)['png'];
      await tester.pumpWidget(iconButton(icon: Icons.close));
      for (
        var i = 0;
        i < 50 && find.byType(UiKitView).evaluate().isEmpty;
        ++i
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(ByteData.sublistView(png() as Uint8List).getUint32(16), 192);
      // A long press keeps the standalone look and its padded bitmap.
      await tester.pumpWidget(iconButton(icon: Icons.close, hold: true));
      await tester.pumpAndSettle();
      expect(params[id]!['standaloneIcon'], isTrue);
      expect(ByteData.sublistView(png() as Uint8List).getUint32(16), 192);
      // A title turns it into a capsule icon, which fits the whole bitmap
      // into the icon size.
      await tester.pumpWidget(
        iconButton(icon: Icons.close, hold: true, label: 'Close'),
      );
      for (var i = 0; i < 50 && png() == null; ++i) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(params[id]!['standaloneIcon'], isFalse);
      // The glyph's own bounds, not the padded square that would halve it.
      expect(
        ByteData.sublistView(png() as Uint8List).getUint32(16),
        lessThan(192),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  Widget lone({
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool prominent = false,
    Color? iconColor,
    String? label,
  }) => MaterialApp(
    home: LiquidGlassTheme(
      data: const _NativeTheme(),
      child: Scaffold(
        body: Center(
          child: LiquidGlassButton(
            icon: Icons.add,
            sfSymbol: 'plus',
            semanticLabel: 'Add',
            label: label,
            prominent: prominent,
            iconColor: iconColor,
            onPressed: onPressed,
            onLongPress: onLongPress,
          ),
        ),
      ),
    ),
  );
  Map updatedItem(Map update) => (update['items'] as List).single as Map;
  ColorScheme scheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme;

  testWidgets(
    'a lone icon button keeps its native view when enabled state, emphasis '
    'or icon color changes',
    (tester) async {
      void press() {}
      await tester.pumpWidget(lone(onPressed: press));
      await tester.pumpAndSettle();
      final view = id;
      expect(params[view]!['standaloneIcon'], isTrue);
      expect(updates(view), isEmpty);
      final colors = scheme(tester);

      await tester.pumpWidget(lone());
      await tester.pumpAndSettle();
      expect(id, view);
      expect(updatedItem(updates(view).last)['enabled'], isFalse);
      expect(updatedItem(updates(view).last)['tapEnabled'], isFalse);

      await tester.pumpWidget(lone(onPressed: press, prominent: true));
      await tester.pumpAndSettle();
      expect(id, view);
      expect(updates(view).last['tint'], colors.primary.toARGB32());
      expect(updates(view).last['foreground'], colors.onPrimary.toARGB32());
      expect(updatedItem(updates(view).last)['tapEnabled'], isTrue);

      // A disabled prominent button gives up its fill.
      await tester.pumpWidget(lone(prominent: true));
      await tester.pumpAndSettle();
      expect(id, view);
      expect(updates(view).last['tint'], isNull);
      expect(updates(view).last['foreground'], colors.onSurface.toARGB32());
      expect(updatedItem(updates(view).last)['tapEnabled'], isFalse);

      await tester.pumpWidget(
        lone(onPressed: press, iconColor: const Color(0xff16a34a)),
      );
      await tester.pumpAndSettle();
      expect(id, view);
      expect(updatedItem(updates(view).last)['iconColor'], 0xff16a34a);
      expect(updatedItem(updates(view).last)['tapEnabled'], isTrue);
      expect(updates(view), hasLength(4));
      expect(params.keys, [view]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a lone text button updates its enabled state and emphasis in place',
    (tester) async {
      void send() {}
      await tester.pumpWidget(
        lone(label: 'Send', prominent: true, onPressed: send),
      );
      await tester.pumpAndSettle();
      final view = id;
      final colors = scheme(tester);
      expect(params[view]!['standaloneIcon'], isFalse);
      expect(params[view]!['tint'], colors.primary.toARGB32());

      await tester.pumpWidget(lone(label: 'Send', prominent: true));
      await tester.pumpAndSettle();
      expect(id, view);
      expect(updates(view).last['tint'], isNull);
      expect(updates(view).last['foreground'], colors.onSurface.toARGB32());
      expect(updatedItem(updates(view).last)['tapEnabled'], isFalse);

      await tester.pumpWidget(
        lone(label: 'Send', prominent: true, onPressed: send),
      );
      await tester.pumpAndSettle();
      expect(id, view);
      expect(updates(view).last['tint'], colors.primary.toARGB32());
      expect(updates(view).last['foreground'], colors.onPrimary.toARGB32());
      expect(updatedItem(updates(view).last)['tapEnabled'], isTrue);
      expect(params.keys, [view]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a press sent before the button was disabled is rejected',
    (tester) async {
      var presses = 0;
      void press() => presses++;
      await tester.pumpWidget(lone(onPressed: press));
      await tester.pumpAndSettle();
      final view = id, enabledEpoch = epoch(id);
      await tester.pumpWidget(lone());
      await tester.pumpAndSettle();
      final disabledEpoch = epoch(view);
      await tester.pumpWidget(lone(onPressed: press));
      await tester.pumpAndSettle();
      expect(id, view);
      final enabledAgainEpoch = epoch(view);
      expect(
        [for (final update in updates(view)) update['epoch']],
        [disabledEpoch, enabledAgainEpoch],
      );
      expect(disabledEpoch, greaterThan(enabledEpoch));
      expect(enabledAgainEpoch, greaterThan(disabledEpoch));
      // UIKit reported these before the button was disabled, or meanwhile.
      await event('pressed', 'button', eventEpoch: enabledEpoch);
      await event('pressed', 'button', eventEpoch: disabledEpoch, sequence: 2);
      expect(presses, 0);
      await event('pressed', 'button', sequence: 3);
      expect(presses, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'adding a long press still creates a new native view',
    (tester) async {
      await tester.pumpWidget(lone(onPressed: () {}));
      await tester.pumpAndSettle();
      final view = id;
      await tester.pumpWidget(lone(onPressed: () {}, onLongPress: () {}));
      await tester.pumpAndSettle();
      expect(id, isNot(view));
      final item = (params[id]!['items'] as List).single as Map;
      expect(item['longPressEnabled'], isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  Widget group({
    VoidCallback? onSecond,
    List<String> ids = const ['first', 'second', 'third'],
    String secondLabel = 'Second',
    bool showLabel = false,
  }) => MaterialApp(
    home: LiquidGlassTheme(
      data: const _NativeTheme(),
      child: Scaffold(
        body: Center(
          child: LiquidGlassButtonGroup(
            actions: [
              for (final actionId in ids)
                LiquidGlassAction(
                  id: actionId,
                  label: actionId == 'second' ? secondLabel : actionId,
                  icon: Icons.add,
                  sfSymbol: 'plus',
                  showLabel: showLabel,
                  onPressed: actionId == 'second' ? onSecond : () {},
                ),
            ],
          ),
        ),
      ),
    ),
  );
  List<bool> tapEnabled(Map update) => [
    for (final item in update['items'] as List) (item as Map)['tapEnabled'],
  ];

  testWidgets(
    'a button group keeps its native view when one action is enabled or '
    'disabled',
    (tester) async {
      void press() {}
      await tester.pumpWidget(group(onSecond: press));
      await tester.pumpAndSettle();
      final view = id;
      expect(params[view]!['grouped'], isTrue);
      expect(updates(view), isEmpty);

      await tester.pumpWidget(group());
      await tester.pumpAndSettle();
      expect(id, view);
      expect(tapEnabled(updates(view).last), [true, false, true]);
      expect(
        [
          for (final item in updates(view).last['items'] as List)
            (item as Map)['enabled'],
        ],
        [true, false, true],
      );

      await tester.pumpWidget(group(onSecond: press));
      await tester.pumpAndSettle();
      expect(id, view);
      expect(tapEnabled(updates(view).last), [true, true, true]);
      expect(updates(view), hasLength(2));
      expect(params.keys, [view]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a press on a group action sent before it was disabled is rejected',
    (tester) async {
      var presses = 0;
      void press() => presses++;
      await tester.pumpWidget(group(onSecond: press));
      await tester.pumpAndSettle();
      final view = id, enabledEpoch = epoch(id);
      await tester.pumpWidget(group());
      await tester.pumpAndSettle();
      final disabledEpoch = epoch(view);
      expect(disabledEpoch, greaterThan(enabledEpoch));
      await event('pressed', 'second', eventEpoch: enabledEpoch);
      await event('pressed', 'second', sequence: 2);
      expect(presses, 0);
      await tester.pumpWidget(group(onSecond: press));
      await tester.pumpAndSettle();
      expect(id, view);
      expect(epoch(view), greaterThan(disabledEpoch));
      await event('pressed', 'second', eventEpoch: disabledEpoch, sequence: 3);
      expect(presses, 0);
      await event('pressed', 'second', sequence: 4);
      expect(presses, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'adding, reordering or relabelling group actions creates a new view',
    (tester) async {
      await tester.pumpWidget(group(onSecond: () {}));
      await tester.pumpAndSettle();
      var view = id;
      for (final next in [
        group(onSecond: () {}, ids: const ['first', 'second']),
        group(onSecond: () {}, ids: const ['second', 'first']),
        group(onSecond: () {}, ids: const ['second', 'first'], showLabel: true),
        group(
          onSecond: () {},
          ids: const ['second', 'first'],
          showLabel: true,
          secondLabel: 'Later',
        ),
      ]) {
        await tester.pumpWidget(next);
        await tester.pumpAndSettle();
        expect(id, isNot(view));
        view = id;
      }
      expect(
        [
          for (final item in params[view]!['items'] as List)
            (item as Map)['title'],
        ],
        ['Later', 'first'],
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a capsule takes the ambient text direction', (tester) async {
    Widget directed(TextDirection direction) => MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: NativeCapsule(
              grouped: true,
              items: [
                NativeCapsuleItem(
                  id: 'one',
                  label: 'One',
                  title: 'One',
                  onPressed: () {},
                ),
                NativeCapsuleItem(
                  id: 'two',
                  label: 'Two',
                  title: 'Two',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(directed(TextDirection.rtl));
    await tester.pumpAndSettle();
    final rightToLeft = id;
    expect(params[rightToLeft]!['rtl'], isTrue);
    // UIKit cannot change a view's direction; a new one is created.
    await tester.pumpWidget(directed(TextDirection.ltr));
    await tester.pumpAndSettle();
    expect(id, isNot(rightToLeft));
    expect(params[id]!['rtl'], isFalse);
  });

  testWidgets(
    'a bitmap glyph that matches text direction is mirrored right to left',
    (tester) async {
      Future<Map> created(IconData icon, TextDirection direction) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: LiquidGlassTheme(
                data: const _NativeTheme(),
                child: Scaffold(
                  body: Center(
                    child: LiquidGlassButton.icon(
                      icon: icon,
                      semanticLabel: 'Icon',
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (
          var i = 0;
          i < 50 && find.byType(UiKitView).evaluate().isEmpty;
          ++i
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byType(UiKitView), findsOneWidget);
        expect(params[id]!['rtl'], direction == TextDirection.rtl);
        return (params[id]!['items'] as List).single as Map;
      }

      final back = await created(Icons.arrow_back, TextDirection.rtl);
      expect(back['png'], isNotNull);
      expect(back['mirror'], isTrue);
      final close = await created(Icons.close, TextDirection.rtl);
      expect(close['mirror'], isFalse);
      final ltr = await created(Icons.arrow_back, TextDirection.ltr);
      expect(ltr['mirror'], isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('backgrounding cancels native action epoch before resuming', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      host([
        NativeCapsuleItem(id: 'one', label: 'Open', onLongPress: () => holds++),
      ]),
    );
    await tester.pumpAndSettle();
    final previousEpoch = epoch(id);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await event('longPressed', 'one');
    expect(holds, 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await event('longPressed', 'one', eventEpoch: previousEpoch);
    expect(holds, 0);
    await event('longPressed', 'one', sequence: 2);
    expect(holds, 1);
  });
}
