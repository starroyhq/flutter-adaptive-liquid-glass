import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// A fixed page with the package's system tab bar, segmented controls and
/// standalone icon buttons, for screenshot comparison and UI tests.
///
/// It has no animated content, and its title bar is a Flutter [AppBar], so
/// only these native controls differ between two renderings of the page.
class NativeControlsProbeApp extends StatefulWidget {
  const NativeControlsProbeApp({super.key});

  @override
  State<NativeControlsProbeApp> createState() => _NativeControlsProbeAppState();
}

class _NativeControlsProbeAppState extends State<NativeControlsProbeApp> {
  final _observer = LiquidGlassNavigatorObserver();

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Native controls probe',
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    navigatorObservers: [_observer],
    builder: (context, child) =>
        LiquidGlassAppearance(mode: ThemeMode.system, child: child!),
    home: const NativeControlsProbePage(),
  );
}

/// The probe page itself; the catalog's Search page also pushes it.
class NativeControlsProbePage extends StatefulWidget {
  const NativeControlsProbePage({super.key});

  @override
  State<NativeControlsProbePage> createState() =>
      _NativeControlsProbePageState();
}

class _NativeControlsProbePageState extends State<NativeControlsProbePage> {
  int _iconPresses = 0, _segment = 0, _tab = 2, _finds = 0;

  void _press() => setState(() => _iconPresses++);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Native controls probe')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LiquidGlassButton.icon(
              id: 'probe-add',
              icon: Icons.add,
              sfSymbol: 'plus',
              semanticLabel: 'Add item',
              onPressed: _press,
            ),
            // No SF Symbol: the native button draws the Material glyph.
            LiquidGlassButton.icon(
              id: 'probe-close',
              icon: Icons.close,
              semanticLabel: 'Close',
              onPressed: _press,
            ),
            LiquidGlassButton.icon(
              id: 'probe-up',
              icon: Icons.arrow_upward,
              sfSymbol: 'arrow.up',
              semanticLabel: 'Move up',
              prominent: true,
              onPressed: _press,
            ),
            const LiquidGlassButton.icon(
              id: 'probe-disabled',
              icon: Icons.delete_outline,
              sfSymbol: 'trash',
              semanticLabel: 'Delete',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Icon presses: $_iconPresses'),
        const SizedBox(height: 24),
        LiquidGlassSegmentedControl<int>(
          segments: const [
            LiquidGlassSegment(value: 0, label: 'One'),
            LiquidGlassSegment(value: 1, label: 'Two'),
            LiquidGlassSegment(value: 2, label: 'Three'),
          ],
          selected: _segment,
          onChanged: (value) => setState(() => _segment = value),
        ),
        const SizedBox(height: 12),
        Text('Segment: $_segment'),
        const SizedBox(height: 24),
        LiquidGlassSegmentedControl<bool>(
          segments: const [
            LiquidGlassSegment(value: false, label: 'Off'),
            LiquidGlassSegment(value: true, label: 'On'),
          ],
          selected: true,
          onChanged: null,
        ),
        const SizedBox(height: 24),
        Text('Tab: $_tab'),
        Text('Find presses: $_finds'),
      ],
    ),
    bottomNavigationBar: LiquidGlassTabBar(
      items: const [
        LiquidGlassTabItem(label: 'Alpha', icon: Icons.home, sfSymbol: 'house'),
        LiquidGlassTabItem(
          label: 'Beta',
          icon: Icons.star_border,
          sfSymbol: 'star',
          badge: '',
        ),
        // No SF Symbol: both states are drawn from Material glyphs.
        LiquidGlassTabItem(
          label: 'Gamma',
          icon: Icons.settings,
          selectedIcon: Icons.settings_suggest,
        ),
      ],
      selectedIndex: _tab,
      onSelected: (value) => setState(() => _tab = value),
      trailingAction: LiquidGlassAction(
        id: 'probe-find',
        label: 'Find',
        onPressed: () => setState(() => _finds++),
      ),
    ),
  );
}
