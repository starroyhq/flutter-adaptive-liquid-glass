import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass_example/native_controls_probe.dart';
import 'package:flutter_adaptive_liquid_glass_example/native_layout_probe.dart';
import 'package:flutter_adaptive_liquid_glass_example/native_rtl_probe.dart';

// A test host renders the probes' Flutter fallback. These checks catch fixture
// logic and layout errors before the native UI tests rely on the pages.
Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the controls probe toggles its buttons and refuses Locked', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NativeControlsProbeApp());
    await tester.pumpAndSettle();
    expect(find.text('Delete enabled: false'), findsOneWidget);
    expect(find.text('Move up enabled: true'), findsOneWidget);
    await tapText(tester, 'Toggle Delete');
    expect(find.text('Delete enabled: true'), findsOneWidget);
    await tapText(tester, 'Toggle Move up');
    expect(find.text('Move up enabled: false'), findsOneWidget);
    await tapText(tester, 'Send');
    expect(find.text('Send presses: 0'), findsOneWidget);
    await tapText(tester, 'Toggle Move up');
    await tapText(tester, 'Send');
    expect(find.text('Send presses: 1'), findsOneWidget);
    await tapText(tester, 'Locked');
    expect(find.text('Access: public'), findsOneWidget);
    expect(find.text('Locked attempts: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the layout probe opens and closes each popup', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NativeLayoutProbeApp());
    await tester.pumpAndSettle();
    expect(find.text('Popup result: none'), findsOneWidget);
    await tapText(tester, 'Menu');
    await tapText(tester, 'First choice');
    expect(find.text('Popup result: menu first'), findsOneWidget);
    await tapText(tester, 'Alert');
    await tapText(tester, 'OK');
    expect(find.text('Popup result: alert ok'), findsOneWidget);
    await tapText(tester, 'Sheet');
    await tapText(tester, 'Sheet action');
    expect(find.text('Sheet presses: 1'), findsOneWidget);
    await tapText(tester, 'Close');
    expect(find.text('Popup result: sheet closed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('the RTL probe toggles Paste and starts on the first tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NativeRtlProbeApp());
    await tester.pumpAndSettle();
    expect(find.text('Tab: 0'), findsOneWidget);
    // The first segment is at the right.
    expect(
      tester.getCenter(find.text('Day')).dx,
      greaterThan(tester.getCenter(find.text('Month')).dx),
    );
    await tapText(tester, 'Paste');
    expect(find.text('Paste presses: 1'), findsOneWidget);
    await tapText(tester, 'Toggle Paste');
    expect(find.text('Paste enabled: false'), findsOneWidget);
    await tapText(tester, 'Paste');
    expect(find.text('Paste presses: 1'), findsOneWidget);
    await tapText(tester, 'Copy');
    expect(find.text('Last action: copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
