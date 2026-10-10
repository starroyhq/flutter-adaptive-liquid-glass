import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <int, List<Map<dynamic, dynamic>>>{};
  final creations = <int, Map<dynamic, dynamic>>{};
  Completer<void>? creating;
  Completer<void>? configuring;

  setUp(() {
    calls.clear();
    creations.clear();
    creating = null;
    configuring = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final id = args['id'] as int;
          creations[id] =
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(args['params'] as Uint8List),
                  )
                  as Map;
          calls[id] = [];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel('flutter_adaptive_liquid_glass/status/$id'),
            (call) async {
              expect(call.method, 'configure');
              calls[id]!.add(call.arguments as Map);
              await configuring?.future;
              return null;
            },
          );
          await creating?.future;
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
    for (final id in calls.keys) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('flutter_adaptive_liquid_glass/status/$id'),
        null,
      );
    }
  });

  Widget host(
    Widget child, {
    Brightness brightness = Brightness.light,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 250, child: Center(child: child)),
        ),
      ),
    ),
  );

  Map<dynamic, dynamic> latest() => calls.values.single.last;

  testWidgets(
    'updates during native creation apply the latest complete state',
    (tester) async {
      creating = Completer<void>();
      await tester.pumpWidget(
        host(const NativeStatus(kind: 'progress', height: 4, progress: .1)),
      );
      await tester.pump();
      expect(creations.values.single['progress'], .1);
      expect(calls.values.single, isEmpty);
      await tester.pumpWidget(
        host(
          const NativeStatus(
            kind: 'progress',
            height: 8,
            progress: .9,
            color: Colors.teal,
            trackColor: Colors.amber,
          ),
          brightness: Brightness.dark,
          direction: TextDirection.rtl,
        ),
      );
      expect(calls.values.single, isEmpty);
      creating!.complete();
      await tester.pumpAndSettle();
      expect(creations, hasLength(1));
      expect(latest()['progress'], .9);
      expect(latest()['height'], 8);
      expect(latest()['color'], Colors.teal.toARGB32());
      expect(latest()['trackColor'], Colors.amber.toARGB32());
      expect(latest()['dark'], isTrue);
      expect(latest()['rtl'], isTrue);
    },
  );

  testWidgets('in-flight updates coalesce without losing the final progress', (
    tester,
  ) async {
    configuring = Completer<void>();
    await tester.pumpWidget(
      host(const NativeStatus(kind: 'progress', height: 4, progress: .1)),
    );
    await tester.pump();
    expect(calls.values.single, hasLength(1));
    for (final value in [.2, .5, .8]) {
      await tester.pumpWidget(
        host(NativeStatus(kind: 'progress', height: 4, progress: value)),
      );
    }
    expect(calls.values.single, hasLength(1));
    configuring!.complete();
    await tester.pumpAndSettle();
    expect(calls.values.single, hasLength(2));
    expect(latest()['progress'], .8);
    expect(creations, hasLength(1));
  });

  testWidgets('activity styling and cleared colors update the retained view', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const NativeStatus(
          kind: 'activity',
          height: 44,
          width: 44,
          animating: true,
          color: Colors.red,
          trackColor: Colors.blue,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(
        const NativeStatus(
          kind: 'activity',
          height: 64,
          width: 64,
          style: 'large',
          animating: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(latest()['animating'], isFalse);
    expect(latest()['style'], 'large');
    expect(latest()['color'], isNull);
    expect(latest()['trackColor'], isNull);
    expect(latest()['height'], 64);
    expect(tester.getSize(find.byType(UiKitView)), const Size(64, 64));
    expect(creations, hasLength(1));
  });

  testWidgets('multiple status views retain independent configurations', (
    tester,
  ) async {
    Widget content(double progress) => host(
      Column(
        children: [
          const NativeStatus(kind: 'activity', height: 44, animating: true),
          NativeStatus(kind: 'progress', height: 4, progress: progress),
        ],
      ),
    );
    await tester.pumpWidget(content(.2));
    await tester.pumpAndSettle();
    final activity = creations.entries
        .singleWhere((entry) => entry.value['kind'] == 'activity')
        .key;
    final progress = creations.entries
        .singleWhere((entry) => entry.value['kind'] == 'progress')
        .key;
    final activityCalls = calls[activity]!.length;
    await tester.pumpWidget(content(.7));
    await tester.pumpAndSettle();
    expect(calls[activity], hasLength(activityCalls));
    expect(calls[activity]!.last['animating'], isTrue);
    expect(calls[progress]!.last['progress'], .7);
    expect(creations, hasLength(2));
  });

  testWidgets('late creation after disposal does not send a configuration', (
    tester,
  ) async {
    creating = Completer<void>();
    await tester.pumpWidget(
      host(const NativeStatus(kind: 'progress', height: 4)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    creating!.complete();
    await tester.pumpAndSettle();
    expect(calls.values.single, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose during a configuration drops pending updates', (
    tester,
  ) async {
    configuring = Completer<void>();
    await tester.pumpWidget(
      host(const NativeStatus(kind: 'progress', height: 4)),
    );
    await tester.pump();
    await tester.pumpWidget(
      host(const NativeStatus(kind: 'progress', height: 4, progress: .8)),
    );
    await tester.pumpWidget(const SizedBox());
    configuring!.complete();
    await tester.pumpAndSettle();
    expect(calls.values.single, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native popup status stays visible during its reverse transition',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox()),
      );
      navigator.currentState!.push(
        _TestPopup(const NativeStatus(kind: 'progress', height: 4)),
      );
      await tester.pumpAndSettle();
      expect(latest()['popupOwner'], isTrue);
      expect(latest()['suppressed'], isFalse);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NativeStatus), findsOneWidget);
      expect(latest()['suppressed'], isFalse);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'covered ancestor popup suppresses status in a nested Navigator',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox()),
      );
      navigator.currentState!.push(
        _TestPopup(
          SizedBox(
            width: 300,
            height: 300,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => const NativeStatus(
                  kind: 'activity',
                  height: 44,
                  animating: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(latest()['popupOwner'], isTrue);
      expect(latest()['suppressed'], isFalse);
      final innerContext = tester.element(find.byType(NativeStatus));
      navigator.currentState!.push(_TestPopup(const Text('Overlay')));
      await tester.pumpAndSettle();
      expect(ModalRoute.of(innerContext)!.isCurrent, isTrue);
      expect(latest()['suppressed'], isTrue);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(latest()['suppressed'], isFalse);
      expect(creations, hasLength(1));
    },
  );
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
