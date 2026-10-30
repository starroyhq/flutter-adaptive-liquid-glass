import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// A fixed page for screenshot comparison and UI tests of native layout: icon
/// buttons with and without a long press side by side, popups over native
/// controls, and native buttons in a right-to-left region.
///
/// Its first row is where the native controls probe's first row is, in the
/// same theme, so crops of the two pages can be compared.
class NativeLayoutProbeApp extends StatefulWidget {
  const NativeLayoutProbeApp({super.key});

  @override
  State<NativeLayoutProbeApp> createState() => _NativeLayoutProbeAppState();
}

class _NativeLayoutProbeAppState extends State<NativeLayoutProbeApp> {
  final _observer = LiquidGlassNavigatorObserver();

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Native layout probe',
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    navigatorObservers: [_observer],
    builder: (context, child) =>
        LiquidGlassAppearance(mode: ThemeMode.system, child: child!),
    home: const NativeLayoutProbePage(),
  );
}

/// The probe page itself; the catalog's Search page also pushes it.
class NativeLayoutProbePage extends StatefulWidget {
  const NativeLayoutProbePage({super.key});

  @override
  State<NativeLayoutProbePage> createState() => _NativeLayoutProbePageState();
}

class _NativeLayoutProbePageState extends State<NativeLayoutProbePage> {
  int _taps = 0, _holds = 0, _layout = 0, _tab = 0;
  String _result = 'none';

  void _tap() => setState(() => _taps++);

  void _hold() => setState(() => _holds++);

  void _record(String result) {
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Native layout probe')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Each pair is one icon without and with a long press, in the places
        // of the controls probe's first row.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LiquidGlassButton.icon(
              id: 'layout-plus-tap',
              icon: Icons.add,
              sfSymbol: 'plus',
              semanticLabel: 'Plus tap',
              onPressed: _tap,
            ),
            LiquidGlassButton.icon(
              id: 'layout-plus-hold',
              icon: Icons.add,
              sfSymbol: 'plus',
              semanticLabel: 'Plus hold',
              onPressed: _tap,
              onLongPress: _hold,
              longPressSemanticLabel: 'Count a hold',
            ),
            LiquidGlassButton.icon(
              id: 'layout-trash-tap',
              icon: Icons.delete_outline,
              sfSymbol: 'trash',
              semanticLabel: 'Trash tap',
              onPressed: _tap,
            ),
            LiquidGlassButton.icon(
              id: 'layout-trash-hold',
              icon: Icons.delete_outline,
              sfSymbol: 'trash',
              semanticLabel: 'Trash hold',
              onPressed: _tap,
              onLongPress: _hold,
              longPressSemanticLabel: 'Count a hold',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          children: [
            Text('Icon taps: $_taps'),
            Text('Icon holds: $_holds'),
            Text('Layout: $_layout'),
            Text('Tab: $_tab'),
          ],
        ),
        const SizedBox(height: 16),
        LiquidGlassSegmentedControl<int>(
          segments: const [
            LiquidGlassSegment(value: 0, label: 'List'),
            LiquidGlassSegment(value: 1, label: 'Grid'),
          ],
          selected: _layout,
          onChanged: (value) => setState(() => _layout = value),
        ),
        const SizedBox(height: 16),
        // Popups over the native controls on this page.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LiquidGlassMenuButton<String>(
              label: 'Menu',
              items: const [
                LiquidGlassMenuItem(value: 'first', label: 'First choice'),
                LiquidGlassMenuItem(value: 'second', label: 'Second choice'),
              ],
              onSelected: (value) => _record('menu $value'),
              onCanceled: () => _record('menu cancelled'),
            ),
            LiquidGlassButton(
              id: 'layout-alert',
              label: 'Alert',
              onPressed: () async {
                final value = await showLiquidGlassAlert<String>(
                  context: context,
                  title: const Text('Confirm'),
                  content: const Text(
                    'Native views beneath stay under the barrier.',
                  ),
                  actions: const [
                    LiquidGlassAlertAction(
                      label: 'Cancel',
                      value: 'cancel',
                      cancel: true,
                    ),
                    LiquidGlassAlertAction(label: 'OK', value: 'ok'),
                  ],
                );
                _record('alert ${value ?? 'dismissed'}');
              },
            ),
            LiquidGlassButton(
              id: 'layout-sheet',
              label: 'Sheet',
              onPressed: () async {
                final value = await showLiquidGlassSheet<String>(
                  context: context,
                  fitContent: true,
                  builder: (_) => const _LayoutSheet(),
                );
                _record('sheet ${value ?? 'dismissed'}');
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Popup result: $_result'),
        const SizedBox(height: 16),
        const Text('Right to left'),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  LiquidGlassButton(
                    id: 'rtl-favorite',
                    label: 'Favorite',
                    icon: Icons.star,
                    sfSymbol: 'star',
                    onPressed: () {},
                  ),
                  // No SF Symbol: the native button mirrors the Material glyph.
                  LiquidGlassButton.icon(
                    id: 'rtl-back',
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back bitmap',
                    onPressed: () {},
                  ),
                  LiquidGlassButton.icon(
                    id: 'rtl-back-symbol',
                    icon: Icons.arrow_back,
                    sfSymbol: 'arrow.backward',
                    semanticLabel: 'Back symbol',
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LiquidGlassButtonGroup(
                actions: [
                  LiquidGlassAction(
                    id: 'rtl-first',
                    label: 'First',
                    onPressed: () {},
                  ),
                  LiquidGlassAction(
                    id: 'rtl-second',
                    label: 'Second',
                    onPressed: () {},
                  ),
                  LiquidGlassAction(
                    id: 'rtl-third',
                    label: 'Third',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: LiquidGlassTabBar(
      items: const [
        LiquidGlassTabItem(label: 'Home', icon: Icons.home, sfSymbol: 'house'),
        LiquidGlassTabItem(
          label: 'Saved',
          icon: Icons.bookmark_border,
          sfSymbol: 'bookmark',
        ),
        LiquidGlassTabItem(
          label: 'Profile',
          icon: Icons.person_outline,
          sfSymbol: 'person',
        ),
      ],
      selectedIndex: _tab,
      onSelected: (value) => setState(() => _tab = value),
    ),
  );
}

/// A sheet with native buttons, which stay visible above the page's
/// native views.
class _LayoutSheet extends StatefulWidget {
  const _LayoutSheet();

  @override
  State<_LayoutSheet> createState() => _LayoutSheetState();
}

class _LayoutSheetState extends State<_LayoutSheet> {
  int _presses = 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout sheet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LiquidGlassButton(
              id: 'layout-sheet-action',
              label: 'Sheet action',
              onPressed: () => setState(() => _presses++),
            ),
            LiquidGlassButton(
              id: 'layout-sheet-close',
              label: 'Close',
              onPressed: () => Navigator.of(context).pop('closed'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Sheet presses: $_presses'),
      ],
    ),
  );
}
