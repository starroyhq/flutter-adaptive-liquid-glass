import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// A fixed right-to-left page for screenshot comparison and UI tests of native
/// controls that follow Flutter's text direction rather than the device
/// language: SF Symbols with a direction, a segmented control, a button group
/// with an action whose enabled state changes in place, and the system tab
/// bar with a trailing action.
class NativeRtlProbeApp extends StatefulWidget {
  const NativeRtlProbeApp({super.key});

  @override
  State<NativeRtlProbeApp> createState() => _NativeRtlProbeAppState();
}

class _NativeRtlProbeAppState extends State<NativeRtlProbeApp> {
  final _observer = LiquidGlassNavigatorObserver();

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Native RTL probe',
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    navigatorObservers: [_observer],
    builder: (context, child) =>
        LiquidGlassAppearance(mode: ThemeMode.system, child: child!),
    home: const NativeRtlProbePage(),
  );
}

/// The probe page itself; the catalog's Search page also pushes it.
class NativeRtlProbePage extends StatefulWidget {
  const NativeRtlProbePage({super.key});

  @override
  State<NativeRtlProbePage> createState() => _NativeRtlProbePageState();
}

class _NativeRtlProbePageState extends State<NativeRtlProbePage> {
  int _segment = 0, _tab = 0, _finds = 0, _pastes = 0;
  bool _pasteEnabled = true;
  String _lastAction = 'none';

  VoidCallback _record(String action) =>
      () => setState(() => _lastAction = action);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('Native RTL probe')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Semantic symbols turn with the direction; arrow.left and star
          // do not.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              LiquidGlassButton.icon(
                id: 'rtl-symbol-backward',
                icon: Icons.arrow_back,
                sfSymbol: 'arrow.backward',
                semanticLabel: 'Backward symbol',
                onPressed: _record('backward'),
              ),
              LiquidGlassButton.icon(
                id: 'rtl-symbol-forward',
                icon: Icons.arrow_forward,
                sfSymbol: 'arrow.forward',
                semanticLabel: 'Forward symbol',
                onPressed: _record('forward'),
              ),
              LiquidGlassButton.icon(
                id: 'rtl-symbol-left',
                icon: Icons.west,
                sfSymbol: 'arrow.left',
                semanticLabel: 'Left symbol',
                onPressed: _record('left'),
              ),
              LiquidGlassButton.icon(
                id: 'rtl-symbol-star',
                icon: Icons.star,
                sfSymbol: 'star',
                semanticLabel: 'Star symbol',
                onPressed: _record('star'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              LiquidGlassButton(
                id: 'rtl-chevron-back',
                label: 'Back',
                icon: Icons.chevron_left,
                sfSymbol: 'chevron.backward',
                onPressed: _record('back'),
              ),
              LiquidGlassButton(
                id: 'rtl-chevron-next',
                label: 'Next',
                icon: Icons.chevron_right,
                sfSymbol: 'chevron.forward',
                onPressed: _record('next'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LiquidGlassSegmentedControl<int>(
            segments: const [
              LiquidGlassSegment(value: 0, label: 'Day'),
              LiquidGlassSegment(value: 1, label: 'Week'),
              LiquidGlassSegment(value: 2, label: 'Month'),
            ],
            selected: _segment,
            onChanged: (value) => setState(() => _segment = value),
          ),
          const SizedBox(height: 12),
          Text('Segment: $_segment'),
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LiquidGlassButtonGroup(
              actions: [
                LiquidGlassAction(
                  id: 'rtl-group-copy',
                  label: 'Copy',
                  onPressed: _record('copy'),
                ),
                // Toggle Paste changes its enabled state in place.
                LiquidGlassAction(
                  id: 'rtl-group-paste',
                  label: 'Paste',
                  onPressed: _pasteEnabled
                      ? () => setState(() => _pastes++)
                      : null,
                ),
                LiquidGlassAction(
                  id: 'rtl-group-cut',
                  label: 'Cut',
                  onPressed: _record('cut'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _pasteEnabled = !_pasteEnabled),
              child: const Text('Toggle Paste'),
            ),
          ),
          Text('Paste enabled: $_pasteEnabled'),
          Text('Paste presses: $_pastes'),
          Text('Last action: $_lastAction'),
          Text('Tab: $_tab'),
          Text('Find presses: $_finds'),
        ],
      ),
      // Gamma is drawn from Material glyphs and starts unselected.
      bottomNavigationBar: LiquidGlassTabBar(
        items: const [
          LiquidGlassTabItem(
            label: 'Alpha',
            icon: Icons.home,
            sfSymbol: 'house',
          ),
          LiquidGlassTabItem(
            label: 'Beta',
            icon: Icons.star_border,
            sfSymbol: 'star',
            badge: '',
          ),
          LiquidGlassTabItem(
            label: 'Gamma',
            icon: Icons.settings,
            selectedIcon: Icons.settings_suggest,
          ),
        ],
        selectedIndex: _tab,
        onSelected: (value) => setState(() => _tab = value),
        trailingAction: LiquidGlassAction(
          id: 'rtl-find',
          label: 'Find',
          onPressed: () => setState(() => _finds++),
        ),
      ),
    ),
  );
}
