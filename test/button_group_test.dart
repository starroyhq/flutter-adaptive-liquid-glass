import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

void main() {
  testWidgets(
    'adjacent actions share exactly one surface and preserve enabled state',
    (tester) async {
      var first = 0, second = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassButtonGroup(
                actions: [
                  LiquidGlassAction(
                    id: 'first',
                    label: 'Search',
                    icon: Icons.search,
                    onPressed: () => first++,
                  ),
                  const LiquidGlassAction(
                    id: 'disabled',
                    label: 'Disabled',
                    icon: Icons.add,
                  ),
                  LiquidGlassAction(
                    id: 'second',
                    label: 'New conversation',
                    icon: Icons.edit,
                    onPressed: () => second++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(find.byType(LiquidGlassButton), findsNothing);
      expect(
        tester.getSize(find.byType(LiquidGlassButtonGroup)),
        const Size(152, 48),
      );
      await tester.tap(find.byKey(const ValueKey('first')));
      await tester.tap(find.byKey(const ValueKey('disabled')));
      await tester.tap(find.byKey(const ValueKey('second')));
      expect([first, second], [1, 1]);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group actions expose accessible activation and allow a single item',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassButtonGroup(
              actions: [
                LiquidGlassAction(
                  id: 'one',
                  label: 'Attach files',
                  icon: Icons.attach_file,
                  onPressed: () => presses++,
                ),
              ],
            ),
          ),
        ),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Attach files').first,
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pump();
      expect(presses, 1);
      semantics.dispose();
    },
  );

  testWidgets('navigation combines adjacent trailing actions in one capsule', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: LiquidGlassNavigationBar(
            title: 'Conversation',
            actions: [
              LiquidGlassAction(
                id: 'files',
                label: 'Files',
                icon: Icons.folder,
                onPressed: () {},
              ),
              LiquidGlassAction(
                id: 'options',
                label: 'Options',
                icon: Icons.more_horiz,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(LiquidGlassButtonGroup), findsOneWidget);
    expect(find.byType(LiquidGlassSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled group actions use the shared disabled opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassButtonGroup(
              actions: [
                LiquidGlassAction(
                  id: 'on',
                  label: 'On',
                  icon: Icons.add,
                  onPressed: () {},
                ),
                const LiquidGlassAction(
                  id: 'off',
                  label: 'Off',
                  icon: Icons.remove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    double opacityOf(String id) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacityOf('on'), 1);
    expect(opacityOf('off'), .48);
  });
}
