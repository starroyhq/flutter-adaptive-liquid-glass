import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

import 'native_modal_example.dart';
import 'component_catalog.dart';
import 'native_controls_probe.dart';
import 'native_layout_probe.dart';
import 'native_rtl_probe.dart';
import 'new_controls_example.dart';

void main() => runApp(
  const bool.fromEnvironment('GLASS_NATIVE_CONTROLS_PROBE')
      ? const NativeControlsProbeApp()
      : const bool.fromEnvironment('GLASS_NATIVE_LAYOUT_PROBE')
      ? const NativeLayoutProbeApp()
      : const bool.fromEnvironment('GLASS_NATIVE_RTL_PROBE')
      ? const NativeRtlProbeApp()
      : const bool.fromEnvironment('GLASS_NEW_CONTROLS')
      ? const NewControlsExample()
      : const bool.fromEnvironment('GLASS_MODAL_PROBE')
      ? const NativeModalExample()
      : const bool.fromEnvironment('GLASS_MATERIAL_PROBE')
      ? const GlassExample()
      : const ComponentCatalogApp(),
);

enum _Palette {
  neutral('Neutral', null),
  blue('Blue', Color(0xff2459b7)),
  green('Green', Color(0xff237957));

  const _Palette(this.label, this.seed);

  final String label;
  final Color? seed;
}

class GlassExample extends StatefulWidget {
  const GlassExample({super.key});
  @override
  State<GlassExample> createState() => _GlassExampleState();
}

class _GlassExampleState extends State<GlassExample> {
  final observer = LiquidGlassNavigatorObserver();
  LiquidGlassMode mode = LiquidGlassMode.auto;
  ThemeMode appearance = ThemeMode.system;
  _Palette palette = _Palette.neutral;
  bool reduceTransparency = false;
  bool reduceMotion = false;
  int index = 0;
  int filter = 0;

  @override
  void dispose() {
    observer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flutter Adaptive Liquid Glass',
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: appearance,
    navigatorObservers: [observer],
    builder: (context, child) => LiquidGlassAppearance(
      mode: appearance,
      child: LiquidGlassTheme(
        data: LiquidGlassThemeData(
          mode: mode,
          reduceTransparency: reduceTransparency,
          reduceMotion: reduceMotion,
          colors: palette == _Palette.neutral
              ? const LiquidGlassColors()
              : LiquidGlassColors.fromColorScheme(
                  Theme.of(context).colorScheme,
                ),
        ),
        child: child!,
      ),
    ),
    home: Builder(builder: _buildHome),
  );

  Widget _buildHome(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassNavigationBar(
        title: 'Liquid Glass',
        actions: [
          LiquidGlassAction(
            id: 'search',
            label: 'Search',
            icon: Icons.search,
            sfSymbol: 'magnifyingglass',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Search'),
                content: const TextField(
                  autofocus: true,
                  decoration: InputDecoration(hintText: 'Search this preview'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          LiquidGlassAction(
            id: 'options',
            label: 'Appearance and accessibility',
            icon: Icons.tune,
            sfSymbol: 'slider.horizontal.3',
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : LiquidGlassTabBar(
              items: const [
                LiquidGlassTabItem(
                  label: 'Computer',
                  icon: Icons.computer,
                  sfSymbol: 'desktopcomputer',
                ),
                LiquidGlassTabItem(
                  label: 'Sessions',
                  icon: Icons.chat_bubble_outline,
                  sfSymbol: 'bubble.left.and.bubble.right',
                  badge: '2',
                ),
                LiquidGlassTabItem(
                  label: 'Account',
                  icon: Icons.person_outline,
                  sfSymbol: 'person.crop.circle',
                ),
              ],
              selectedIndex: index,
              onSelected: (value) => setState(() => index = value),
            ),
      body: Builder(
        builder: (context) {
          // Scaffold supplies the measured bars through padding when the body
          // extends behind them, including large text and native tabs.
          final insets = MediaQuery.paddingOf(context);
          return Stack(
            children: [
              ListView(
                key: const PageStorageKey('material-background'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  insets.top + 80 + MediaQuery.textScalerOf(context).scale(14),
                  20,
                  insets.bottom + 180,
                ),
                children: [
                  Text(
                    'A quiet surface, in motion',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scroll the content beneath the toolbar, segmented control, '
                    'composer and tabs. Open the sliders to compare light, dark, '
                    'custom colors and accessibility settings.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Native available: $liquidGlassNativeAvailable · '
                    'Selected tab: ${['Computer', 'Sessions', 'Account'][index]}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      LiquidGlassButton(
                        label: '会话',
                        icon: Icons.add,
                        sfSymbol: 'plus',
                        prominent: true,
                        onPressed: () => _showOptions(context),
                      ),
                      const LiquidGlassButton(label: 'Disabled'),
                      const LiquidGlassButton(label: 'Loading', loading: true),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    [
                      'Recent sessions',
                      'Pinned sessions',
                      'All sessions',
                    ][filter],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 24; i++)
                    if (filter == 2 || (filter == 0 ? i < 12 : i % 4 == 0)) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          i % 4 == 0
                              ? Icons.push_pin_outlined
                              : Icons.folder_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        title: Text(
                          [
                            'Review workspace changes',
                            'Continue the conversation',
                            'Check the connected computer',
                          ][i % 3],
                        ),
                        subtitle: Text('Workspace ${i + 1} · Updated recently'),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 1, thickness: .5),
                      if (i % 5 == 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'final theme = LiquidGlassThemeData(\n'
                                '  mode: LiquidGlassMode.fallback,\n'
                                ');',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                ],
              ),
              Positioned(
                top: insets.top + 8,
                left: 20,
                right: 20,
                child: LiquidGlassSegmentedControl<int>(
                  segments: const [
                    LiquidGlassSegment(value: 0, label: 'Recent'),
                    LiquidGlassSegment(value: 1, label: 'Pinned'),
                    LiquidGlassSegment(value: 2, label: 'All'),
                  ],
                  selected: filter,
                  onChanged: (value) => setState(() => filter = value),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: insets.bottom + 12,
                child: LiquidGlassSurface(
                  radius: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: TextField(
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '中文 / 日本語 / emoji 👩🏽‍💻',
                      suffixIcon: IconButton(
                        tooltip: 'Dismiss keyboard',
                        icon: const Icon(Icons.keyboard_hide_outlined),
                        onPressed: () => FocusScope.of(context).unfocus(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showOptions(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        void update(VoidCallback change) {
          setState(change);
          setSheetState(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                LiquidGlassSegmentedControl(
                  segments: const [
                    LiquidGlassSegment(
                      value: ThemeMode.system,
                      label: 'System',
                    ),
                    LiquidGlassSegment(value: ThemeMode.light, label: 'Light'),
                    LiquidGlassSegment(value: ThemeMode.dark, label: 'Dark'),
                  ],
                  selected: appearance,
                  onChanged: (value) => update(() => appearance = value),
                ),
                const SizedBox(height: 16),
                Text(
                  'Color palette',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                LiquidGlassSegmentedControl(
                  segments: [
                    for (final value in _Palette.values)
                      LiquidGlassSegment(value: value, label: value.label),
                  ],
                  selected: palette,
                  onChanged: (value) => update(() => palette = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Blue and Green use ColorScheme.fromSeed. Any app palette '
                  'can be supplied through LiquidGlassColors.',
                ),
                const SizedBox(height: 16),
                LiquidGlassSegmentedControl(
                  segments: [
                    for (final value in LiquidGlassMode.values)
                      LiquidGlassSegment(value: value, label: value.name),
                  ],
                  selected: mode,
                  onChanged: (value) => update(() => mode = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                    'Keep the material; stop fallback motion.',
                  ),
                  value: reduceMotion,
                  onChanged: (value) => update(() => reduceMotion = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce transparency'),
                  subtitle: const Text(
                    'Use a solid material without background blur.',
                  ),
                  value: reduceTransparency,
                  onChanged: (value) =>
                      update(() => reduceTransparency = value),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bottom tabs stay native on iOS 26+. Use Android or older iOS '
                  'to inspect fallback tabs. Glass beneath this sheet must stay hidden.',
                ),
                const SizedBox(height: 24),
                LiquidGlassButton(
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final foreground = dark ? Colors.white : Colors.black;
    final background = dark ? Colors.black : Colors.white;
    final neutralColors =
        (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
          primary: foreground,
          onPrimary: background,
          primaryContainer: dark
              ? const Color(0xff303030)
              : const Color(0xffeeeeee),
          onPrimaryContainer: foreground,
          secondary: foreground,
          onSecondary: background,
          secondaryContainer: dark
              ? const Color(0xff262626)
              : const Color(0xfff0f0f0),
          onSecondaryContainer: foreground,
          tertiary: foreground,
          onTertiary: background,
          tertiaryContainer: dark
              ? const Color(0xff303030)
              : const Color(0xffeeeeee),
          onTertiaryContainer: foreground,
          surface: background,
          onSurface: foreground,
          onSurfaceVariant: dark
              ? const Color(0xffa3a3a3)
              : const Color(0xff686868),
          surfaceContainer: dark
              ? const Color(0xff1b1b1b)
              : const Color(0xfff5f5f5),
          surfaceContainerHigh: dark
              ? const Color(0xff242424)
              : const Color(0xffeeeeee),
          surfaceContainerHighest: dark
              ? const Color(0xff303030)
              : const Color(0xffe5e5e5),
          outline: dark ? const Color(0xff5c5c5c) : const Color(0xffa0a0a0),
          outlineVariant: dark
              ? const Color(0xff2b2b2b)
              : const Color(0xffe7e7e7),
        );
    final colors = palette.seed == null
        ? neutralColors
        : ColorScheme.fromSeed(
            seedColor: palette.seed!,
            brightness: brightness,
          );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: colors.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
