import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    home: const _ControlsPage(),
  ),
);

class _ControlsPage extends StatefulWidget {
  const _ControlsPage();

  @override
  State<_ControlsPage> createState() => _ControlsPageState();
}

class _ControlsPageState extends State<_ControlsPage> {
  int _tab = 0;
  int _segment = 0;
  bool _switchedOn = true;
  double _volume = .62;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      appBar: LiquidGlassNavigationBar(
        title: 'Library',
        leading: [
          LiquidGlassAction(
            id: 'back',
            label: 'Back',
            icon: Icons.chevron_left,
            sfSymbol: 'chevron.backward',
            onPressed: () {},
          ),
        ],
        actions: [
          LiquidGlassAction(
            id: 'search',
            label: 'Search',
            icon: Icons.search,
            sfSymbol: 'magnifyingglass',
            onPressed: () {},
          ),
          LiquidGlassAction(
            id: 'more',
            label: 'More',
            icon: Icons.more_horiz,
            sfSymbol: 'ellipsis',
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final (color, alignment) in const [
                  (Color(0xffe48d52), Alignment.centerLeft),
                  (Color(0xff597dc1), Alignment.centerRight),
                  (Color(0xff4e9c86), Alignment.centerLeft),
                  (Color(0xffb56386), Alignment.centerRight),
                  (Color(0xff597dc1), Alignment.centerLeft),
                ])
                  Align(
                    alignment: alignment,
                    child: SizedBox(
                      width: 208,
                      height: 152,
                      child: ColoredBox(
                        color: Color.alphaBlend(
                          color.withAlpha(110),
                          colors.surface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: const Alignment(0, -.34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LiquidGlassSurface(
                radius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LiquidGlassSegmentedControl<int>(
                      segments: const [
                        LiquidGlassSegment(value: 0, label: 'Recent'),
                        LiquidGlassSegment(value: 1, label: 'Saved'),
                      ],
                      selected: _segment,
                      onChanged: (value) => setState(() => _segment = value),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Text('Notifications')),
                        LiquidGlassSwitch(
                          value: _switchedOn,
                          onChanged: (value) =>
                              setState(() => _switchedOn = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Volume'),
                    LiquidGlassSlider(
                      value: _volume,
                      onChanged: (value) => setState(() => _volume = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        items: const [
          LiquidGlassTabItem(
            label: 'Home',
            icon: Icons.home_outlined,
            sfSymbol: 'house',
            badge: '•',
          ),
          LiquidGlassTabItem(
            label: 'Inbox',
            icon: Icons.inbox_outlined,
            sfSymbol: 'tray',
          ),
          LiquidGlassTabItem(
            label: 'Account',
            icon: Icons.person_outline,
            sfSymbol: 'person.crop.circle',
          ),
        ],
        selectedIndex: _tab,
        onSelected: (value) => setState(() => _tab = value),
      ),
    );
  }
}
