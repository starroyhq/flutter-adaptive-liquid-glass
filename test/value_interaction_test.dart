import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_value_controls.dart';
import 'package:flutter_adaptive_liquid_glass/src/value_controls.dart';
import 'package:flutter_test/flutter_test.dart';

import 'value_controls_test.dart' show host;

void main() {
  final platformCalls = <MethodCall>[];
  setUp(() {
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  int selections() => platformCalls
      .where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      )
      .length;

  testWidgets(
    'external slider reset invalidates old drag but accepts value echoes',
    (tester) async {
      var value = .5;
      late StateSetter update;
      final ends = <double>[];
      var edits = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 300,
                child: LiquidGlassSlider(
                  value: value,
                  onChanged: (next) {
                    edits++;
                    setState(() => value = next);
                  },
                  onChangeEnd: ends.add,
                ),
              );
            },
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FallbackGlassSlider)),
      );
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      final first = value;
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      expect(
        value,
        greaterThan(first),
        reason: 'Accepted echoes must not cancel the active drag.',
      );
      update(() => value = .1);
      await tester.pump();
      final before = edits;
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(value, .1);
      expect(edits, before);
      expect(ends, [.1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'continuous keyboard and semantic slider adjustments only signal boundaries',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var value = .9;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => LiquidGlassSlider(
              value: value,
              semanticLabel: 'Continuous',
              onChanged: (next) => update(() => value = next),
            ),
          ),
        ),
      );
      final focus = tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: find.byType(FallbackGlassSlider),
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(.95, 1e-12));
      expect(selections(), 0);
      final node = tester.getSemantics(find.byType(LiquidGlassSlider));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.increase,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pump();
      expect(value, 1);
      expect(selections(), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(selections(), 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'stepper pointer and semantic taps use the same single click feedback',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var value = 0.0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => LiquidGlassStepper(
              value: value,
              semanticLabel: 'Copies',
              onChanged: (next) => update(() => value = next),
            ),
          ),
        ),
      );
      platformCalls.clear();
      await tester.tap(
        find.byKey(const ValueKey('liquid-glass-stepper-increase')),
      );
      await tester.pump();
      final pointer = platformCalls
          .map((call) => '${call.method}:${call.arguments}')
          .toList();
      expect(pointer, ['SystemSound.play:SystemSoundType.click']);
      platformCalls.clear();
      final node = tester.getSemantics(find.byType(LiquidGlassStepper));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.increase,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pump();
      expect(value, 2);
      expect(
        platformCalls.map((call) => '${call.method}:${call.arguments}'),
        pointer,
      );
      expect(selections(), 0);
      semantics.dispose();
    },
  );

  testWidgets('slider cancellation ends once without another value edit', (
    tester,
  ) async {
    var value = .5;
    final starts = <double>[], changes = <double>[], ends = <double>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => SizedBox(
            width: 300,
            child: LiquidGlassSlider(
              value: value,
              onChanged: (next) {
                changes.add(next);
                update(() => value = next);
              },
              onChangeStart: starts.add,
              onChangeEnd: ends.add,
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FallbackGlassSlider)),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(starts, hasLength(1));
    final beforeCancel = changes.length;
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(ends, [value]);
    expect(changes, hasLength(beforeCancel));
    await tester.tap(find.byType(FallbackGlassSlider));
    await tester.pumpAndSettle();
    expect(starts, hasLength(2));
    expect(ends, hasLength(2));
  });

  testWidgets('disabling an active slider cancels its lifecycle exactly once', (
    tester,
  ) async {
    var value = .5, enabled = true;
    late StateSetter update;
    final ends = <double>[];
    var changes = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 300,
              child: LiquidGlassSlider(
                value: value,
                onChanged: enabled
                    ? (next) {
                        changes++;
                        setState(() => value = next);
                      }
                    : null,
                onChangeEnd: ends.add,
              ),
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FallbackGlassSlider)),
    );
    await gesture.moveBy(const Offset(65, 0));
    await tester.pump();
    update(() => enabled = false);
    await tester.pump();
    final before = changes;
    await gesture.moveBy(const Offset(60, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(ends, [value]);
    expect(changes, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('continuous slider only signals entering endpoints', (
    tester,
  ) async {
    var value = .5;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 300,
              child: FallbackGlassSlider(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FallbackGlassSlider)),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(selections(), 0);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(value, 1);
    expect(selections(), 1);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(selections(), 1);
    await gesture.cancel();
    platformCalls.clear();
    update(() => value = .25);
    await tester.pumpAndSettle();
    expect(
      platformCalls,
      isEmpty,
      reason: 'External state must not play feedback.',
    );
  });

  testWidgets('dense discrete channels can suppress intermediate ticks', (
    tester,
  ) async {
    var value = 128.0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => SizedBox(
            width: 300,
            child: FallbackGlassSlider(
              value: value,
              max: 255,
              divisions: 255,
              continuousFeedback: false,
              onChanged: (next) => update(() => value = next),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FallbackGlassSlider)),
    );
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(value, greaterThan(128));
    expect(selections(), 0);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(value, 255);
    expect(selections(), 1);
    await gesture.up();
  });

  testWidgets(
    'slider keyboard respects RTL and keeps focus across reduced motion',
    (tester) async {
      var value = .5;
      Widget app(bool reduce) => host(
        StatefulBuilder(
          builder: (context, update) => LiquidGlassSlider(
            value: value,
            divisions: 4,
            onChanged: (next) => update(() => value = next),
          ),
        ),
        direction: TextDirection.rtl,
        reduceMotion: reduce,
      );
      await tester.pumpWidget(app(false));
      final focusFinder = find.descendant(
        of: find.byType(FallbackGlassSlider),
        matching: find.byType(FocusableActionDetector),
      );
      final focus = tester
          .widget<FocusableActionDetector>(focusFinder)
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, .75);
      await tester.pumpWidget(app(true));
      expect(
        tester.widget<FocusableActionDetector>(focusFinder).focusNode,
        same(focus),
      );
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(value, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value, 1);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('switch cancellation and disabling cannot commit a drag', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter update;
    var edits = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidGlassSwitch(
              value: false,
              onChanged: enabled ? (_) => edits++ : null,
            );
          },
        ),
      ),
    );
    var gesture = await tester.startGesture(
      tester.getCenter(find.byType(FallbackGlassSwitch)),
    );
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(edits, 0);
    expect(selections(), 0);
    gesture = await tester.startGesture(
      tester.getCenter(find.byType(FallbackGlassSwitch)),
    );
    await gesture.moveBy(const Offset(60, 0));
    update(() => enabled = false);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(edits, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stepper waits 500 ms then repeats every 100 ms without release tap',
    (tester) async {
      var value = 0.0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => LiquidGlassStepper(
              value: value,
              onChanged: (next) => update(() => value = next),
            ),
          ),
        ),
      );
      final button = find.byKey(
        const ValueKey('liquid-glass-stepper-increase'),
      );
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 499));
      expect(value, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(value, 1);
      await tester.pump(const Duration(milliseconds: 99));
      expect(value, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(value, 2);
      expect(selections(), 0);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(value, 6);
      expect(
        platformCalls.where((call) => call.method == 'HapticFeedback.vibrate'),
        hasLength(1),
        reason:
            'Only long-press recognition signals; timer repeats are silent.',
      );
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(value, 6);
    },
  );

  testWidgets(
    'stepper suppresses repeated stale proposals rejected by its owner',
    (tester) async {
      var proposals = 0;
      await tester.pumpWidget(
        host(LiquidGlassStepper(value: 0, onChanged: (_) => proposals++)),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('liquid-glass-stepper-increase')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(proposals, 1);
      await gesture.up();
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('liquid-glass-stepper-increase')),
      );
      expect(
        proposals,
        2,
        reason: 'A distinct tap starts a fresh user intent.',
      );
    },
  );

  testWidgets('covering a stepper route stops repetition until a new press', (
    tester,
  ) async {
    var value = 0.0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: Center(
              child: LiquidGlassStepper(
                value: value,
                onChanged: (next) => update(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('liquid-glass-stepper-increase')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered')),
      ),
    );
    await tester.pumpAndSettle();
    final before = value;
    await tester.pump(const Duration(seconds: 1));
    expect(value, before);
    await gesture.cancel();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(value, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slider keeps the grab offset on the thumb and jumps elsewhere', (
    tester,
  ) async {
    var value = .5;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 300,
            child: LiquidGlassSlider(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(FallbackGlassSlider));
    // The thumb centre is at 18 + .5 * 264 = 150. Grab its edge, 20 to the right.
    var gesture = await tester.startGesture(
      box.centerLeft + const Offset(170, 0),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(value, closeTo((190 - 18) / 264, .002));

    // Far from the thumb the value follows the touch position.
    final thumb = 18 + value * 264;
    gesture = await tester.startGesture(box.centerLeft + Offset(thumb + 80, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(value, closeTo((thumb + 90 - 18) / 264, .002));
  });
}
