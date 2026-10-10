import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

const _lifecycle = MethodChannel('liquid-glass-lifecycle');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  late List<LiquidGlassNavigatorObserver> observers;

  LiquidGlassNavigatorObserver observer({bool available = true}) {
    final value = LiquidGlassNavigatorObserver.debug(
      nativeAvailable: available,
    );
    observers.add(value);
    return value;
  }

  setUp(() {
    calls = [];
    observers = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
  });

  tearDown(() async {
    for (final value in observers) {
      value.dispose();
    }
    await _flush();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, null);
  });

  testWidgets('pop keeps native views hidden through the exit animation', (
    tester,
  ) async {
    final lifecycleObserver = observer();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [lifecycleObserver],
        home: const Scaffold(body: Text('Page')),
      ),
    );
    final route = _AnimatedPopup();
    unawaited(navigator.currentState!.push(route));
    await tester.pumpAndSettle();
    expect(calls, ['suppressGlassEffects']);

    var completed = false;
    unawaited(route.completed.then((_) => completed = true));
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(completed, isFalse);
    expect(find.text('Popup'), findsOneWidget);
    expect(calls, ['suppressGlassEffects']);

    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Popup'), findsNothing);
    expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);
  });

  test('nested popups release only when the last exit completes', () async {
    final value = observer();
    final outer = _ControlledPopup();
    final inner = _ControlledPopup();
    value.didPush(outer, null);
    value.didPush(inner, outer);
    await _flush();
    expect(calls, ['suppressGlassEffects']);

    value.didPop(inner, outer);
    inner.finish();
    await _flush();
    expect(calls, ['suppressGlassEffects']);
    value.didPop(outer, null);
    await _flush();
    expect(calls, ['suppressGlassEffects']);
    outer.finish();
    await _flush();
    expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);
  });

  test(
    'rapid pop then push never restores views under the new popup',
    () async {
      final value = observer();
      final old = _ControlledPopup();
      final next = _ControlledPopup();
      value.didPush(old, null);
      value.didPop(old, null);
      value.didPush(next, null);
      old.finish();
      await _flush();
      expect(calls, ['suppressGlassEffects']);

      value.didRemove(next, null);
      await _flush();
      expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);
    },
  );

  test('popup replacement has no intermediate native restore', () async {
    final value = observer();
    final old = _ControlledPopup();
    final next = _ControlledPopup();
    value.didPush(old, null);
    await _flush();
    value.didReplace(oldRoute: old, newRoute: next);
    await _flush();
    expect(calls, ['suppressGlassEffects']);

    value.didReplace(oldRoute: next, newRoute: next);
    value.didRemove(old, null);
    await _flush();
    expect(calls, ['suppressGlassEffects']);
    value.didRemove(next, null);
    await _flush();
    expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);
  });

  test(
    'remove, repeated notifications and late completion are idempotent',
    () async {
      final value = observer();
      final old = _ControlledPopup();
      final next = _ControlledPopup();
      value.didPush(old, null);
      value.didPush(old, null);
      value.didPop(old, null);
      value.didPop(old, null);
      value.didRemove(old, null);
      value.didRemove(old, null);
      await _flush();
      expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);

      value.didPush(next, null);
      old.finish();
      await _flush();
      expect(calls, [
        'suppressGlassEffects',
        'unsuppressGlassEffects',
        'suppressGlassEffects',
      ]);
      value.didRemove(next, null);
      await _flush();
      expect(calls.last, 'unsuppressGlassEffects');
      expect(calls.length, 4);
    },
  );

  test(
    'an old completion cannot release a new ownership of the same route',
    () async {
      final value = observer();
      final popup = _ControlledPopup();
      value.didPush(popup, null);
      value.didPop(popup, null);
      value.didRemove(popup, null);
      value.didPush(popup, null);
      popup.finish();
      await _flush();
      expect(calls, [
        'suppressGlassEffects',
        'unsuppressGlassEffects',
        'suppressGlassEffects',
      ]);
      value.didRemove(popup, null);
      await _flush();
      expect(calls.last, 'unsuppressGlassEffects');
      expect(calls.length, 4);
    },
  );

  test(
    'separate navigators balance together when one observer is disposed',
    () async {
      final first = observer();
      final second = observer();
      final old = _ControlledPopup();
      final active = _ControlledPopup();
      first.didPush(old, null);
      second.didPush(active, null);
      first.didPop(old, null);
      first.dispose();
      first.dispose();
      first.didPush(_ControlledPopup(), null);
      old.finish();
      await _flush();
      expect(calls, ['suppressGlassEffects']);

      second.didPop(active, null);
      active.finish();
      await _flush();
      expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);
    },
  );

  test(
    'native channel operations remain ordered while a call is pending',
    () async {
      final blocked = Completer<void>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'suppressGlassEffects') await blocked.future;
        return null;
      });
      final first = observer();
      final second = observer();
      first.didPush(_ControlledPopup(), null);
      second.didPush(_ControlledPopup(), null);
      first.dispose();
      second.dispose();
      await _flush();
      expect(calls, ['suppressGlassEffects']);

      blocked.complete();
      await _flush();
      expect(calls, ['suppressGlassEffects', 'unsuppressGlassEffects']);
    },
  );

  test(
    'unavailable platforms and ordinary page routes do not use the channel',
    () async {
      final fallback = observer(available: false);
      final native = observer();
      final popup = _ControlledPopup();
      final page = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      fallback.didPush(popup, null);
      fallback.didPop(popup, null);
      popup.finish();
      native.didPush(page, null);
      native.didRemove(page, null);
      await _flush();
      expect(calls, isEmpty);
    },
  );

  test(
    'plugin errors do not strand subsequent observers in the queue',
    () async {
      var fail = true;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, (
        call,
      ) async {
        calls.add(call.method);
        if (fail) {
          fail = false;
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });
      final first = observer();
      first.didPush(_ControlledPopup(), null);
      first.dispose();
      await _flush();
      final second = observer();
      second.didPush(_ControlledPopup(), null);
      second.dispose();
      await _flush();
      expect(calls, [
        'suppressGlassEffects',
        'unsuppressGlassEffects',
        'suppressGlassEffects',
        'unsuppressGlassEffects',
      ]);
    },
  );
  test(
    'coverage follows replacement of a route below an active popup',
    () async {
      final value = observer();
      final page = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final replacement = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );
      final popup = _ControlledPopup();
      value.didPush(page, null);
      value.didPush(popup, page);
      expect(nativeRouteCoverage.covers(page), isTrue);
      expect(nativeRouteCoverage.covers(popup), isFalse);
      value.didReplace(oldRoute: page, newRoute: replacement);
      expect(nativeRouteCoverage.covers(page), isFalse);
      expect(nativeRouteCoverage.covers(replacement), isTrue);
      value.didPop(popup, replacement);
      expect(nativeRouteCoverage.covers(replacement), isTrue);
      popup.finish();
      await _flush();
      expect(nativeRouteCoverage.covers(replacement), isFalse);
    },
  );

  test(
    'replacement popup remains visible and holds all lower coverage',
    () async {
      final value = observer();
      final page = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final popup = _ControlledPopup();
      final replacement = _ControlledPopup();
      value.didPush(page, null);
      value.didPush(popup, page);
      value.didReplace(oldRoute: popup, newRoute: replacement);
      expect(nativeRouteCoverage.covers(page), isTrue);
      expect(nativeRouteCoverage.covers(replacement), isFalse);
      value.didRemove(replacement, page);
      expect(nativeRouteCoverage.covers(page), isFalse);
      await _flush();
    },
  );

  test(
    'disposing observers clears their coverage without clearing others',
    () async {
      final first = observer();
      final second = observer();
      final page = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final otherPage = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );
      final popup = _ControlledPopup();
      first.didPush(page, null);
      first.didPush(popup, page);
      first.didPop(popup, page);
      second.didPush(otherPage, null);
      second.didPush(_ControlledPopup(), otherPage);
      first.dispose();
      expect(nativeRouteCoverage.covers(page), isFalse);
      expect(nativeRouteCoverage.covers(otherPage), isTrue);
      popup.finish();
      await _flush();
      expect(nativeRouteCoverage.covers(otherPage), isTrue);
      second.dispose();
      expect(nativeRouteCoverage.covers(otherPage), isFalse);
      await _flush();
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _AnimatedPopup extends PopupRoute<void> {
  @override
  Color? get barrierColor => Colors.black54;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Dismiss';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 600);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const Center(child: Material(child: Text('Popup')));
}

class _ControlledPopup extends _AnimatedPopup {
  final _finished = Completer<void>();

  @override
  Future<void> get completed => _finished.future;

  void finish() => _finished.complete();
}
