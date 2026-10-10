import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'catalog_popups.dart';

/// Independent synthetic data only. No account, network or application services.
class ComponentCatalogApp extends StatefulWidget {
  const ComponentCatalogApp({
    super.key,
    this.initialMode = LiquidGlassMode.auto,
  });
  final LiquidGlassMode initialMode;
  @override
  State<ComponentCatalogApp> createState() => _ComponentCatalogAppState();
}

class _ComponentCatalogAppState extends State<ComponentCatalogApp> {
  final _observer = LiquidGlassNavigatorObserver();
  late LiquidGlassMode _mode = widget.initialMode;
  ThemeMode _appearance = ThemeMode.system;
  bool _branded = false, _reduceMotion = false, _opaque = false;
  int _page = 0, _segment = 0, _presses = 0;
  int _sliderStarts = 0, _sliderEnds = 0;
  double? _sliderLastEnd;
  double _slider = .4, _stepper = 2;
  bool _enabled = true;
  DateTime _date = DateTime(2026, 10, 10, 12);
  Color _color = const Color(0xff2463b8);
  LiquidGlassDatePickerMode _dateMode = LiquidGlassDatePickerMode.dateAndTime;
  LiquidGlassDatePickerStyle _dateStyle = LiquidGlassDatePickerStyle.compact;

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _branded ? Colors.teal : Colors.blueGrey,
      brightness: brightness,
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Component catalog',
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [
      Locale('en'),
      Locale('zh'),
      Locale('zh', 'TW'),
      Locale('ja'),
      Locale('ar'),
    ],
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: _appearance,
    navigatorObservers: [_observer],
    builder: (context, child) => LiquidGlassAppearance(
      mode: _appearance,
      child: LiquidGlassTheme(
        data: LiquidGlassThemeData(
          mode: _mode,
          reduceMotion: _reduceMotion,
          reduceTransparency: _opaque,
          colors: _branded
              ? LiquidGlassColors.fromColorScheme(Theme.of(context).colorScheme)
              : const LiquidGlassColors(),
        ),
        child: child!,
      ),
    ),
    home: Builder(builder: _home),
  );

  Widget _home(BuildContext context) => Scaffold(
    appBar: LiquidGlassNavigationBar(
      title: 'Component catalog',
      actions: [
        LiquidGlassAction(
          id: 'appearance',
          label: 'Appearance',
          icon: Icons.tune,
          sfSymbol: 'slider.horizontal.3',
          onPressed: () => _settings(context),
        ),
      ],
    ),
    body: SingleChildScrollView(
      key: ValueKey('catalog-page-$_page'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '21 component capabilities · ${LiquidGlassTheme.modeOf(context).name}',
            key: const ValueKey('catalog-renderer'),
          ),
          const Text(
            'iOS 26+ tabs stay native. Search and custom popups keep Flutter content.',
          ),
          const SizedBox(height: 16),
          if (_page == 0) ..._controls(context),
          if (_page == 1) ..._pickers(context),
          if (_page == 2) const CatalogPopups(),
          if (_page == 3) ...[
            _heading('Search field'),
            const LiquidGlassSearchField(
              key: ValueKey('catalog-search'),
              hintText: 'Try 中文 or emoji 👩🏽‍💻',
            ),
            const SizedBox(height: 24),
            LiquidGlassButton(
              label: 'Open search scaffold',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _SearchDemo()),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : LiquidGlassTabBar(
            items: const [
              LiquidGlassTabItem(
                label: 'Controls',
                icon: Icons.tune,
                sfSymbol: 'slider.horizontal.3',
              ),
              LiquidGlassTabItem(
                label: 'Pickers',
                icon: Icons.palette_outlined,
                sfSymbol: 'paintpalette',
              ),
              LiquidGlassTabItem(
                label: 'Popups',
                icon: Icons.layers_outlined,
                sfSymbol: 'square.stack',
              ),
              LiquidGlassTabItem(
                label: 'Search',
                icon: Icons.search,
                sfSymbol: 'magnifyingglass',
              ),
            ],
            selectedIndex: _page,
            onSelected: (value) => setState(() => _page = value),
          ),
  );

  List<Widget> _controls(BuildContext context) => [
    _heading('Surface and buttons'),
    const LiquidGlassSurface(
      padding: EdgeInsets.all(16),
      child: Text('A bounded surface. Reading content stays on the page.'),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        LiquidGlassButton(
          label: 'Action',
          onPressed: () => setState(() => _presses++),
        ),
        LiquidGlassButton.icon(
          icon: Icons.add,
          sfSymbol: 'plus',
          semanticLabel: 'Add',
          onPressed: () => setState(() => _presses++),
        ),
        const LiquidGlassButton(label: 'Disabled'),
        const LiquidGlassButton(label: 'Loading', loading: true),
      ],
    ),
    Text('Action count: $_presses'),
    _heading('Grouped toolbar'),
    LiquidGlassToolbar(
      groups: [
        [
          LiquidGlassAction(
            id: 'undo',
            label: 'Undo',
            icon: Icons.undo,
            sfSymbol: 'arrow.uturn.backward',
            onPressed: () => setState(() => _presses--),
          ),
          LiquidGlassAction(
            id: 'redo',
            label: 'Redo',
            icon: Icons.redo,
            sfSymbol: 'arrow.uturn.forward',
            onPressed: () => setState(() => _presses++),
          ),
        ],
        [
          LiquidGlassAction(
            id: 'copy',
            label: 'Copy',
            icon: Icons.copy,
            sfSymbol: 'doc.on.doc',
            onPressed: () => setState(() => _presses++),
          ),
        ],
      ],
    ),
    _heading('Segmented control'),
    LiquidGlassSegmentedControl<int>(
      segments: const [
        LiquidGlassSegment(value: 0, label: 'Recent'),
        LiquidGlassSegment(value: 1, label: 'All'),
      ],
      selected: _segment,
      onChanged: (value) => setState(() => _segment = value),
    ),
    _heading('Slider'),
    LiquidGlassSlider(
      key: const ValueKey('catalog-slider'),
      value: _slider,
      divisions: 10,
      semanticLabel: 'Preview level',
      onChangeStart: (_) => setState(() => _sliderStarts++),
      onChanged: (value) => setState(() => _slider = value),
      onChangeEnd: (value) => setState(() {
        _sliderEnds++;
        _sliderLastEnd = value;
      }),
    ),
    Text(
      'Value: ${_slider.toStringAsFixed(1)}',
      key: const ValueKey('catalog-slider-value'),
    ),
    Text(
      'Gestures: $_sliderStarts / $_sliderEnds · '
      'Last end: ${_sliderLastEnd?.toStringAsFixed(1) ?? 'none'}',
    ),
    _heading('Switch'),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: LiquidGlassSwitch(
        key: const ValueKey('catalog-switch'),
        value: _enabled,
        semanticLabel: 'Enable preview',
        onChanged: (value) => setState(() => _enabled = value),
      ),
    ),
    Text('Enabled: $_enabled', key: const ValueKey('catalog-switch-value')),
    _heading('Stepper'),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: LiquidGlassStepper(
        key: const ValueKey('catalog-stepper'),
        value: _stepper,
        min: 0,
        max: 5,
        wraps: true,
        semanticLabel: 'Copies',
        onChanged: (value) => setState(() => _stepper = value),
      ),
    ),
    Text(
      'Copies: ${_stepper.toInt()}',
      key: const ValueKey('catalog-stepper-value'),
    ),
    _heading('Activity and progress'),
    const Align(
      alignment: AlignmentDirectional.centerStart,
      child: LiquidGlassActivityIndicator(
        animating: false,
        hidesWhenStopped: false,
        semanticLabel: 'Idle indicator',
      ),
    ),
    LiquidGlassProgressView(
      progress: _slider,
      semanticLabel: 'Preview progress',
    ),
  ];

  List<Widget> _pickers(BuildContext context) => [
    _heading('Date picker'),
    DropdownButton<LiquidGlassDatePickerMode>(
      isExpanded: true,
      value: _dateMode,
      items: [
        for (final mode in LiquidGlassDatePickerMode.values)
          DropdownMenuItem(value: mode, child: Text(mode.name)),
      ],
      onChanged: (mode) => setState(() => _dateMode = mode!),
    ),
    DropdownButton<LiquidGlassDatePickerStyle>(
      isExpanded: true,
      value: _dateStyle,
      items: [
        for (final style in LiquidGlassDatePickerStyle.values)
          DropdownMenuItem(value: style, child: Text(style.name)),
      ],
      onChanged: (style) => setState(() => _dateStyle = style!),
    ),
    LiquidGlassDatePicker(
      key: const ValueKey('catalog-date'),
      value: _date,
      mode: _dateMode,
      style: _dateStyle,
      onChanged: (value) => setState(() => _date = value),
    ),
    Text(
      'Date: ${_date.toIso8601String()}',
      key: const ValueKey('catalog-date-value'),
    ),
    _heading('Color picker'),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: LiquidGlassColorPicker(
        key: const ValueKey('catalog-color'),
        selectedColor: _color,
        title: 'Preview color',
        semanticLabel: 'Preview color',
        onChanged: (value) => setState(() => _color = value),
      ),
    ),
    Text(
      'ARGB: ${_color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      key: const ValueKey('catalog-color-value'),
    ),
  ];

  Future<void> _settings(BuildContext context) => showLiquidGlassSheet<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, localSetState) {
        void change(VoidCallback callback) {
          setState(callback);
          localSetState(() {});
        }

        return ListView(
          primary: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Appearance and accessibility',
              style: TextStyle(fontSize: 20),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in ThemeMode.values)
                  TextButton(
                    key: ValueKey('catalog-theme-${mode.name}'),
                    onPressed: () => change(() => _appearance = mode),
                    child: Text(mode.name),
                  ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('catalog-palette'),
              title: const Text('Custom teal palette'),
              value: _branded,
              onChanged: (value) => change(() => _branded = value),
            ),
            SwitchListTile(
              title: const Text('Reduce motion'),
              value: _reduceMotion,
              onChanged: (value) => change(() => _reduceMotion = value),
            ),
            SwitchListTile(
              title: const Text('Reduce transparency'),
              value: _opaque,
              onChanged: (value) => change(() => _opaque = value),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in LiquidGlassMode.values)
                  TextButton(
                    onPressed: () => change(() => _mode = mode),
                    child: Text(mode.name),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

Widget _heading(String title) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 12),
  child: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  ),
);

class _SearchDemo extends StatefulWidget {
  const _SearchDemo();
  @override
  State<_SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<_SearchDemo> {
  final controller = TextEditingController();
  bool active = false;
  int index = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LiquidGlassSearchScaffold(
    appBar: AppBar(title: const Text('Search scaffold')),
    body: IndexedStack(
      index: index,
      children: const [
        Center(child: Text('First application page')),
        Center(child: Text('Second application page')),
      ],
    ),
    tabs: const [
      LiquidGlassTabItem(label: 'First', icon: Icons.home, sfSymbol: 'house'),
      LiquidGlassTabItem(
        label: 'Second',
        icon: Icons.person,
        sfSymbol: 'person',
      ),
    ],
    selectedIndex: index,
    onTabChanged: (value) => setState(() => index = value),
    searchController: controller,
    searchActive: active,
    onSearchActiveChanged: (value) => setState(() => active = value),
    onSearchChanged: (_) => setState(() {}),
    searchResults: Center(child: Text('Results for: ${controller.text}')),
  );
}
