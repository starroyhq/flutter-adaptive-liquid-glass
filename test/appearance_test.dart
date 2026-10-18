import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_button_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_adaptive_liquid_glass/appearance');
  testWidgets(
    'selected app mode is sent in order and system clears the override',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      Future<void> show(ThemeMode mode, Brightness effective) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: effective),
            home: LiquidGlassAppearance(
              mode: mode,
              child: const Text('content'),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(ThemeMode.dark, Brightness.light);
      await show(ThemeMode.light, Brightness.dark);
      await show(ThemeMode.system, Brightness.dark);
      await show(ThemeMode.system, Brightness.light);
      expect(calls.map((v) => v.method), everyElement('setAppearance'));
      expect(calls.map((v) => v.arguments), ['dark', 'light', 'system']);
      expect(find.text('content'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'non-iOS does not mutate native appearance',
    (tester) async {
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        ++calls;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        const LiquidGlassAppearance(mode: ThemeMode.dark, child: SizedBox()),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  test(
    'native CJK text buttons reserve label, wide symbol and explicit insets',
    () {
      final plain = NativeButtonLayout.measure(
        label: '会话',
        hasIcon: false,
        usesSfSymbol: false,
        textScaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      );
      final withSymbol = NativeButtonLayout.measure(
        label: '会话',
        hasIcon: true,
        usesSfSymbol: true,
        textScaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      );
      // A symbol beside a title is as large as the title's 17-point font.
      expect(withSymbol.width, greaterThan(90));
      expect(withSymbol.width - plain.width, inInclusiveRange(29, 30));
      expect(withSymbol.labelStyle.fontSize, 17);
      expect(NativeButtonLayout.padding.horizontal, 32);
      final scaled = NativeButtonLayout.measure(
        label: '会话',
        hasIcon: true,
        usesSfSymbol: true,
        textScaler: TextScaler.linear(1.4),
        direction: TextDirection.ltr,
      );
      expect(scaled.width, greaterThan(withSymbol.width));
      expect(scaled.labelStyle.fontSize, closeTo(23.8, .01));
    },
  );

  test('native icon target remains a fixed 48 point circle', () {
    final icon = NativeButtonLayout.measure(
      label: null,
      hasIcon: true,
      usesSfSymbol: true,
      textScaler: TextScaler.noScaling,
      direction: TextDirection.ltr,
    );
    expect(icon.width, 48);
    expect(NativeButtonLayout.height, 48);
  });
}
