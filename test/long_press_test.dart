import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_pressable.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final feedback = <MethodCall>[];
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          feedback.add(call);
          return null;
        });
    feedback.clear();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final interruption in ['coverage', 'lifecycle', 'disabled']) {
    testWidgets(
      '$interruption releases a press whose terminal event was lost',
      (tester) async {
        var taps = 0, holds = 0, enabled = true;
        late StateSetter update;
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return LiquidGlassButton(
                  label: 'Open',
                  onPressed: enabled ? () => taps++ : null,
                  onLongPress: enabled ? () => holds++ : null,
                );
              },
            ),
          ),
        );
        final oldInk = tester.widget<InkWell>(find.byType(InkWell));
        final old = await tester.startGesture(
          tester.getCenter(find.text('Open')),
          pointer: 51,
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(holds, 1);
        final route = ModalRoute.of(
          tester.element(find.byType(FallbackPressable)),
        )!;
        final token = Object();
        if (interruption == 'coverage') {
          nativeRouteCoverage.retain(token, [route]);
        } else if (interruption == 'lifecycle') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          update(() => enabled = false);
        }
        await tester.pump();
        if (interruption == 'coverage') {
          nativeRouteCoverage.release(token);
        } else if (interruption == 'lifecycle') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else {
          update(() => enabled = true);
        }
        await tester.pump();
        // The previous hit-test path may never receive its up/cancel. New input
        // must recover, while saved callbacks and a late old cancel stay inert.
        oldInk.onTap!();
        oldInk.onLongPress!();
        expect([taps, holds], [0, 1]);
        final fresh = await tester.startGesture(
          tester.getCenter(find.text('Open')),
          pointer: 52,
        );
        await old.cancel();
        await fresh.up();
        await tester.pumpAndSettle();
        expect([taps, holds], [1, 1]);
      },
    );
  }

  testWidgets('another pointer does not revive a cancelled long press', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      _host(LiquidGlassButton(label: 'Open', onLongPress: () => holds++)),
    );
    final rect = tester.getRect(find.byType(FallbackPressable));
    final first = await tester.startGesture(
      Offset(rect.right - 2, rect.center.dy),
      pointer: 1,
    );
    await first.moveBy(const Offset(5, 0));
    final second = await tester.startGesture(rect.center, pointer: 2);
    await tester.pump(const Duration(milliseconds: 700));
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(holds, 0);
  });

  testWidgets('secondary pointer cannot finish a cancelled primary batch', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      _host(LiquidGlassButton(label: 'Open', onLongPress: () => holds++)),
    );
    final rect = tester.getRect(find.byType(FallbackPressable));
    final first = await tester.startGesture(
      Offset(rect.right - 2, rect.center.dy),
      pointer: 1,
    );
    await first.moveBy(const Offset(30, 0));
    final second = await tester.startGesture(rect.center, pointer: 2);
    await first.up();
    await tester.pump(const Duration(milliseconds: 700));
    await second.up();
    await tester.pumpAndSettle();
    expect(holds, 0);
    await tester.longPress(find.text('Open'));
    await tester.pumpAndSettle();
    expect(holds, 1);
  });

  testWidgets('button long press runs once without a following click', (
    tester,
  ) async {
    var taps = 0, holds = 0;
    await tester.pumpWidget(
      _host(
        LiquidGlassButton(
          label: 'Open',
          onPressed: () => taps++,
          onLongPress: () => holds++,
          longPressSemanticLabel: 'Open options',
        ),
      ),
    );
    await tester.longPress(find.text('Open'));
    await tester.pumpAndSettle();
    expect([taps, holds], [0, 1]);
    expect(
      feedback.where((call) => call.method == 'HapticFeedback.vibrate').length,
      1,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect([taps, holds], [1, 1]);
  });

  testWidgets('long-only icon is enabled and loading disables both actions', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      _host(
        LiquidGlassButton.icon(
          icon: Icons.more_horiz,
          semanticLabel: 'Options',
          onLongPress: () => holds++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.longPress(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(holds, 1);
    await tester.pumpWidget(
      _host(
        LiquidGlassButton(
          label: 'Busy',
          loading: true,
          onPressed: () => holds++,
          onLongPress: () => holds++,
        ),
      ),
    );
    await tester.longPress(find.text('Busy'));
    await tester.tap(find.text('Busy'));
    await tester.pump();
    expect(holds, 1);
  });

  testWidgets('shared actions expose a named semantic long press once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0, holds = 0;
    await tester.pumpWidget(
      _host(
        LiquidGlassButtonGroup(
          actions: [
            LiquidGlassAction(
              id: 'action',
              label: 'Details',
              onPressed: () => taps++,
              onLongPress: () => holds++,
              longPressSemanticLabel: 'Show history',
            ),
            const LiquidGlassAction(id: 'disabled', label: 'Disabled'),
          ],
        ),
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('Details').first);
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );
    tester.binding.performSemanticsAction(
      ui.SemanticsActionEvent(
        type: SemanticsAction.longPress,
        viewId: tester.view.viewId,
        nodeId: node.id,
      ),
    );
    await tester.pump();
    expect([taps, holds], [0, 1]);
    expect(
      feedback.where((call) => call.method == 'HapticFeedback.vibrate').length,
      1,
    );
    await tester.longPress(find.byKey(const ValueKey('action')));
    await tester.pumpAndSettle();
    expect([taps, holds], [0, 2]);
    expect(
      tester
          .widget<FallbackPressable>(find.byKey(const ValueKey('disabled')))
          .onLongPress,
      isNull,
    );
    semantics.dispose();
  });

  testWidgets('navigation passes secondary action through a grouped capsule', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: LiquidGlassNavigationBar(
            title: 'Page',
            actions: [
              LiquidGlassAction(id: 'first', label: 'First', onPressed: () {}),
              LiquidGlassAction(
                id: 'more',
                label: 'More',
                onLongPress: () => holds++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('more')));
    await tester.pumpAndSettle();
    expect(holds, 1);
  });

  testWidgets(
    'fallback segment selection emits selection feedback without click sound',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 260,
              child: LiquidGlassSegmentedControl<int>(
                segments: const [
                  LiquidGlassSegment(value: 0, label: 'First'),
                  LiquidGlassSegment(value: 1, label: 'Second'),
                ],
                selected: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(
        feedback
            .where((call) => call.method == 'HapticFeedback.vibrate')
            .map((call) => call.arguments),
        ['HapticFeedbackType.selectionClick'],
      );
      expect(
        feedback.where((call) => call.method == 'SystemSound.play'),
        isEmpty,
      );
      feedback.clear();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(feedback, isEmpty);
    },
  );

  testWidgets('fallback tabs emit feedback only when selection changes', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 320,
            child: LiquidGlassTabBar(
              items: const [
                LiquidGlassTabItem(label: 'Home', icon: Icons.home),
                LiquidGlassTabItem(label: 'Files', icon: Icons.folder),
              ],
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(
      feedback.where((call) => call.method == 'HapticFeedback.vibrate').length,
      1,
    );
    expect(
      feedback.where((call) => call.method == 'SystemSound.play'),
      isEmpty,
    );
    feedback.clear();
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(feedback, isEmpty);
  });
}

Widget _host(Widget child) => MaterialApp(
  home: LiquidGlassTheme(
    data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
    child: Scaffold(body: Center(child: child)),
  ),
);
