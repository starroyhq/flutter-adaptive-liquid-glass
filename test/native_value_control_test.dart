import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_value_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <int, List<MethodCall>>{};
  late int id;

  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final viewId = (call.arguments as Map)['id'] as int;
          id = viewId;
          calls[viewId] = [];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(
              'flutter_adaptive_liquid_glass/value-control/$viewId',
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
        MethodChannel('flutter_adaptive_liquid_glass/value-control/$viewId'),
        null,
      );
    }
  });

  Map<dynamic, dynamic> config() =>
      calls[id]!.lastWhere((call) => call.method == 'configure').arguments
          as Map;

  Future<void> event(
    String phase,
    double value, {
    int? revision,
    int gestureId = 1,
  }) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter_adaptive_liquid_glass/value-control/$id',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('valueEvent', {
          'phase': phase,
          'value': value,
          'revision': revision ?? config()['revision'],
          'gestureId': gestureId,
        }),
      ),
      (_) {},
    );
  }

  Widget host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: SizedBox(width: 300, child: child)),
        ),
      );

  testWidgets('native controls reserve only their supported gestures', (
    tester,
  ) async {
    for (final kind in ['slider', 'switch', 'stepper']) {
      await tester.pumpWidget(
        host(
          NativeValueControl(
            key: ValueKey(kind),
            kind: kind,
            value: .5,
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      final types = view.gestureRecognizers!.map((factory) => factory.type);
      expect(types.contains(EagerGestureRecognizer), isFalse);
      expect(types.contains(TapGestureRecognizer), isTrue);
      expect(
        types.contains(HorizontalDragGestureRecognizer),
        kind != 'stepper',
      );
      expect(types.contains(LongPressGestureRecognizer), kind == 'stepper');
    }
  });

  testWidgets(
    'a disabled slider leaves the gesture arena to its scroll parent',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        host(
          ListView(
            controller: scroll,
            children: [
              NativeValueControl(
                kind: 'slider',
                value: .5,
                enabled: false,
                onChanged: (_) =>
                    fail('A disabled slider cannot propose a value'),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(view.gestureRecognizers, isEmpty);
      await event('start', .5);
      await event('change', .8);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(UiKitView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
    },
  );

  testWidgets(
    'one atomic configuration includes range, direction and styling',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        host(
          NativeValueControl(
            kind: 'slider',
            value: 50,
            min: 20,
            max: 80,
            divisions: 6,
            enabled: true,
            accent: Colors.orange,
            semanticLabel: 'Volume',
            onChanged: (_) => changes++,
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(config(), containsPair('value', 50.0));
      expect(config(), containsPair('min', 20.0));
      expect(config(), containsPair('max', 80.0));
      expect(config(), containsPair('divisions', 6));
      expect(config(), containsPair('rtl', true));
      expect(config(), containsPair('accent', Colors.orange.toARGB32()));
      expect(changes, 0);
    },
  );

  testWidgets('rejected native edit is reconciled without a parent rebuild', (
    tester,
  ) async {
    final changed = <double>[];
    await tester.pumpWidget(
      host(
        NativeValueControl(
          kind: 'slider',
          value: .25,
          enabled: true,
          onChanged: changed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await event('start', .25);
    await event('change', .75);
    await tester.pumpAndSettle();
    expect(changed, [.75]);
    expect(config()['value'], .25);
  });

  testWidgets(
    'accepted change sends new controlled value and external rollback',
    (tester) async {
      var value = .25;
      late StateSetter update;
      final changed = <double>[];
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return NativeValueControl(
                kind: 'slider',
                value: value,
                enabled: true,
                onChanged: (next) {
                  changed.add(next);
                  setState(() => value = next);
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await event('start', .25);
      final revision = config()['revision'] as int;
      await event('change', .75);
      await tester.pumpAndSettle();
      expect(config()['value'], .75);
      expect(config()['revision'], revision);
      expect(config()['valueIsEcho'], isTrue);
      update(() => value = .5);
      await tester.pumpAndSettle();
      expect(config()['value'], .5);
      expect(config()['revision'], greaterThan(revision));
      expect(config()['valueIsEcho'], isFalse);
      await event('change', .9, revision: revision);
      await event('end', .9, revision: revision);
      // Even a falsely relabeled old gesture cannot survive an external reset.
      await event('change', .9);
      expect(changed, [.75]);
    },
  );

  testWidgets('slider accepts queued changes and end after a controlled echo', (
    tester,
  ) async {
    var value = .25;
    final events = <String>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => NativeValueControl(
            kind: 'slider',
            value: value,
            enabled: true,
            onChangeStart: (_) => events.add('start'),
            onChanged: (next) {
              events.add('change:$next');
              update(() => value = next);
            },
            onChangeEnd: (next) => events.add('end:$next'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialRevision = config()['revision'] as int;
    await event('start', .25);
    await event('change', .5);
    await tester.pumpAndSettle();
    expect(config()['valueIsEcho'], isTrue);
    // These were emitted by UIKit before it could receive the first echo.
    await event('change', .75, revision: initialRevision);
    await tester.pumpAndSettle();
    await event('end', .75, revision: initialRevision);
    await event('end', .75, revision: initialRevision);
    await event('change', .9, revision: initialRevision);
    expect(events, ['start', 'change:0.5', 'change:0.75', 'end:0.75']);
    expect(value, .75);
  });

  testWidgets('disabled, stale and malformed events never trigger callbacks', (
    tester,
  ) async {
    var changes = 0;
    Widget control(bool enabled) => host(
      NativeValueControl(
        kind: 'switch',
        value: 0,
        enabled: enabled,
        onChanged: (_) => changes++,
      ),
    );
    await tester.pumpWidget(control(true));
    await tester.pumpAndSettle();
    await event('change', 1, revision: -1);
    await event('change', double.nan);
    expect(changes, 0);
    await tester.pumpWidget(control(false));
    await tester.pumpAndSettle();
    await event('change', 1);
    expect(changes, 0);
  });

  testWidgets('colors can clear and range updates do not emit value changes', (
    tester,
  ) async {
    var changes = 0;
    Widget control(double value, double min, double max, Color? color) => host(
      NativeValueControl(
        kind: 'stepper',
        value: value,
        min: min,
        max: max,
        step: 3,
        wraps: true,
        enabled: true,
        accent: color,
        onChanged: (_) => changes++,
      ),
    );
    await tester.pumpWidget(control(2, 0, 10, Colors.orange));
    await tester.pumpAndSettle();
    await tester.pumpWidget(control(30, 20, 40, null));
    await tester.pumpAndSettle();
    expect(config()['accent'], isNull);
    expect(config()['value'], 30);
    expect(config()['min'], 20);
    expect(config()['max'], 40);
    expect(config()['step'], 3);
    expect(config()['wraps'], true);
    expect(changes, 0);
  });

  testWidgets('start/end events are ordered and cancellation has no commit', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      host(
        NativeValueControl(
          kind: 'slider',
          value: .5,
          enabled: true,
          onChanged: (_) => events.add('change'),
          onChangeStart: (_) => events.add('start'),
          onChangeEnd: (_) => events.add('end'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await event('start', .5);
    await event('change', .75);
    await event('end', .75);
    await event('end', .75);
    await event('start', .5);
    expect(events, ['start', 'change', 'end']);
    await event('cancel', .75);
    expect(events, ['start', 'change', 'end']);
    await tester.pumpAndSettle();
    expect(config()['value'], .5);
  });

  testWidgets('disposed instance ignores late platform messages', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      host(
        NativeValueControl(
          kind: 'switch',
          value: 0,
          enabled: true,
          onChanged: (_) => changes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final revision = config()['revision'] as int;
    await tester.pumpWidget(const SizedBox());
    await event('change', 1, revision: revision);
    expect(changes, 0);
  });

  testWidgets('multiple controls have isolated channels and callbacks', (
    tester,
  ) async {
    final first = <double>[], second = <double>[];
    await tester.pumpWidget(
      host(
        Column(
          children: [
            NativeValueControl(
              kind: 'switch',
              value: 0,
              enabled: true,
              onChanged: first.add,
            ),
            NativeValueControl(
              kind: 'slider',
              value: .5,
              enabled: true,
              onChanged: second.add,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    final ids = calls.keys.toList();
    for (var index = 0; index < ids.length; index++) {
      final viewId = ids[index];
      final arguments =
          calls[viewId]!
                  .lastWhere((call) => call.method == 'configure')
                  .arguments
              as Map;
      if (index == 1) {
        id = viewId;
        await event('start', .5);
      }
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter_adaptive_liquid_glass/value-control/$viewId',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('valueEvent', {
            'phase': 'change',
            'value': index == 0 ? 1.0 : .75,
            'revision': arguments['revision'],
            'gestureId': 1,
          }),
        ),
        (_) {},
      );
    }
    await tester.pumpAndSettle();
    expect(first, [1]);
    expect(second, [.75]);
  });

  testWidgets('native popup controls stay unsuppressed through their exit', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox()),
    );
    navigator.currentState!.push(
      _TestPopup(
        NativeValueControl(
          kind: 'switch',
          value: 0,
          enabled: true,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(config()['popupOwner'], isTrue);
    expect(config()['suppressed'], isFalse);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NativeValueControl), findsOneWidget);
    expect(config()['suppressed'], isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('a covered ancestor popup suppresses nested Navigator controls', (
    tester,
  ) async {
    final rootNavigator = GlobalKey<NavigatorState>();
    final nestedNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: rootNavigator, home: const SizedBox()),
    );
    rootNavigator.currentState!.push(
      _TestPopup(
        SizedBox(
          width: 300,
          height: 300,
          child: Navigator(
            key: nestedNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => const NativeValueControl(
                kind: 'stepper',
                value: 0,
                enabled: true,
                onChanged: _ignoreValue,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(config()['popupOwner'], isTrue);
    expect(config()['suppressed'], isFalse);
    final controlContext = tester.element(find.byType(NativeValueControl));
    rootNavigator.currentState!.push(_TestPopup(const Text('Covered')));
    await tester.pumpAndSettle();
    // The inner route remains current; only its ancestor is covered.
    expect(ModalRoute.of(controlContext)!.isCurrent, isTrue);
    expect(config()['popupOwner'], isTrue);
    expect(config()['suppressed'], isTrue);
    rootNavigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(config()['suppressed'], isFalse);
    expect(calls, hasLength(1));
  });
}

class _TestPopup extends PopupRoute<void> {
  _TestPopup(this.child);
  final Widget child;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => Colors.black26;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Center(child: child);
}

void _ignoreValue(double _) {}
