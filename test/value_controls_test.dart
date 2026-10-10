import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/theme.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_value_controls.dart';
import 'package:flutter_adaptive_liquid_glass/src/value_controls.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
  bool disableAnimations = false,
}) => MaterialApp(
  home: LiquidGlassTheme(
    data: LiquidGlassThemeData(
      mode: LiquidGlassMode.fallback,
      reduceMotion: reduceMotion,
    ),
    child: Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ),
);

void main() {
  testWidgets('slider emits start, snapped changes, and end while dragging', (
    tester,
  ) async {
    var value = .5;
    final changes = <double>[], starts = <double>[], ends = <double>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 300,
            child: LiquidGlassSlider(
              value: value,
              divisions: 4,
              onChanged: (next) {
                changes.add(next);
                setState(() => value = next);
              },
              onChangeStart: starts.add,
              onChangeEnd: ends.add,
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(FallbackGlassSlider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(changes, isNotEmpty);
    expect(changes.every((v) => v * 4 == (v * 4).round()), isTrue);
    expect(starts, hasLength(1));
    expect(ends, hasLength(1));
    expect(value, greaterThan(.5));
  });

  testWidgets(
    'slider exposes one adjustable semantic node and formatted value',
    (tester) async {
      final handle = tester.ensureSemantics();
      double? changed;
      await tester.pumpWidget(
        host(
          LiquidGlassSlider(
            value: 20,
            min: 0,
            max: 100,
            divisions: 5,
            semanticLabel: 'Volume',
            semanticFormatterCallback: (value) => '${value.toInt()} units',
            onChanged: (value) => changed = value,
          ),
        ),
      );
      final finder = find.semantics.byLabel('Volume');
      expect(finder, findsOneWidget);
      final node = tester.getSemantics(find.byType(LiquidGlassSlider));
      expect(node.value, '20 units');
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.increase,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      expect(changed, 40);
      handle.dispose();
    },
  );

  testWidgets('slider horizontal direction follows RTL', (tester) async {
    double? changed;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 300,
          child: LiquidGlassSlider(
            value: .5,
            onChanged: (value) => changed = value,
          ),
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.drag(find.byType(FallbackGlassSlider), const Offset(60, 0));
    expect(changed, lessThan(.5));
  });

  testWidgets(
    'disabled slider does not expose adjustment or start/end events',
    (tester) async {
      var starts = 0, ends = 0;
      await tester.pumpWidget(
        host(
          LiquidGlassSlider(
            value: .5,
            onChanged: null,
            onChangeStart: (_) => starts++,
            onChangeEnd: (_) => ends++,
          ),
        ),
      );
      await tester.drag(find.byType(FallbackGlassSlider), const Offset(80, 0));
      expect(starts, 0);
      expect(ends, 0);
    },
  );

  testWidgets('switch remains controlled and can be disabled externally', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      host(LiquidGlassSwitch(value: false, onChanged: (_) => changes++)),
    );
    await tester.tap(find.byType(FallbackGlassSwitch));
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(
      tester
          .widget<FallbackGlassSwitch>(find.byType(FallbackGlassSwitch))
          .value,
      isFalse,
    );
    await tester.pumpWidget(
      host(const LiquidGlassSwitch(value: true, onChanged: null)),
    );
    await tester.tap(find.byType(FallbackGlassSwitch));
    expect(changes, 1);
    expect(
      tester
          .widget<FallbackGlassSwitch>(find.byType(FallbackGlassSwitch))
          .value,
      isTrue,
    );
  });

  for (final system in [false, true]) {
    testWidgets(
      'reduced motion slider snaps immediately (${system ? 'system' : 'theme'})',
      (tester) async {
        var value = .25;
        late StateSetter update;
        final changes = <double>[], starts = <double>[], ends = <double>[];
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SizedBox(
                  width: 300,
                  child: LiquidGlassSlider(
                    value: value,
                    divisions: 4,
                    onChanged: (next) {
                      changes.add(next);
                      setState(() => value = next);
                    },
                    onChangeStart: starts.add,
                    onChangeEnd: ends.add,
                  ),
                );
              },
            ),
            reduceMotion: !system,
            disableAnimations: system,
          ),
        );
        await tester.pumpAndSettle();
        update(() => value = .5);
        await tester.pump();
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason:
              'A discrete value must reach its endpoint without a position ticker.',
        );
        await tester.drag(
          find.byType(FallbackGlassSlider),
          const Offset(75, 0),
        );
        await tester.pump();
        expect(value, greaterThan(.5));
        expect(changes.every((next) => next * 4 == (next * 4).round()), isTrue);
        expect(starts, hasLength(1));
        expect(ends, [value]);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'reduced motion switch retains drag, keyboard and focus (${system ? 'system' : 'theme'})',
      (tester) async {
        var value = false;
        var accept = true;
        var callbacks = 0;
        late StateSetter update;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return LiquidGlassSwitch(
                  value: value,
                  onChanged: (next) {
                    callbacks++;
                    if (accept) setState(() => value = next);
                  },
                );
              },
            ),
            direction: TextDirection.rtl,
            reduceMotion: !system,
            disableAnimations: system,
          ),
        );
        await tester.pumpAndSettle();
        final switchFocus = find.descendant(
          of: find.byType(FallbackGlassSwitch),
          matching: find.byType(FocusableActionDetector),
        );
        final focus = tester
            .widget<FocusableActionDetector>(switchFocus)
            .focusNode!;
        focus.requestFocus();
        await tester.pump();
        await tester.drag(
          find.byType(FallbackGlassSwitch),
          const Offset(-65, 0),
        );
        await tester.pump();
        expect(value, isTrue);
        expect(callbacks, 1);
        expect(focus.hasFocus, isTrue);
        expect(
          tester.widget<FocusableActionDetector>(switchFocus).focusNode,
          same(focus),
        );
        expect(tester.binding.transientCallbackCount, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(value, isFalse);
        expect(callbacks, 2);
        expect(tester.binding.transientCallbackCount, 0);
        update(() => accept = false);
        await tester.pump();
        await tester.drag(
          find.byType(FallbackGlassSwitch),
          const Offset(-65, 0),
        );
        await tester.pump();
        expect(value, isFalse);
        expect(callbacks, 3);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets('stepper clamps partial steps or wraps beyond endpoints', (
    tester,
  ) async {
    var value = 9.0;
    var wraps = false;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidGlassStepper(
              value: value,
              max: 10,
              step: 3,
              wraps: wraps,
              onChanged: (next) => setState(() => value = next),
            );
          },
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('liquid-glass-stepper-increase')),
    );
    await tester.pump();
    expect(value, 10);
    update(() => wraps = true);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('liquid-glass-stepper-increase')),
    );
    await tester.pump();
    expect(value, 0);
    await tester.tap(
      find.byKey(const ValueKey('liquid-glass-stepper-decrease')),
    );
    await tester.pump();
    expect(value, 10);
    update(() => value = 9);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('liquid-glass-stepper-increase')),
    );
    await tester.pump();
    expect(value, 0);
  });

  testWidgets('stepper long press repeats and stops on release and disposal', (
    tester,
  ) async {
    var value = 0.0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassStepper(
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('liquid-glass-stepper-increase')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 110));
    }
    expect(value, greaterThanOrEqualTo(4));
    await gesture.up();
    final released = value;
    await tester.pump(const Duration(seconds: 1));
    expect(value, released);
    final next = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('liquid-glass-stepper-increase')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox());
    await next.cancel();
    final disposed = value;
    await tester.pump(const Duration(seconds: 1));
    expect(value, disposed);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stepper stops repeating when upper boundary disables increment',
    (tester) async {
      var value = 0.0;
      var changes = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => LiquidGlassStepper(
              value: value,
              max: 2,
              onChanged: (next) {
                changes++;
                setState(() => value = next);
              },
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('liquid-glass-stepper-increase')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 110));
      }
      await gesture.up();
      expect(value, 2);
      expect(changes, 2);
    },
  );

  testWidgets(
    'stepper repeat stops on pointer cancellation and backgrounding',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        host(LiquidGlassStepper(value: 0, onChanged: (_) => changes++)),
      );
      var gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('liquid-glass-stepper-increase')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.cancel();
      var stopped = changes;
      await tester.pump(const Duration(seconds: 1));
      expect(changes, stopped);
      gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('liquid-glass-stepper-increase')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      stopped = changes;
      await tester.pump(const Duration(seconds: 1));
      expect(changes, stopped);
      await gesture.cancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'stepper disabled and theme updates preserve the supplied value',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        host(LiquidGlassStepper(value: 5, onChanged: (_) => changes++)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: LiquidGlassTheme(
            data: const LiquidGlassThemeData(
              mode: LiquidGlassMode.fallback,
              colors: LiquidGlassColors(accent: Colors.orange),
            ),
            child: const Center(
              child: LiquidGlassStepper(value: 5, onChanged: null),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('liquid-glass-stepper-increase')),
      );
      expect(changes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
