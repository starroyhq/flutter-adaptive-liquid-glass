import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// Interactive native/Flutter composition probe, enabled with
/// `--dart-define=GLASS_MODAL_PROBE=true`. Native rendering needs an iOS device;
/// widget tests exercise only navigation, controls and state retention.
class NativeModalExample extends StatefulWidget {
  const NativeModalExample({super.key});

  @override
  State<NativeModalExample> createState() => _NativeModalExampleState();
}

class _NativeModalExampleState extends State<NativeModalExample> {
  final _settings = _ProbeSettings();
  final _observer = LiquidGlassNavigatorObserver();

  @override
  void dispose() {
    _observer.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _settings,
    builder: (context, _) => MaterialApp(
      title: 'Mixed modal probe',
      theme: _settings.theme(Brightness.light),
      darkTheme: _settings.theme(Brightness.dark),
      themeMode: _settings.appearance,
      navigatorObservers: [_observer],
      builder: (context, child) => LiquidGlassAppearance(
        mode: _settings.appearance,
        child: LiquidGlassTheme(
          data: LiquidGlassThemeData(
            colors: LiquidGlassColors.fromColorScheme(
              Theme.of(context).colorScheme,
            ),
          ),
          child: child!,
        ),
      ),
      home: _ProbeHome(settings: _settings),
    ),
  );
}

class _ProbeSettings extends ChangeNotifier {
  bool segment = const bool.fromEnvironment(
    'GLASS_MODAL_SEGMENT',
    defaultValue: true,
  );
  bool capsule = const bool.fromEnvironment(
    'GLASS_MODAL_CAPSULE',
    defaultValue: true,
  );
  bool surface = const bool.fromEnvironment(
    'GLASS_MODAL_SURFACE',
    defaultValue: true,
  );
  bool green = false;
  ThemeMode appearance = ThemeMode.system;

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  ThemeData theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: green ? const Color(0xff237957) : const Color(0xff2459b7),
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}

class _ProbeHome extends StatefulWidget {
  const _ProbeHome({required this.settings});

  final _ProbeSettings settings;

  @override
  State<_ProbeHome> createState() => _ProbeHomeState();
}

class _ProbeHomeState extends State<_ProbeHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mixed modal probe')),
    body: _ProbePanel(settings: widget.settings, depth: 0),
    bottomNavigationBar: LiquidGlassTabBar(
      items: const [
        LiquidGlassTabItem(
          label: 'First',
          icon: Icons.home_outlined,
          sfSymbol: 'house',
        ),
        LiquidGlassTabItem(
          label: 'Second',
          icon: Icons.star_outline,
          sfSymbol: 'star',
        ),
      ],
      selectedIndex: tab,
      onSelected: (value) => setState(() => tab = value),
    ),
  );
}

class _ProbePanel extends StatefulWidget {
  const _ProbePanel({required this.settings, required this.depth});

  final _ProbeSettings settings;
  final int depth;

  @override
  State<_ProbePanel> createState() => _ProbePanelState();
}

class _ProbePanelState extends State<_ProbePanel> {
  final _draft = TextEditingController();
  int selected = 0;
  int count = 0;
  bool switched = false;

  String get prefix => 'probe-${widget.depth}';

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _open(bool sheet) {
    final panel = _ProbePanel(
      settings: widget.settings,
      depth: widget.depth + 1,
    );
    if (sheet) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: panel,
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(context).height * .85,
          child: panel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.settings,
    builder: (context, _) {
      final settings = widget.settings;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: ValueKey('$prefix-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Layer ${widget.depth} · native: $liquidGlassNativeAvailable',
                key: ValueKey('$prefix-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: ValueKey('$prefix-dialog'),
                    onPressed: () => _open(false),
                    child: const Text('Open dialog'),
                  ),
                  TextButton(
                    key: ValueKey('$prefix-sheet'),
                    onPressed: () => _open(true),
                    child: const Text('Open sheet'),
                  ),
                  if (widget.depth > 0)
                    TextButton(
                      key: ValueKey('$prefix-close'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close layer'),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    key: ValueKey('$prefix-segment-factor'),
                    label: const Text('Native segment'),
                    selected: settings.segment,
                    onSelected: (value) =>
                        settings.update(() => settings.segment = value),
                  ),
                  FilterChip(
                    key: ValueKey('$prefix-capsule-factor'),
                    label: const Text('Native capsule'),
                    selected: settings.capsule,
                    onSelected: (value) =>
                        settings.update(() => settings.capsule = value),
                  ),
                  FilterChip(
                    key: ValueKey('$prefix-surface-factor'),
                    label: const Text('Native surface'),
                    selected: settings.surface,
                    onSelected: (value) =>
                        settings.update(() => settings.surface = value),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in ThemeMode.values)
                    ChoiceChip(
                      key: ValueKey('$prefix-${mode.name}'),
                      label: Text(mode.name),
                      selected: settings.appearance == mode,
                      onSelected: (_) =>
                          settings.update(() => settings.appearance = mode),
                    ),
                  ActionChip(
                    key: ValueKey('$prefix-palette'),
                    label: Text(
                      settings.green ? 'Green palette' : 'Blue palette',
                    ),
                    onPressed: () =>
                        settings.update(() => settings.green = !settings.green),
                  ),
                ],
              ),
              const Divider(),
              const Text('Flutter text A — above the first native control.'),
              const SizedBox(height: 12),
              if (settings.segment)
                LiquidGlassSegmentedControl<int>(
                  key: ValueKey('$prefix-native-segment'),
                  segments: const [
                    LiquidGlassSegment(value: 0, label: 'One'),
                    LiquidGlassSegment(value: 1, label: 'Two'),
                  ],
                  selected: selected,
                  onChanged: (value) => setState(() => selected = value),
                )
              else
                const Text('Segment absent'),
              const SizedBox(height: 12),
              Text(
                'Flutter text B — selected: $selected',
                key: ValueKey('$prefix-selection'),
              ),
              TextField(
                key: ValueKey('$prefix-draft'),
                controller: _draft,
                decoration: const InputDecoration(
                  labelText: 'Flutter draft',
                  hintText: '中文 / 日本語 / emoji 👩🏽‍💻',
                ),
              ),
              const SizedBox(height: 12),
              if (settings.capsule)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LiquidGlassButtonGroup(
                    key: ValueKey('$prefix-native-capsule'),
                    actions: [
                      LiquidGlassAction(
                        id: '$prefix-increment',
                        label: 'Count',
                        onPressed: () => setState(() => count++),
                      ),
                      LiquidGlassAction(
                        id: '$prefix-reset',
                        label: 'Reset',
                        onPressed: () => setState(() => count = 0),
                      ),
                    ],
                  ),
                )
              else
                const Text('Capsule absent'),
              Text(
                'Flutter text C — taps: $count',
                key: ValueKey('$prefix-count'),
              ),
              SwitchListTile(
                key: ValueKey('$prefix-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Flutter switch'),
                value: switched,
                onChanged: (value) => setState(() => switched = value),
              ),
              if (settings.surface)
                LiquidGlassSurface(
                  key: ValueKey('$prefix-native-surface'),
                  padding: const EdgeInsets.all(16),
                  child: const Text('Flutter text D — inside native surface.'),
                )
              else
                const Text('Surface absent'),
              const SizedBox(height: 12),
              const Text('Flutter text E — below every native control.'),
            ],
          ),
        ),
      );
    },
  );
}
