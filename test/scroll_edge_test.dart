import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(
    ScrollController controller, {
    LiquidGlassMode mode = LiquidGlassMode.fallback,
    double top = 60,
    double bottom = 80,
    int rows = 60,
    VoidCallback? onTap,
  }) => MaterialApp(
    home: LiquidGlassTheme(
      data: LiquidGlassThemeData(mode: mode),
      child: Scaffold(
        body: LiquidGlassScrollEdgeEffect(
          top: top,
          bottom: bottom,
          child: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < rows; i++)
                ListTile(title: Text('Row $i'), onTap: i == 0 ? onTap : null),
            ],
          ),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester, int index) => tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .elementAt(index)
      .opacity;

  testWidgets('each edge appears only while content is beneath it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    // At rest at the top: nothing is under the top edge, the rest is below.
    expect(opacity(tester, 0), 0);
    expect(opacity(tester, 1), 1);
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(opacity(tester, 0), 1);
    expect(opacity(tester, 1), 1);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(opacity(tester, 0), 1);
    expect(opacity(tester, 1), 0);
  });

  testWidgets('short content that cannot scroll shows no effect', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, rows: 2));
    await tester.pumpAndSettle();
    expect(opacity(tester, 0), 0);
    expect(opacity(tester, 1), 0);
  });

  testWidgets('soft edges blur; the opaque mode uses hard edges', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsWidgets);
    await tester.pumpWidget(host(controller, mode: LiquidGlassMode.opaque));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('touches reach the content beneath an edge', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var taps = 0;
    await tester.pumpWidget(host(controller, top: 200, onTap: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Row 0'));
    expect(taps, 1);
  });

  testWidgets('an edge with no extent draws nothing', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, top: 0, bottom: 0));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedOpacity), findsNothing);
  });
}
