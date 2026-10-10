import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

void main() => runApp(const GlassExample());

class GlassExample extends StatefulWidget {
  const GlassExample({super.key});
  @override
  State<GlassExample> createState() => _GlassExampleState();
}

class _GlassExampleState extends State<GlassExample> {
  final observer = LiquidGlassNavigatorObserver();
  LiquidGlassMode mode = LiquidGlassMode.auto;
  ThemeMode appearance = ThemeMode.system;
  bool reduced = false;
  int index = 0;

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
        data: LiquidGlassThemeData(mode: mode, reduceTransparency: reduced),
        child: child!,
      ),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        extendBody: true,
        appBar: LiquidGlassNavigationBar(
          title: 'Liquid Glass controls',
          actions: [
            LiquidGlassAction(
              id: 'sheet',
              label: 'Open sheet',
              icon: Icons.more_horiz,
              sfSymbol: 'ellipsis',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Glass underneath must not bleed through this sheet.',
                        ),
                        const SizedBox(height: 24),
                        LiquidGlassButton(
                          label: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: LiquidGlassTabBar(
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
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            Text(
              'Native available: $liquidGlassNativeAvailable · selected: $index',
            ),
            const SizedBox(height: 16),
            LiquidGlassSegmentedControl(
              segments: [
                for (final value in LiquidGlassMode.values)
                  LiquidGlassSegment(value: value, label: value.name),
              ],
              selected: mode,
              onChanged: (value) => setState(() => mode = value),
            ),
            const SizedBox(height: 12),
            LiquidGlassSegmentedControl(
              segments: const [
                LiquidGlassSegment(value: ThemeMode.system, label: 'System'),
                LiquidGlassSegment(value: ThemeMode.light, label: 'Light'),
                LiquidGlassSegment(value: ThemeMode.dark, label: 'Dark'),
              ],
              selected: appearance,
              onChanged: (value) => setState(() => appearance = value),
            ),
            SwitchListTile(
              title: const Text('Reduce transparency'),
              value: reduced,
              onChanged: (value) => setState(() => reduced = value),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                LiquidGlassButton(
                  label: 'Primary',
                  prominent: true,
                  icon: Icons.add,
                  sfSymbol: 'plus',
                  onPressed: () {},
                ),
                LiquidGlassButton(
                  icon: Icons.search,
                  semanticLabel: 'Search',
                  sfSymbol: 'magnifyingglass',
                  onPressed: () {},
                ),
                const LiquidGlassButton(label: 'Disabled'),
                const LiquidGlassButton(label: 'Loading', loading: true),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassButtonGroup(
                actions: [
                  LiquidGlassAction(
                    id: 'group-search',
                    label: 'Search',
                    icon: Icons.search,
                    sfSymbol: 'magnifyingglass',
                    onPressed: () {},
                  ),
                  LiquidGlassAction(
                    id: 'group-add',
                    label: 'Add',
                    icon: Icons.add,
                    sfSymbol: 'plus',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassButton(
                label: '会话',
                icon: Icons.chat_bubble_outline,
                sfSymbol: 'bubble.left.and.bubble.right',
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 24),
            const LiquidGlassSurface(
              padding: EdgeInsets.all(16),
              child: TextField(
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Flutter editing: 中文 / 日本語 / emoji 👩🏽‍💻',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Today', style: Theme.of(context).textTheme.labelLarge),
            for (var i = 0; i < 18; i++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 1, thickness: .5),
            ],
          ],
        ),
      ),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final foreground = dark ? Colors.white : Colors.black;
    final background = dark ? Colors.black : Colors.white;
    final colors = (dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
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
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: colors.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
