import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/feedback.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_pressable.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate' ||
            call.method == 'SystemSound.play') {
          calls.add('${call.method}:${call.arguments}');
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test('feedback value data participates in theme equality and copying', () {
    const defaults = LiquidGlassThemeData();
    final muted = defaults.copyWith(
      feedback: defaults.feedback.copyWith(sound: false),
    );
    expect(muted.feedback.haptics, isTrue);
    expect(muted.feedback.sound, isFalse);
    expect(muted, isNot(defaults));
    expect(muted.copyWith(), muted);
    expect(muted.copyWith().hashCode, muted.hashCode);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform sends one platform feedback per gesture', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      var taps = 0, holds = 0;
      await tester.pumpWidget(
        _host(
          FallbackPressable(
            onTap: () => taps++,
            onLongPress: () => holds++,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              width: 150,
              height: 48,
              child: Text('Target'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Target'));
      await tester.pump();
      expect(taps, 1);
      expect(
        calls,
        platform == TargetPlatform.android
            ? ['SystemSound.play:SystemSoundType.click']
            : isEmpty,
      );
      calls.clear();
      await tester.longPress(find.text('Target'));
      await tester.pump();
      expect(taps, 1);
      expect(holds, 1);
      expect(
        calls,
        platform == TargetPlatform.iOS
            ? [
                'HapticFeedback.vibrate:HapticFeedbackType.heavyImpact',
                'SystemSound.play:SystemSoundType.click',
              ]
            : ['HapticFeedback.vibrate:null'],
      );
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'haptic and sound flags independently apply after a theme change',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      for (final policy in [
        const LiquidGlassFeedbackData(haptics: false),
        const LiquidGlassFeedbackData(sound: false),
        const LiquidGlassFeedbackData(haptics: false, sound: false),
      ]) {
        calls.clear();
        await tester.pumpWidget(
          _host(
            FallbackPressable(
              onTap: () {},
              onLongPress: () {},
              borderRadius: BorderRadius.circular(24),
              child: const SizedBox(
                width: 100,
                height: 48,
                child: Text('Target'),
              ),
            ),
            feedback: policy,
          ),
        );
        await tester.longPress(find.text('Target'));
        await tester.pump();
        expect(calls, [
          if (policy.haptics)
            'HapticFeedback.vibrate:HapticFeedbackType.heavyImpact',
          if (policy.sound) 'SystemSound.play:SystemSoundType.click',
        ]);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'pointer leaving target before recognition cancels action and feedback',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(
        _host(
          FallbackPressable(
            onTap: () => actions++,
            onLongPress: () => actions++,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              width: 100,
              height: 48,
              child: Text('Target'),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(FallbackPressable));
      final gesture = await tester.startGesture(
        Offset(rect.right - 2, rect.center.dy),
      );
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();
      expect(actions, 0);
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'programmatic rebuilds and disabled presses do not emit feedback',
    (tester) async {
      for (final mode in [LiquidGlassMode.fallback, LiquidGlassMode.opaque]) {
        await tester.pumpWidget(
          _host(
            const FallbackPressable(
              onTap: null,
              borderRadius: BorderRadius.all(Radius.circular(24)),
              child: SizedBox(width: 100, height: 48, child: Text('Disabled')),
            ),
            mode: mode,
          ),
        );
        await tester.tap(find.text('Disabled'));
        await tester.longPress(find.text('Disabled'));
      }
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'nested route coverage rejects stale dispatch until exit completes',
    (tester) async {
      final observer = LiquidGlassNavigatorObserver.debug(
        nativeAvailable: true,
      );
      addTearDown(observer.dispose);
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext innerContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) {
                innerContext = context;
                return const Scaffold(body: Text('Inner'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(LiquidGlassFeedback.canInteract(innerContext), isTrue);
      final dialog = showDialog<void>(
        context: innerContext,
        useRootNavigator: true,
        builder: (_) => const AlertDialog(content: Text('Cover')),
      );
      await tester.pumpAndSettle();
      expect(LiquidGlassFeedback.canInteract(innerContext), isFalse);
      LiquidGlassFeedback.longPress(innerContext);
      expect(calls, isEmpty);
      navigator.currentState!.pop();
      await tester.pump();
      expect(LiquidGlassFeedback.canInteract(innerContext), isFalse);
      await tester.pumpAndSettle();
      await dialog;
      expect(LiquidGlassFeedback.canInteract(innerContext), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Widget _host(
  Widget child, {
  LiquidGlassFeedbackData feedback = const LiquidGlassFeedbackData(),
  LiquidGlassMode mode = LiquidGlassMode.fallback,
}) => MaterialApp(
  home: LiquidGlassTheme(
    data: LiquidGlassThemeData(mode: mode, feedback: feedback),
    child: Scaffold(
      body: Center(child: Material(child: child)),
    ),
  ),
);
