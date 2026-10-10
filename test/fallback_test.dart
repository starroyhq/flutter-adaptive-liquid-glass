import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_pressable.dart';

void main() {
  testWidgets(
    'light and dark materials use one fill without painted highlights',
    (tester) async {
      for (final dark in [false, true]) {
        for (final style in LiquidGlassSurfaceStyle.values) {
          await tester.pumpWidget(
            _host(
              LiquidGlassSurface(
                key: const ValueKey('surface'),
                style: style,
                child: const SizedBox(width: 160, height: 48),
              ),
              dark: dark,
            ),
          );
          final boxes = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byKey(const ValueKey('surface')),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((box) => box.decoration as BoxDecoration)
              .toList();
          expect(boxes.every((box) => box.gradient == null), isTrue);
          final fill = boxes.singleWhere((box) => box.color != null);
          expect(fill.color!.a, inInclusiveRange(.8, .95));
          expect((fill.border! as Border).top.width, .5);
          expect((fill.border! as Border).top.color.a, lessThan(.15));
          final shadow = boxes
              .singleWhere((box) => box.boxShadow != null)
              .boxShadow!
              .single;
          expect(shadow.blurRadius, lessThanOrEqualTo(12));
          expect(shadow.spreadRadius, isNegative);
          expect(find.byType(BackdropFilter), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'reduced transparency keeps solid material without shadow or blur',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const LiquidGlassSurface(child: Text('Readable')),
          reducedTransparency: true,
        ),
      );
      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(LiquidGlassSurface),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration as BoxDecoration);
      expect(boxes.single.color!.a, 1);
      expect(boxes.single.boxShadow, isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets(
    'fallback segments are a solid track with reachable selected thumb',
    (tester) async {
      final selections = <int>[];
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: LiquidGlassSegmentedControl(
              segments: const [
                LiquidGlassSegment(value: 0, label: 'System'),
                LiquidGlassSegment(value: 1, label: 'Light'),
                LiquidGlassSegment(value: 2, label: 'Dark'),
              ],
              selected: 0,
              onChanged: selections.add,
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(LiquidGlassSurface), findsNothing);
      for (final pressable in find.byType(FallbackPressable).evaluate()) {
        expect(tester.getSize(find.byWidget(pressable.widget)).height, 48);
      }
      await tester.tap(find.text('Dark'));
      expect(selections, [2]);
    },
  );

  testWidgets(
    'tab density stays compact and selection has no brand-colored fill',
    (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          _host(_tabs(const ['Hosts', 'Chats', 'Me']), dark: dark),
        );
        expect(tester.getSize(find.byType(LiquidGlassSurface)).height, 60);
        final selected = tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(LiquidGlassTabBar),
                matching: find.byType(Material),
              ),
            )
            .singleWhere((material) => material.color != Colors.transparent);
        expect(
          selected.color,
          (dark ? Colors.white : Colors.black).withValues(
            alpha: dark ? .10 : .06,
          ),
        );
        expect(tester.widget<Icon>(find.byIcon(Icons.computer)).size, 20);
      }
    },
  );

  testWidgets(
    'four language tabs grow for large text and preserve 48 point taps',
    (tester) async {
      final selections = <int>[];
      for (final labels in [
        ['电脑', '会话', '账号'],
        ['電腦', '對話', '帳號'],
        ['Computers', 'Conversations', 'Account'],
        ['コンピューター', '会話', 'アカウント'],
      ]) {
        await tester.pumpWidget(
          _host(_tabs(labels, onSelected: selections.add), textScale: 1.8),
        );
        expect(tester.takeException(), isNull);
        for (final label in labels) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, isNull);
          expect(text.overflow, isNull);
          final target = find.ancestor(
            of: find.text(label),
            matching: find.byType(FallbackPressable),
          );
          final size = tester.getSize(target);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        await tester.tap(find.text(labels[1]));
        expect(selections.last, 1);
      }
    },
  );

  testWidgets('press feedback survives NoSplash and respects reduced motion', (
    tester,
  ) async {
    var taps = 0;
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        _host(
          LiquidGlassButtonGroup(
            actions: [
              LiquidGlassAction(
                id: 'search',
                label: 'Search',
                icon: Icons.search,
                onPressed: () => taps++,
              ),
            ],
          ),
          reducedMotion: reduced,
        ),
      );
      final target = find.byKey(const ValueKey('search'));
      final restingSize = tester.getSize(target);
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 120));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, reduced ? 1 : .97);
      expect(
        scale.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 120),
      );
      expect(tester.getSize(target), restingSize);
      expect(restingSize, const Size(48, 48));
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(
        ink.overlayColor!.resolve({WidgetState.pressed})!.a,
        greaterThan(0),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    }
    expect(taps, 2);
  });
}

Widget _tabs(List<String> labels, {ValueChanged<int>? onSelected}) => SizedBox(
  width: 320,
  child: LiquidGlassTabBar(
    items: [
      LiquidGlassTabItem(label: labels[0], icon: Icons.computer),
      LiquidGlassTabItem(label: labels[1], icon: Icons.chat),
      LiquidGlassTabItem(label: labels[2], icon: Icons.person),
    ],
    selectedIndex: 0,
    onSelected: onSelected ?? (_) {},
  ),
);

Widget _host(
  Widget child, {
  bool dark = false,
  double textScale = 1,
  bool reducedTransparency = false,
  bool reducedMotion = false,
}) {
  final colors = (dark ? const ColorScheme.dark() : const ColorScheme.light())
      .copyWith(
        primary: Colors.blue,
        surface: dark ? Colors.black : Colors.white,
        onSurface: dark ? Colors.white : Colors.black,
      );
  return MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: ThemeData(
      colorScheme: colors,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: LiquidGlassTheme(
        data: LiquidGlassThemeData(
          mode: LiquidGlassMode.fallback,
          reduceMotion: reducedMotion,
          reduceTransparency: reducedTransparency,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}
