import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('liquid-glass-lifecycle');

  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      return null;
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('covered subtree cannot receive taps or expose semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    late ModalRoute<dynamic> route;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            route = ModalRoute.of(context)!;
            return Scaffold(
              body: Center(
                child: NativeVisibility(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: Semantics(
                      label: 'Native action',
                      button: true,
                      child: const SizedBox(width: 100, height: 60),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final position = tester.getCenter(find.byType(NativeVisibility));
    await tester.tapAt(position);
    expect(taps, 1);
    final token = Object();
    nativeRouteCoverage.retain(token, [route]);
    addTearDown(() => nativeRouteCoverage.release(token));
    await tester.pump();
    await tester.tapAt(position);
    expect(taps, 1);
    expect(find.semantics.byLabel('Native action'), findsNothing);
    nativeRouteCoverage.release(token);
    await tester.pump();
    await tester.tapAt(position);
    expect(taps, 2);
    expect(find.semantics.byLabel('Native action'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('covered native subtree keeps size and state without painting', (
    tester,
  ) async {
    final observer = LiquidGlassNavigatorObserver.debug(nativeAvailable: true);
    addTearDown(observer.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final pageProbe = GlobalKey<_ProbeState>();
    final popupProbe = GlobalKey<_ProbeState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: Scaffold(
          body: Center(child: _Probe(key: pageProbe)),
        ),
      ),
    );
    final state = pageProbe.currentState!;
    final size = tester.getSize(find.byKey(pageProbe));
    final popup = _Popup(_Probe(key: popupProbe));
    unawaited(navigator.currentState!.push(popup));
    await tester.pumpAndSettle();
    expect(_visible(tester, pageProbe), isFalse);
    expect(_visible(tester, popupProbe), isTrue);
    expect(tester.getSize(find.byKey(pageProbe)), size);
    expect(pageProbe.currentState, same(state));
    final paints = state.paints;
    state.refresh();
    await tester.pump();
    expect(state.paints, paints);
    expect(popupProbe.currentState!.paints, greaterThan(0));

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_visible(tester, pageProbe), isFalse);
    expect(_visible(tester, popupProbe), isTrue);
    state.refresh();
    await tester.pump();
    expect(state.paints, paints);
    await tester.pumpAndSettle();
    expect(_visible(tester, pageProbe), isTrue);
    expect(pageProbe.currentState, same(state));
    expect(state.paints, greaterThan(paints));
  });

  testWidgets('nested popup hides only the covered layers through dismissal', (
    tester,
  ) async {
    final observer = LiquidGlassNavigatorObserver.debug(nativeAvailable: true);
    addTearDown(observer.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final pageProbe = GlobalKey<_ProbeState>();
    final outerProbe = GlobalKey<_ProbeState>();
    final innerProbe = GlobalKey<_ProbeState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: Scaffold(body: _Probe(key: pageProbe)),
      ),
    );
    final outer = _Popup(_Probe(key: outerProbe));
    final inner = _Popup(_Probe(key: innerProbe));
    unawaited(navigator.currentState!.push(outer));
    await tester.pumpAndSettle();
    unawaited(navigator.currentState!.push(inner));
    await tester.pumpAndSettle();
    expect(_visible(tester, pageProbe), isFalse);
    expect(_visible(tester, outerProbe), isFalse);
    expect(_visible(tester, innerProbe), isTrue);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_visible(tester, outerProbe), isFalse);
    await tester.pumpAndSettle();
    expect(_visible(tester, outerProbe), isTrue);
    expect(_visible(tester, pageProbe), isFalse);

    // Removing a lower popup while another remains must not release the page.
    final next = _Popup(const SizedBox());
    unawaited(navigator.currentState!.push(next));
    await tester.pumpAndSettle();
    navigator.currentState!.removeRoute(outer);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_visible(tester, pageProbe), isFalse);
    await tester.pumpAndSettle();
    expect(_visible(tester, pageProbe), isTrue);
  });

  testWidgets('root popup covers native views inside a nested navigator', (
    tester,
  ) async {
    final observer = LiquidGlassNavigatorObserver.debug(nativeAvailable: true);
    final nestedObserver = LiquidGlassNavigatorObserver.debug(
      nativeAvailable: true,
    );
    addTearDown(observer.dispose);
    addTearDown(nestedObserver.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final nested = GlobalKey<NavigatorState>();
    final nestedProbe = GlobalKey<_ProbeState>();
    final rootPopupProbe = GlobalKey<_ProbeState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: Scaffold(
          body: Navigator(
            key: nested,
            observers: [nestedObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _Probe(key: nestedProbe),
            ),
          ),
        ),
      ),
    );
    final popup = _Popup(_Probe(key: rootPopupProbe));
    unawaited(navigator.currentState!.push(popup));
    await tester.pumpAndSettle();
    expect(_visible(tester, nestedProbe), isFalse);
    expect(_visible(tester, rootPopupProbe), isTrue);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_visible(tester, nestedProbe), isFalse);
    await tester.pumpAndSettle();
    expect(_visible(tester, nestedProbe), isTrue);
  });

  testWidgets(
    'route current state still hides covered content without observer',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final probe = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(body: _Probe(key: probe)),
        ),
      );
      unawaited(navigator.currentState!.push(_Popup(const SizedBox())));
      await tester.pumpAndSettle();
      expect(_visible(tester, probe), isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_visible(tester, probe), isTrue);
    },
  );

  testWidgets(
    'nested navigator follows parent coverage without its own observer',
    (tester) async {
      final observer = LiquidGlassNavigatorObserver.debug(
        nativeAvailable: true,
      );
      addTearDown(observer.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final probe = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => _Probe(key: probe)),
            ),
          ),
        ),
      );
      unawaited(navigator.currentState!.push(_Popup(const SizedBox())));
      await tester.pumpAndSettle();
      expect(_visible(tester, probe), isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_visible(tester, probe), isTrue);
    },
  );
}

bool _visible(WidgetTester tester, GlobalKey<_ProbeState> key) => tester
    .widget<Visibility>(
      find.descendant(of: find.byKey(key), matching: find.byType(Visibility)),
    )
    .visible;

class _Popup extends PopupRoute<void> {
  _Popup(this.child);
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
  Duration get reverseTransitionDuration => const Duration(milliseconds: 600);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Center(child: Material(child: child));
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int paints = 0;
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => NativeVisibility(
    child: SizedBox(
      width: 120,
      height: 48,
      child: CustomPaint(painter: _Painter(() => paints++)),
    ),
  );
}

class _Painter extends CustomPainter {
  _Painter(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) => true;
}
