import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_navigation_bar.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final creation = <int, Map>{};
  late int id;

  setUp(() {
    calls.clear();
    creation.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final viewId = args['id'] as int;
          id = viewId;
          creation[viewId] =
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(args['params'] as Uint8List),
                  )
                  as Map;
          calls[viewId] = [];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(
              'flutter_adaptive_liquid_glass/navigation-bar/$viewId',
            ),
            (call) async {
              calls[viewId]!.add(call);
              return null;
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
        MethodChannel('flutter_adaptive_liquid_glass/navigation-bar/$viewId'),
        null,
      );
    }
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  Map config([int? viewId]) => calls[viewId ?? id]!.last.arguments as Map;

  Future<void> event(
    String action, {
    int? viewId,
    int? epoch,
    int sequence = 1,
  }) async {
    final target = viewId ?? id;
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter_adaptive_liquid_glass/navigation-bar/$target',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('pressed', {
          'id': action,
          'epoch': epoch ?? config(target)['epoch'],
          'sequence': sequence,
        }),
      ),
      (_) {},
    );
  }

  Widget host({
    String title = 'Components',
    String? subtitle,
    String label = 'Toggle theme',
    String actionId = 'theme',
    VoidCallback? onPressed,
    Brightness brightness = Brightness.light,
    Color tint = Colors.blue,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: NativeNavigationBar(
          title: title,
          subtitle: subtitle,
          tintColor: tint,
          leading: [
            LiquidGlassAction(id: 'back', label: 'Back', onPressed: () {}),
          ],
          actions: [
            LiquidGlassAction(
              id: actionId,
              label: label,
              icon: Icons.brightness_6,
              sfSymbol: 'circle.lefthalf.filled',
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('the subtitle reaches the native navigation item', (
    tester,
  ) async {
    await tester.pumpWidget(host(subtitle: 'Synthetic workspace'));
    await tester.pumpAndSettle();
    expect(creation[id]!['subtitle'], 'Synthetic workspace');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(config()['subtitle'], isNull);
  });

  testWidgets('native bar receives business labels separately from symbols', (
    tester,
  ) async {
    await tester.pumpWidget(host(onPressed: () {}));
    await tester.pumpAndSettle();
    expect(creation[id]!['title'], 'Components');
    expect((creation[id]!['actions'] as List).single, {
      'id': 'theme',
      'label': 'Toggle theme',
      'sfSymbol': 'circle.lefthalf.filled',
      'enabled': true,
    });
    expect((creation[id]!['leading'] as List).single, {
      'id': 'back',
      'label': 'Back',
      'sfSymbol': null,
      'enabled': true,
    });
    final view = tester.widget<UiKitView>(find.byType(UiKitView));
    expect(view.viewType, 'flutter_adaptive_liquid_glass/navigation-bar');
    expect(view.gestureRecognizers!.map((factory) => factory.type), [
      TapGestureRecognizer,
    ]);
    expect(tester.getSize(find.byType(UiKitView)).height, 64);
  });

  testWidgets(
    'label and theme update retain the view and accept delayed activation once',
    (tester) async {
      var presses = 0;
      void press() => presses++;
      await tester.pumpWidget(host(onPressed: press));
      await tester.pumpAndSettle();
      final viewId = id, previousEpoch = config()['epoch'] as int;
      await tester.pumpWidget(
        host(
          title: 'Updated',
          label: 'Switch to light appearance',
          brightness: Brightness.dark,
          direction: TextDirection.rtl,
          tint: Colors.purple,
          onPressed: press,
        ),
      );
      await tester.pumpAndSettle();
      expect(id, viewId);
      expect(creation.length, 1);
      expect(config()['title'], 'Updated');
      expect(config()['dark'], true);
      expect(config()['rtl'], true);
      expect(config()['tintColor'], Colors.purple.toARGB32());
      expect(config()['epoch'], previousEpoch);
      expect((config()['actions'] as List).single, {
        'id': 'theme',
        'label': 'Switch to light appearance',
        'sfSymbol': 'circle.lefthalf.filled',
        'enabled': true,
      });
      // UIKit captured this event before Flutter changed the business label
      // and theme. Its action remains enabled, so delivering it late is valid.
      await event('theme', epoch: previousEpoch);
      expect(presses, 1);
      await event('theme');
      expect(presses, 1);
      await event('theme', sequence: 2);
      expect(presses, 2);
    },
  );

  testWidgets(
    'unchanged rebuild retains epoch and current callback dispatches once',
    (tester) async {
      var oldPresses = 0, newPresses = 0;
      await tester.pumpWidget(host(onPressed: () => oldPresses++));
      await tester.pumpAndSettle();
      final originalEpoch = config()['epoch'];
      final updates = calls[id]!.length;
      await tester.pumpWidget(host(onPressed: () => newPresses++));
      await tester.pumpAndSettle();
      expect(config()['epoch'], originalEpoch);
      expect(calls[id]!.length, updates);
      await event('theme');
      await event('theme');
      expect(oldPresses, 0);
      expect(newPresses, 1);
      await event('unknown', sequence: 2);
      expect(newPresses, 1);
      await event('theme', sequence: 3);
      expect(newPresses, 2);
    },
  );

  testWidgets('disabled action cannot receive current or old native events', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(host(onPressed: () => presses++));
    await tester.pumpAndSettle();
    final oldEpoch = config()['epoch'] as int;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(((config()['actions'] as List).single as Map)['enabled'], false);
    await event('theme', epoch: oldEpoch);
    await event('theme', sequence: 2);
    expect(presses, 0);
    await tester.pumpWidget(host(onPressed: () => presses++));
    await tester.pumpAndSettle();
    await event('theme', epoch: oldEpoch, sequence: 3);
    expect(presses, 0);
    await event('theme', sequence: 4);
    expect(presses, 1);
  });

  testWidgets('replacing action identity rejects previous interaction events', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(host(onPressed: () => presses++));
    await tester.pumpAndSettle();
    final oldEpoch = config()['epoch'] as int;
    await tester.pumpWidget(
      host(actionId: 'appearance', onPressed: () => presses++),
    );
    await tester.pumpAndSettle();
    expect(config()['epoch'], isNot(oldEpoch));
    await event('theme', epoch: oldEpoch);
    await event('appearance', epoch: oldEpoch);
    await event('theme', sequence: 2);
    expect(presses, 0);
    await event('appearance', sequence: 3);
    expect(presses, 1);
  });

  testWidgets('covered route and its old epoch cannot trigger an action', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(host(onPressed: () => presses++));
    await tester.pumpAndSettle();
    final oldEpoch = config()['epoch'] as int;
    final route = ModalRoute.of(
      tester.element(find.byType(NativeNavigationBar)),
    )!;
    final token = Object();
    nativeRouteCoverage.retain(token, [route]);
    await tester.pumpAndSettle();
    expect(config()['suppressed'], true);
    await event('theme');
    expect(presses, 0);
    nativeRouteCoverage.release(token);
    await tester.pumpAndSettle();
    expect(config()['suppressed'], false);
    await event('theme', epoch: oldEpoch);
    expect(presses, 0);
    await event('theme', sequence: 2);
    expect(presses, 1);
  });

  testWidgets('background and disposed view events cannot invoke actions', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(host(onPressed: () => presses++));
    await tester.pumpAndSettle();
    final oldEpoch = config()['epoch'] as int;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(config()['interactionEnabled'], false);
    await event('theme');
    expect(presses, 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await event('theme', epoch: oldEpoch);
    expect(presses, 0);
    await event('theme', sequence: 2);
    expect(presses, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await event('theme', sequence: 3);
    expect(presses, 1);
  });

  testWidgets(
    'coverage within one frame permanently rejects queued activations',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(host(onPressed: () => presses++));
      await tester.pumpAndSettle();
      final oldEpoch = config()['epoch'] as int;
      final route = ModalRoute.of(
        tester.element(find.byType(NativeNavigationBar)),
      )!;
      final token = Object();
      addTearDown(() => nativeRouteCoverage.release(token));

      nativeRouteCoverage.retain(token, [route]);
      await event('theme', epoch: oldEpoch);
      expect(presses, 0);
      // No rendered frame occurs between covering and uncovering the route.
      // A rejected message, or one still queued in the platform channel, must
      // not become valid again when the current route is visible once more.
      nativeRouteCoverage.release(token);
      await event('theme', epoch: oldEpoch);
      await event('theme', epoch: oldEpoch, sequence: 2);
      expect(presses, 0);

      await tester.pumpAndSettle();
      expect(config()['suppressed'], false);
      expect(config()['epoch'], isNot(oldEpoch));
      await event('theme', epoch: oldEpoch, sequence: 3);
      expect(presses, 0);
      await event('theme', sequence: 4);
      await event('theme', sequence: 4);
      expect(presses, 1);
    },
  );

  testWidgets(
    'disabling a navigation bar action keeps the native bar and its view',
    (tester) async {
      var presses = 0;
      Widget bar({VoidCallback? onPressed}) => MaterialApp(
        home: LiquidGlassTheme(
          data: const _NativeTheme(),
          child: Scaffold(
            appBar: LiquidGlassNavigationBar(
              title: 'Components',
              actions: [
                LiquidGlassAction(
                  id: 'theme',
                  label: 'Toggle theme',
                  sfSymbol: 'circle.lefthalf.filled',
                  onPressed: onPressed,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(bar(onPressed: () => presses++));
      await tester.pumpAndSettle();
      final view = id, oldEpoch = config()['epoch'] as int;
      await tester.pumpWidget(bar());
      await tester.pumpAndSettle();
      expect(find.byType(NativeNavigationBar), findsOneWidget);
      expect(id, view);
      expect(creation.keys, [view]);
      expect(((config()['actions'] as List).single as Map)['enabled'], false);
      await tester.pumpWidget(bar(onPressed: () => presses++));
      await tester.pumpAndSettle();
      expect(id, view);
      await event('theme', epoch: oldEpoch);
      expect(presses, 0);
      await event('theme', sequence: 2);
      expect(presses, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
