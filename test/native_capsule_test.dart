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

  int epoch(int viewId) =>
      (calls[viewId]!
                  .lastWhere((call) => call.method == 'setSuppressed')
                  .arguments
              as Map)['epoch']
          as int;
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
  }) => MaterialApp(
    home: LiquidGlassTheme(
      data: const _NativeTheme(),
      child: Scaffold(
        body: Center(
          child: LiquidGlassButton.icon(
            icon: icon,
            sfSymbol: symbol,
            semanticLabel: 'Add',
            onPressed: () {},
            onLongPress: hold ? () {} : null,
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'only an icon-only button without a long press is standalone',
    (tester) async {
      await tester.pumpWidget(iconButton(symbol: 'plus'));
      await tester.pumpAndSettle();
      expect(params[id]!['standaloneIcon'], isTrue);
      final item = (params[id]!['items'] as List).single as Map;
      expect(item['id'], 'button');
      expect(item['label'], 'Add');
      expect(item['symbol'], 'plus');
      expect(item['title'], isNull);
      await tester.pumpWidget(iconButton(symbol: 'plus', hold: true));
      await tester.pumpAndSettle();
      expect(params[id]!['standaloneIcon'], isFalse);
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
