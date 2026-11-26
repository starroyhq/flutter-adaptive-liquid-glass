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

  int _selections = 0, _cancellations = 0;
  String _lastSelection = 'none';

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
                  onSelected: (value) => setState(() {
                    _lastSelection = value;
                    _selections++;
                  }),
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
