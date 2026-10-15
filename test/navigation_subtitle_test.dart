import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({String? subtitle, double scale = 1, double width = 390}) =>
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 700),
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp(
          home: LiquidGlassTheme(
            data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
            child: Scaffold(
              appBar: LiquidGlassNavigationBar(
                title: 'Files and changes',
                subtitle: subtitle,
                leading: [
                  LiquidGlassAction(
                    id: 'back',
                    label: 'Back',
                    icon: Icons.arrow_back,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('the fallback shows the subtitle under the title', (
    tester,
  ) async {
    await tester.pumpWidget(host(subtitle: 'Synthetic workspace'));
    final title = tester.getRect(find.text('Files and changes'));
    final subtitle = tester.getRect(find.text('Synthetic workspace'));
    expect(subtitle.top, greaterThanOrEqualTo(title.bottom - 1));
    expect(
      tester
          .widget<LiquidGlassNavigationBar>(
            find.byType(LiquidGlassNavigationBar),
          )
          .preferredSize
          .height,
      64,
    );
  });

  testWidgets('large text on a narrow screen still fits the bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(subtitle: 'Synthetic workspace', scale: 2, width: 320),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a subtitle the title is unchanged', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byType(FittedBox), findsNothing);
    expect(find.text('Files and changes'), findsOneWidget);
  });
}
