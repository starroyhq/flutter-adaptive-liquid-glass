import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_selection_track.dart';

void main() {
  test('palette and theme copyWith preserve independent settings', () {
    const original = LiquidGlassThemeData(
      mode: LiquidGlassMode.fallback,
      reduceMotion: true,
      blurSigma: 12,
      colors: _lightBrand,
    );
    final recolored = original.copyWith(
      colors: original.colors.copyWith(accent: Colors.orange),
    );
    expect(recolored.mode, original.mode);
    expect(recolored.reduceMotion, isTrue);
    expect(recolored.blurSigma, 12);
    expect(recolored.colors.accent, Colors.orange);
    expect(recolored.colors.foreground, original.colors.foreground);
    expect(recolored.colors.selection, original.colors.selection);
    expect(original.colors.accent, _lightBrand.accent);
    expect(original.copyWith(), original);
    expect(original.copyWith().hashCode, original.hashCode);
    expect(_lightBrand.copyWith(), _lightBrand);
    expect(recolored, isNot(original));
  });

  test('ColorScheme opt-in maps foreground and action roles', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.deepOrange);
    final colors = LiquidGlassColors.fromColorScheme(scheme);
    expect(colors.foreground, scheme.onSurface);
    expect(colors.accent, scheme.primary);
    expect(colors.onAccent, scheme.onPrimary);
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness brand palette reaches every fallback control', (
      tester,
    ) async {
      final brand = brightness == Brightness.dark ? _darkBrand : _lightBrand;
      await tester.pumpWidget(
        _host(
          brightness: brightness,
          colors: brand,
          child: const _StatefulControls(),
        ),
      );
      await tester.pumpAndSettle();
      expect(_textColor(tester, 'Ordinary'), brand.foreground);
      expect(_iconColor(tester, Icons.search), brand.foreground);
      expect(_textColor(tester, 'Grouped action'), brand.foreground);
      expect(_iconColor(tester, Icons.add), brand.foreground);
      expect(_textColor(tester, 'Primary'), brand.onAccent);
      expect(_materialColor(tester, 'Primary'), brand.accent);
      expect(_textColor(tester, 'Work'), brand.selectedForeground);
      expect(_textColor(tester, 'Settings'), brand.foreground);
      expect(_iconColor(tester, Icons.work), brand.selectedForeground);
      expect(_iconColor(tester, Icons.settings), brand.foreground);
      expect(_textColor(tester, 'Recent'), brand.selectedForeground);
      expect(_textColor(tester, 'All'), brand.foreground);

      final thumbs = find.descendant(
        of: find.byType(FallbackSelectionTrack),
        matching: find.byType(DecoratedBox),
      );
      expect(thumbs, findsNWidgets(2));
      for (final widget in tester.widgetList<DecoratedBox>(thumbs)) {
        expect((widget.decoration as BoxDecoration).color, brand.selection);
      }

      final shadows = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .expand((decoration) => decoration.boxShadow ?? <BoxShadow>[]);
      expect(shadows, isNotEmpty);
      expect(shadows.every((shadow) => shadow.color == brand.shadow), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a foreground-only override keeps unconfigured action colors', (
    tester,
  ) async {
    const foreground = Color(0xff5b246b);
    await tester.pumpWidget(
      _host(
        colors: const LiquidGlassColors(foreground: foreground),
        child: const _StatefulControls(),
      ),
    );
    final scheme = Theme.of(tester.element(find.text('Primary'))).colorScheme;
    for (final label in [
      'Ordinary',
      'Grouped action',
      'Work',
      'Settings',
      'Recent',
      'All',
    ]) {
      expect(_textColor(tester, label), foreground);
    }
    expect(_materialColor(tester, 'Primary'), scheme.primary);
    expect(_textColor(tester, 'Primary'), scheme.onPrimary);
  });

  testWidgets(
    'changing a palette preserves selection and an unfinished draft',
    (tester) async {
      final palette = ValueNotifier<LiquidGlassColors>(
        const LiquidGlassColors(),
      );
      addTearDown(palette.dispose);
      final controls = GlobalKey<_StatefulControlsState>();
      await tester.pumpWidget(
        ValueListenableBuilder<LiquidGlassColors>(
          valueListenable: palette,
          builder: (context, colors, child) => _host(
            colors: colors,
            child: _StatefulControls(key: controls),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.tap(find.text('All'));
      await tester.enterText(find.byType(TextField), '未发送 👩🏽‍💻 draft');
      await tester.pumpAndSettle();
      final originalState = controls.currentState!;
      final originalEditorState = tester.state(find.byType(TextField));
      final originalDraft = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      expect(originalState.selectionCallbacks, 2);

      for (final colors in [
        _lightBrand,
        _darkBrand,
        const LiquidGlassColors(),
      ]) {
        palette.value = colors;
        await tester.pumpAndSettle();
        expect(controls.currentState, same(originalState));
        expect(originalState.tab, 1);
        expect(originalState.segment, 1);
        expect(tester.state(find.byType(TextField)), same(originalEditorState));
        final draft = tester
            .widget<EditableText>(find.byType(EditableText))
            .controller;
        expect(draft, same(originalDraft));
        expect(draft.text, '未发送 👩🏽‍💻 draft');
        expect(originalState.selectionCallbacks, 2);
        final scheme = Theme.of(
          tester.element(find.text('Settings')),
        ).colorScheme;
        expect(
          _textColor(tester, 'Settings'),
          colors.selectedForeground ?? colors.foreground ?? scheme.onSurface,
        );
        expect(
          _textColor(tester, 'Ordinary'),
          colors.foreground ?? scheme.onSurface,
        );
        expect(
          _materialColor(tester, 'Primary'),
          colors.accent ?? scheme.primary,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('a local color override leaves sibling controls unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        colors: _lightBrand,
        child: Builder(
          builder: (context) {
            final inherited = LiquidGlassTheme.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlassTheme(
                  data: inherited.copyWith(
                    colors: inherited.colors.copyWith(
                      foreground: Colors.purple,
                    ),
                  ),
                  child: LiquidGlassButton(label: 'Local', onPressed: () {}),
                ),
                LiquidGlassButton(label: 'Sibling', onPressed: () {}),
                LiquidGlassButton(
                  label: 'Sibling primary',
                  prominent: true,
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
    expect(_textColor(tester, 'Local'), Colors.purple);
    expect(_textColor(tester, 'Sibling'), _lightBrand.foreground);
    expect(_materialColor(tester, 'Sibling primary'), _lightBrand.accent);
  });

  testWidgets('surface widget tint takes priority over inherited tint', (
    tester,
  ) async {
    const localTint = Color(0x332080c0);
    const inheritedKey = ValueKey('inherited-surface');
    const localKey = ValueKey('local-surface');
    await tester.pumpWidget(
      _host(
        colors: _lightBrand,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlassSurface(
              key: inheritedKey,
              child: SizedBox(width: 160, height: 48),
            ),
            LiquidGlassSurface(
              key: localKey,
              tint: localTint,
              child: SizedBox(width: 160, height: 48),
            ),
          ],
        ),
      ),
    );
    Color fill(Key key) => tester
        .widget<ColoredBox>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(ColoredBox),
          ),
        )
        .color;
    expect(
      fill(inheritedKey).withValues(alpha: 1),
      _lightBrand.surfaceTint!.withValues(alpha: 1),
    );
    expect(fill(localKey).withValues(alpha: 1), localTint.withValues(alpha: 1));
    // The source tint does not accidentally disable the material's protection.
    expect(fill(localKey).a, greaterThan(localTint.a));
    expect(fill(localKey).a, fill(inheritedKey).a);
  });
}

const _lightBrand = LiquidGlassColors(
  surfaceTint: Color(0xffe9f2ff),
  foreground: Color(0xff16345c),
  accent: Color(0xff005ac1),
  onAccent: Color(0xffffffff),
  selection: Color(0x335285c6),
  selectedForeground: Color(0xff002958),
  border: Color(0x6650739e),
  highlight: Color(0xaaddf2ff),
  shadow: Color(0x33102c50),
);

const _darkBrand = LiquidGlassColors(
  surfaceTint: Color(0xff172d37),
  foreground: Color(0xffcce9ee),
  accent: Color(0xff76d6e9),
  onAccent: Color(0xff00313a),
  selection: Color(0x4476d6e9),
  selectedForeground: Color(0xffefffff),
  border: Color(0x6695c5d0),
  highlight: Color(0x88d0f7ff),
  shadow: Color(0x55000912),
);

Widget _host({
  required LiquidGlassColors colors,
  required Widget child,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: ThemeData(brightness: brightness),
  home: LiquidGlassTheme(
    data: LiquidGlassThemeData(mode: LiquidGlassMode.fallback, colors: colors),
    child: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

Color? _textColor(WidgetTester tester, String text) {
  final finder = find.text(text);
  final widget = tester.widget<Text>(finder);
  return widget.style?.color ??
      DefaultTextStyle.of(tester.element(finder)).style.color;
}

Color? _iconColor(WidgetTester tester, IconData icon) {
  final finder = find.byIcon(icon);
  return tester.widget<Icon>(finder).color ??
      IconTheme.of(tester.element(finder)).color;
}

Color? _materialColor(WidgetTester tester, String label) => tester
    .widget<Material>(
      find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(LiquidGlassButton),
        ),
        matching: find.byType(Material),
      ),
    )
    .color;

class _StatefulControls extends StatefulWidget {
  const _StatefulControls({super.key});

  @override
  State<_StatefulControls> createState() => _StatefulControlsState();
}

class _StatefulControlsState extends State<_StatefulControls> {
  int tab = 0;
  int segment = 0;
  int selectionCallbacks = 0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      LiquidGlassButton(
        label: 'Ordinary',
        icon: Icons.search,
        onPressed: () {},
      ),
      LiquidGlassButton(label: 'Primary', prominent: true, onPressed: () {}),
      LiquidGlassButtonGroup(
        actions: [
          LiquidGlassAction(
            id: 'label',
            label: 'Grouped action',
            onPressed: () {},
          ),
          LiquidGlassAction(
            id: 'icon',
            label: 'Add',
            icon: Icons.add,
            onPressed: () {},
          ),
        ],
      ),
      LiquidGlassTabBar(
        items: const [
          LiquidGlassTabItem(label: 'Work', icon: Icons.work),
          LiquidGlassTabItem(label: 'Settings', icon: Icons.settings),
        ],
        selectedIndex: tab,
        onSelected: (value) => setState(() {
          tab = value;
          selectionCallbacks++;
        }),
      ),
      LiquidGlassSegmentedControl<int>(
        segments: const [
          LiquidGlassSegment(value: 0, label: 'Recent'),
          LiquidGlassSegment(value: 1, label: 'All'),
        ],
        selected: segment,
        onChanged: (value) => setState(() {
          segment = value;
          selectionCallbacks++;
        }),
      ),
      // Let TextField own its controller: changing surface styling must not
      // recreate the editor and silently discard an unfinished draft.
      const LiquidGlassSurface(child: TextField()),
    ],
  );
}
