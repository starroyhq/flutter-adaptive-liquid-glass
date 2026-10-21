import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// A fixed page with the package's system tab bar, segmented controls and
/// standalone icon buttons, for screenshot comparison and UI tests. Below
/// them, toggles change two buttons' enabled state in place, and a segmented
/// control refuses one of its choices.
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
  int _iconPresses = 0, _segment = 0, _tab = 2, _finds = 0, _sends = 0;
  bool _deleteEnabled = false, _moveUpEnabled = true;
  String _access = 'public';

  /// Counted without a rebuild, so the refused segment is not reset by one.
  final _lockedAttempts = ValueNotifier<int>(0);

  void _press() => setState(() => _iconPresses++);

  @override
  void dispose() {
    _lockedAttempts.dispose();
    super.dispose();
  }

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
              onPressed: _moveUpEnabled ? _press : null,
            ),
            // Disabled until Toggle Delete enables it.
            LiquidGlassButton.icon(
              id: 'probe-disabled',
              icon: Icons.delete_outline,
              sfSymbol: 'trash',
              semanticLabel: 'Delete',
              onPressed: _deleteEnabled ? _press : null,
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
        // Below the compared controls: buttons whose enabled state changes in
        // place, and a choice the page refuses.
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LiquidGlassButton(
              id: 'probe-send',
              label: 'Send',
              prominent: true,
              onPressed: _moveUpEnabled ? () => setState(() => _sends++) : null,
            ),
            TextButton(
              onPressed: () => setState(() => _deleteEnabled = !_deleteEnabled),
              child: const Text('Toggle Delete'),
            ),
            // Move up and Send share this state.
            TextButton(
              onPressed: () => setState(() => _moveUpEnabled = !_moveUpEnabled),
              child: const Text('Toggle Move up'),
            ),
          ],
        ),
        Text('Delete enabled: $_deleteEnabled'),
        Text('Move up enabled: $_moveUpEnabled'),
        Text('Send presses: $_sends'),
        const SizedBox(height: 16),
        LiquidGlassSegmentedControl<String>(
          segments: const [
            LiquidGlassSegment(value: 'public', label: 'Public'),
            LiquidGlassSegment(value: 'locked', label: 'Locked'),
          ],
          selected: _access,
          // Locked is refused without a rebuild: only the control itself can
          // return to Public.
          onChanged: (value) {
            if (value == 'locked') {
              _lockedAttempts.value++;
            } else {
              setState(() => _access = value);
            }
          },
        ),
        Text('Access: $_access'),
        ValueListenableBuilder<int>(
          valueListenable: _lockedAttempts,
          builder: (context, attempts, _) => Text('Locked attempts: $attempts'),
        ),
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
