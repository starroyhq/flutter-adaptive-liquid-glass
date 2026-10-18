import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// The controls added in 0.5.0 on one page: a navigation bar with a subtitle
/// over content that scrolls beneath it, scroll edge effects, buttons with a
/// detail, a coloured mark and a menu indicator, and the modal scrims.
class NewControlsExample extends StatefulWidget {
  const NewControlsExample({super.key, this.themeMode = ThemeMode.system});
  final ThemeMode themeMode;

  @override
  State<NewControlsExample> createState() => _NewControlsExampleState();
}

class _NewControlsExampleState extends State<NewControlsExample> {
  final observer = LiquidGlassNavigatorObserver();
  late ThemeMode themeMode = widget.themeMode;
  String model = 'High';
  int tab = 0;
  int searches = 0;

  @override
  void didUpdateWidget(NewControlsExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) themeMode = widget.themeMode;
  }

  @override
  void dispose() {
    observer.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? Colors.black
        : const Color(0xfff2f2f5),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'New controls',
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: themeMode,
    navigatorObservers: [observer],
    builder: (context, child) =>
        LiquidGlassAppearance(mode: themeMode, child: child!),
    home: Builder(builder: _page),
  );

  Widget _page(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    const bar = 64.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      bottomNavigationBar: LiquidGlassTabBar(
        items: const [
          LiquidGlassTabItem(
            label: 'Inbox',
            icon: Icons.inbox_outlined,
            sfSymbol: 'tray',
          ),
          LiquidGlassTabItem(
            label: 'Sessions',
            icon: Icons.chat_bubble_outline,
            sfSymbol: 'bubble.left.and.bubble.right',
          ),
          LiquidGlassTabItem(
            label: 'Account',
            icon: Icons.person_outline,
            sfSymbol: 'person.crop.circle',
          ),
        ],
        selectedIndex: tab,
        onSelected: (value) => setState(() => tab = value),
        trailingAction: LiquidGlassAction(
          id: 'search',
          label: 'Search',
          onPressed: () => setState(() => searches++),
        ),
      ),
      appBar: LiquidGlassNavigationBar(
        title: 'New controls',
        subtitle: 'Synthetic workspace',
        actions: [
          LiquidGlassAction(
            id: 'appearance',
            label: 'Toggle appearance',
            icon: Icons.brightness_6,
            sfSymbol: 'circle.lefthalf.filled',
            onPressed: () => setState(
              () => themeMode = dark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
        ],
      ),
      body: LiquidGlassScrollEdgeEffect(
        top: padding.top + bar + 16,
        bottom: padding.bottom + 96,
        child: ListView(
          key: const ValueKey('new-controls-list'),
          padding: EdgeInsets.fromLTRB(
            16,
            padding.top + bar + 8,
            16,
            padding.bottom + 96,
          ),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                LiquidGlassButton(
                  id: 'computer',
                  label: 'Studio',
                  detail: 'Online',
                  icon: Icons.circle,
                  sfSymbol: 'circle.fill',
                  iconColor: const Color(0xff16a34a),
                  iconSize: 10,
                  menuIndicator: true,
                  onPressed: () {},
                ),
                LiquidGlassMenuButton<String>(
                  label: 'Model',
                  detail: model,
                  menuIndicator: true,
                  icon: null,
                  sfSymbol: null,
                  onSelected: (value) => setState(() => model = value),
                  items: [
                    for (final effort in ['Low', 'Medium', 'High'])
                      LiquidGlassMenuItem(
                        value: effort,
                        label: effort,
                        selected: effort == model,
                      ),
                  ],
                ),
                SizedBox(
                  width: 180,
                  child: LiquidGlassButton(
                    id: 'long',
                    label: 'A label longer than its button',
                    onPressed: () {},
                  ),
                ),
                LiquidGlassButton(
                  id: 'open-sheet',
                  label: 'Sheet',
                  onPressed: () => showLiquidGlassSheet<void>(
                    context: context,
                    fitContent: true,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('A sheet over the default scrim'),
                    ),
                  ),
                ),
                LiquidGlassButton(
                  id: 'open-alert',
                  label: 'Alert',
                  onPressed: () => showLiquidGlassAlert<void>(
                    context: context,
                    title: const Text('An alert over the default scrim'),
                    actions: const [
                      LiquidGlassAlertAction(value: null, label: 'OK'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Labelled actions: one group per row, so both stay in view.
            for (final group in [
              [
                LiquidGlassAction(
                  id: 'previous',
                  label: 'Previous',
                  icon: Icons.keyboard_arrow_up,
                  sfSymbol: 'chevron.up',
                  showLabel: true,
                  onPressed: () {},
                ),
                LiquidGlassAction(
                  id: 'next',
                  label: 'Next',
                  icon: Icons.keyboard_arrow_down,
                  sfSymbol: 'chevron.down',
                  onPressed: () {},
                ),
              ],
              [
                LiquidGlassAction(
                  id: 'save',
                  label: 'Save',
                  icon: Icons.download,
                  sfSymbol: 'square.and.arrow.down',
                  showLabel: true,
                  onPressed: () {},
                ),
                LiquidGlassAction(
                  id: 'share',
                  label: 'Share',
                  icon: Icons.ios_share,
                  sfSymbol: 'square.and.arrow.up',
                  showLabel: true,
                  onPressed: () {},
                ),
              ],
            ])
              LiquidGlassToolbar(
                padding: const EdgeInsets.only(bottom: 12),
                groups: [group],
              ),
            const SizedBox(height: 24),
            for (var i = 0; i < 40; i++)
              Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xff2563eb),
                    const Color(0xffd97706),
                    i / 39,
                  )!.withValues(alpha: dark ? .5 : .25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Row ${i + 1} scrolls beneath the bars'),
              ),
          ],
        ),
      ),
    );
  }
}
