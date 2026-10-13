import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_pressable.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_selection_track.dart';

void main() {
  for (final tabs in [true, false]) {
    final name = tabs ? 'tabs' : 'segments';

    testWidgets('$name share one thumb that moves and can reverse mid-flight', (
      tester,
    ) async {
      final callbacks = <int>[];
      Future<void> show(int selected) => tester.pumpWidget(
        _host(tabs: tabs, selected: selected, onChanged: callbacks.add),
      );
      await show(0);
      final first = _thumbRect(tester);
      expect(
        first.center.dx,
        closeTo(_target(tester, 'Computers').center.dx, .1),
      );
      await tester.tap(find.text('Account'));
      expect(callbacks, [2]);
      // Controlled selection waits for the owner to apply the value.
      expect(_thumbRect(tester), first);
      await show(2);
      expect(_thumbRect(tester), first);
      await tester.pump(const Duration(milliseconds: 90));
      final moving = _thumbRect(tester);
      final lastX = _target(tester, 'Account').center.dx;
      expect(moving.center.dx, greaterThan(first.center.dx));
      expect(moving.center.dx, lessThan(lastX));
      await show(0);
      expect(_thumbRect(tester).left, closeTo(moving.left, .1));
      await tester.pumpAndSettle();
      expect(_thumbRect(tester), first);
      expect(callbacks, [2]);
      expect(find.byType(FallbackSelectionTrack), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('$name keep geometry in RTL, large text and a resized layout', (
      tester,
    ) async {
      for (final direction in TextDirection.values) {
        for (final width in [320.0, 420.0]) {
          await tester.pumpWidget(
            _host(
              tabs: tabs,
              selected: 1,
              direction: direction,
              width: width,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final selected = _target(tester, 'Sessions');
          expect(_thumbRect(tester).center.dx, closeTo(selected.center.dx, .1));
          expect(_thumbRect(tester).height, selected.height);
          for (final label in _labels) {
            final target = _target(tester, label);
            expect(target.width, greaterThanOrEqualTo(48));
            expect(target.height, greaterThanOrEqualTo(48));
          }
          final first = _target(tester, 'Computers').center.dx;
          final last = _target(tester, 'Account').center.dx;
          expect(
            direction == TextDirection.rtl ? first > last : first < last,
            isTrue,
          );
        }
      }
    });

    testWidgets('$name stop motion without removing the glass material', (
      tester,
    ) async {
      for (final systemSetting in [false, true]) {
        await tester.pumpWidget(
          _host(tabs: tabs, selected: 0, key: ValueKey(systemSetting)),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _host(
            tabs: tabs,
            selected: 2,
            key: ValueKey(systemSetting),
            reduceMotion: !systemSetting,
            disableAnimations: systemSetting,
          ),
        );
        expect(
          _thumbRect(tester).center.dx,
          closeTo(_target(tester, 'Account').center.dx, .1),
        );
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    });

    testWidgets('$name stop in-flight travel when reduced motion is enabled', (
      tester,
    ) async {
      for (final systemSetting in [false, true]) {
        final callbacks = <int>[];
        Widget host(int selected, {bool reduced = false}) => _host(
          tabs: tabs,
          selected: selected,
          key: ValueKey(systemSetting),
          reduceMotion: reduced && !systemSetting,
          disableAnimations: reduced && systemSetting,
          onChanged: callbacks.add,
        );
        await tester.pumpWidget(host(0));
        await tester.pumpAndSettle();
        final first = _thumbRect(tester);
        final control = find.ancestor(
          of: find.text('Account'),
          matching: find.byType(FallbackPressable),
        );
        final controlState = tester.state(control);
        await tester.pumpWidget(host(2));
        await tester.pump(const Duration(milliseconds: 90));
        final moving = _thumbRect(tester);
        final targetX = _target(tester, 'Account').center.dx;
        expect(moving.center.dx, greaterThan(first.center.dx));
        expect(moving.center.dx, lessThan(targetX));

        // Keep the selected value unchanged: the preference itself must end
        // an existing animation, without recreating the interactive children.
        await tester.pumpWidget(host(2, reduced: true));
        final stopped = _thumbRect(tester);
        expect(stopped.center.dx, closeTo(targetX, .1));
        expect(tester.state(control), same(controlState));
        // Dispose may leave one already-requested frame in the scheduler;
        // flushing it without advancing time must not move or restart travel.
        await tester.pump();
        expect(_thumbRect(tester), stopped);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 220));
        expect(_thumbRect(tester), stopped);

        // Re-enabling motion leaves the current selection still, but future
        // selections animate normally instead of resuming the cancelled travel.
        await tester.pumpWidget(host(2));
        expect(_thumbRect(tester), stopped);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(host(0));
        await tester.pump(const Duration(milliseconds: 90));
        final returning = _thumbRect(tester);
        expect(returning.center.dx, greaterThan(first.center.dx));
        expect(returning.center.dx, lessThan(targetX));
        await tester.pumpAndSettle();
        expect(_thumbRect(tester), first);
        expect(callbacks, isEmpty);
      }
    });

    testWidgets('$name retain selection and readable labels across themes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final dark in [false, true, false]) {
          await tester.pumpWidget(_host(tabs: tabs, selected: 2, dark: dark));
          await tester.pumpAndSettle();
          final selected = tester.getSemantics(
            find.bySemanticsLabel('Account'),
          );
          expect(
            selected.getSemanticsData().flagsCollection.isSelected,
            Tristate.isTrue,
          );
          expect(
            selected.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(
            _thumbRect(tester).center.dx,
            closeTo(_target(tester, 'Account').center.dx, .1),
          );
          final text = tester.widget<Text>(find.text('Account'));
          expect(text.style!.color, dark ? Colors.white : Colors.black);
        }
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('disabled segments expose no activation action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          tabs: false,
          selected: 0,
          disabled: true,
          onChanged: (_) => taps++,
        ),
      );
      await tester.tap(find.text('Account'));
      final node = tester.getSemantics(find.bySemanticsLabel('Account'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(
        node.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      expect(taps, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('out-of-range selection hides the thumb without throwing', (
    tester,
  ) async {
    for (final index in [-1, 3, 99]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FallbackSelectionTrack(
              selectedIndex: index,
              children: [
                for (var i = 0; i < 3; i++) const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      );
      final hidden = find.descendant(
        of: find.byType(FallbackSelectionTrack),
        matching: find.byType(Offstage),
      );
      expect(tester.widget<Offstage>(hidden.first).offstage, isTrue);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FallbackSelectionTrack(
            selectedIndex: 1,
            children: [for (var i = 0; i < 3; i++) const SizedBox(height: 48)],
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<Offstage>(
            find.descendant(
              of: find.byType(FallbackSelectionTrack),
              matching: find.byType(Offstage),
            ),
          )
          .any((widget) => widget.offstage),
      isFalse,
    );
  });
}

const _labels = ['Computers', 'Sessions', 'Account'];

Rect _thumbRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(FallbackSelectionTrack),
    matching: find.byType(FractionallySizedBox),
  ),
);

Rect _target(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(FallbackPressable)),
);

Widget _host({
  Key? key,
  required bool tabs,
  required int selected,
  ValueChanged<int>? onChanged,
  bool dark = false,
  bool reduceMotion = false,
  bool disableAnimations = false,
  bool disabled = false,
  double width = 360,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  key: key,
  themeAnimationDuration: Duration.zero,
  theme: ThemeData(
    colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(onSurface: dark ? Colors.white : Colors.black),
  ),
  home: Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: LiquidGlassTheme(
        data: LiquidGlassThemeData(
          mode: LiquidGlassMode.fallback,
          reduceMotion: reduceMotion,
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: tabs
                  ? LiquidGlassTabBar(
                      items: const [
                        LiquidGlassTabItem(
                          label: 'Computers',
                          icon: Icons.computer,
                        ),
                        LiquidGlassTabItem(label: 'Sessions', icon: Icons.chat),
                        LiquidGlassTabItem(
                          label: 'Account',
                          icon: Icons.person,
                        ),
                      ],
                      selectedIndex: selected,
                      onSelected: onChanged ?? (_) {},
                    )
                  : LiquidGlassSegmentedControl<int>(
                      segments: [
                        for (var i = 0; i < _labels.length; i++)
                          LiquidGlassSegment(value: i, label: _labels[i]),
                      ],
                      selected: selected,
                      onChanged: disabled ? null : onChanged ?? (_) {},
                    ),
            ),
          ),
        ),
      ),
    ),
  ),
);
