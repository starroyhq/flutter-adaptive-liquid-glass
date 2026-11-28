import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

class NativeMenuProbePage extends StatefulWidget {
  const NativeMenuProbePage({super.key});

  @override
  State<NativeMenuProbePage> createState() => _NativeMenuProbePageState();
}

class _NativeMenuProbePageState extends State<NativeMenuProbePage> {
  static const _items = [
    LiquidGlassMenuItem(value: 'rename', label: 'Rename', icon: Icons.edit),
    LiquidGlassMenuItem(
      value: 'favorite',
      label: 'Favorite',
      icon: Icons.star,
      sfSymbol: 'star',
      selected: true,
    ),
    LiquidGlassMenuItem(
      value: 'move',
      label: 'Move to',
      icon: Icons.folder,
      sfSymbol: 'folder',
      children: [
        LiquidGlassMenuItem(value: 'archive', label: 'Archive folder'),
      ],
    ),
    LiquidGlassMenuItem(
      value: 'delete',
      label: 'Delete',
      icon: Icons.delete,
      sfSymbol: 'trash',
      enabled: false,
      destructive: true,
    ),
  ];
  static const _modes = [
    LiquidGlassMenuItem(
      value: 'modes',
      label: 'Modes',
      displayInline: true,
      children: [
        LiquidGlassMenuItem(
          value: 'standard',
          label: 'Standard mode',
          subtitle: 'Uses the current settings',
          selected: true,
        ),
        LiquidGlassMenuItem(value: 'quiet', label: 'Quiet mode'),
      ],
    ),
    LiquidGlassMenuItem(
      value: 'reset',
      label: 'Reset modes',
      enabled: false,
      destructive: true,
    ),
    LiquidGlassMenuItem(
      value: 'remove',
      label: 'Remove modes',
      destructive: true,
    ),
  ];

  int _selections = 0, _cancellations = 0;
  String _lastSelection = 'none';
  String _imperativeSelection = 'none';
  bool _editorFocused = false;

  void _select(String value) => setState(() {
    _lastSelection = value;
    _selections++;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Native menu probe')),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffd5e7f2), Color(0xfff2e0c1)],
        ),
      ),
      child: SizedBox.expand(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiquidGlassMenuButton(
                  id: 'native-menu-probe',
                  label: 'File actions',
                  items: _items,
                  onSelected: _select,
                  onCanceled: () => setState(() => _cancellations++),
                ),
                const SizedBox(height: 16),
                Semantics(
                  container: true,
                  child: Text('Last selection: $_lastSelection'),
                ),
                Semantics(
                  container: true,
                  child: Text('Menu selections: $_selections'),
                ),
                Semantics(
                  container: true,
                  child: Text('Menu cancellations: $_cancellations'),
                ),
                const SizedBox(height: 16),
                LiquidGlassMenuButton(
                  id: 'native-menu-custom-trigger',
                  semanticLabel: 'Custom modes',
                  items: _modes,
                  onSelected: _select,
                  triggerChild: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 174,
                      height: 48,
                      child: Center(child: Text('Custom modes')),
                    ),
                  ),
                ),
                Focus(
                  canRequestFocus: false,
                  onFocusChange: (focused) =>
                      setState(() => _editorFocused = focused),
                  child: const TextField(
                    decoration: InputDecoration(labelText: 'Menu editor'),
                  ),
                ),
                TextFieldTapRegion(
                  child: Builder(
                    builder: (anchorContext) => TextButton(
                      onPressed: () async {
                        final value = await showLiquidGlassMenu(
                          context: context,
                          anchorContext: anchorContext,
                          items: _modes,
                          semanticLabel: 'Editor modes',
                        );
                        if (mounted && value != null) {
                          setState(() => _imperativeSelection = value);
                        }
                      },
                      child: const Text('Editor modes'),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  child: Text('Editor selection: $_imperativeSelection'),
                ),
                Semantics(
                  container: true,
                  child: Text('Editor focus: $_editorFocused'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
