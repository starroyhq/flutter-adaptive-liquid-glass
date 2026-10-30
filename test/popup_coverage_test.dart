import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_pressable.dart';
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

const _lifecycle = MethodChannel('flutter_adaptive_liquid_glass/lifecycle');
const _page = ValueKey('page');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final viewChannels = <MethodChannel>[];
  late List<String> lifecycle;

  setUp(() {
    lifecycle = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, (
      call,
    ) async {
      lifecycle.add(call.method);
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final type = arguments['viewType'] as String;
          final channel = MethodChannel('$type/${arguments['id']}');
          viewChannels.add(channel);
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'intrinsicSize' ? {'width': 120.0} : null,
          );
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    for (final channel in viewChannels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
    viewChannels.clear();
  });

  // The page button's native view takes part in painting.
  bool nativeShown(WidgetTester tester, [Key key = _page]) => tester
      .widget<Visibility>(
        find
            .descendant(
              of: find.byKey(key, skipOffstage: false),
              matching: find.byType(Visibility, skipOffstage: false),
            )
            .first,
      )
      .visible;

  // The page button's Flutter stand-in is built.
  bool standIn(WidgetTester tester, [Key key = _page]) => find
      .descendant(
        of: find.byKey(key, skipOffstage: false),
        matching: find.byType(FallbackPressable, skipOffstage: false),
      )
      .evaluate()
      .isNotEmpty;

  Future<GlobalKey<NavigatorState>> pumpPage(
    WidgetTester tester, {
    bool observe = true,
  }) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = LiquidGlassNavigatorObserver.debug(nativeAvailable: true);
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [if (observe) observer],
        builder: (context, child) =>
            LiquidGlassTheme(data: const _NativeTheme(), child: child!),
        home: Scaffold(
          body: Center(
            child: LiquidGlassButton(
              key: _page,
              label: 'Page action',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(nativeShown(tester), isTrue);
    expect(standIn(tester), isFalse);
    return navigator;
  }

  testWidgets(
    'an isolating popup swaps native controls for stand-ins in one frame',
    (tester) async {
      final navigator = await pumpPage(tester);
      unawaited(navigator.currentState!.push(_Popup()));
      // Every frame of the entrance, the presentation and the exit draws the
      // control exactly once: natively or as its stand-in, never neither.
      await tester.pump();
      expect(nativeShown(tester), isFalse);
      expect(standIn(tester), isTrue);
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(nativeShown(tester), isFalse);
        expect(standIn(tester), isTrue);
      }
      await tester.pumpAndSettle();
      expect(standIn(tester), isTrue);
      // The stand-in takes neither input nor accessibility focus.
      final stand = find.byType(FallbackPressable);
      expect(
        find.ancestor(of: stand, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: stand, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );

      navigator.currentState!.pop();
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        expect(nativeShown(tester), isFalse);
        expect(standIn(tester), isTrue);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      // Once the exit completes, the native view returns and the stand-in
      // leaves in the same frame.
      expect(nativeShown(tester), isTrue);
      expect(standIn(tester), isFalse);
    },
  );

  testWidgets('a pushed page hides the controls below without stand-ins', (
    tester,
  ) async {
    final navigator = await pumpPage(tester);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isFalse);
    expect(standIn(tester), isFalse);
  });

  testWidgets('without an observer a popup hides native views as before', (
    tester,
  ) async {
    final navigator = await pumpPage(tester, observe: false);
    unawaited(navigator.currentState!.push(_Popup()));
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isFalse);
    expect(standIn(tester), isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isTrue);
    expect(lifecycle, isEmpty);
  });
}

class _Popup extends PopupRoute<void> {
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => Colors.black26;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const Center(child: Material(child: Text('Popup')));
}
