import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

class NativeNavigationProbePage extends StatefulWidget {
  const NativeNavigationProbePage({super.key});

  @override
  State<NativeNavigationProbePage> createState() =>
      _NativeNavigationProbePageState();
}

class _NativeNavigationProbePageState extends State<NativeNavigationProbePage> {
  // A small two-color bookmark PNG to exercise caller-supplied bitmap pixels.
  static final _bookmarkPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAAO0lEQVR4nGNgGAX4'
    'gERB639S8KjBowYPRoNlwuf8JwWPMIOJkSPZYFLliTKYEjU4NVFLHYoGWqgdoQAA'
    'naJMLPwXWc4AAAAASUVORK5CYII=',
  );
  static const _bookmarkItems = [
    LiquidGlassMenuItem(
      value: 'move',
      label: 'Move bookmark',
      sfSymbol: 'folder',
      icon: Icons.folder_outlined,
      children: [
        LiquidGlassMenuItem(value: 'archive', label: 'Archive bookmark'),
      ],
    ),
    LiquidGlassMenuItem(
      value: 'remove',
      label: 'Remove bookmark',
      enabled: false,
      destructive: true,
    ),
  ];

  int _edits = 0;
  bool _rtl = false;
  String? _badge = '3';
  String _display = 'list';
  String _bookmark = 'none';

  List<LiquidGlassMenuItem<String>> get _displayItems => [
    LiquidGlassMenuItem(
      value: 'grid',
      label: 'Grid layout',
      sfSymbol: 'square.grid.2x2',
      icon: Icons.grid_view,
      selected: _display == 'grid',
    ),
    LiquidGlassMenuItem(
      value: 'list',
      label: 'List layout',
      sfSymbol: 'list.bullet',
      icon: Icons.list,
      selected: _display == 'list',
    ),
  ];

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassNavigationBar(
        title: 'Files',
        leading: [
          LiquidGlassAction(
            id: 'nav-probe-back',
            label: 'Back to catalog',
            icon: Icons.arrow_back,
            sfSymbol: 'chevron.backward',
            onPressed: Navigator.of(context).canPop()
                ? () => Navigator.of(context).pop()
                : null,
          ),
          LiquidGlassAction(
            id: 'nav-probe-edit',
            label: 'Edit',
            onPressed: () => setState(() => _edits++),
          ),
        ],
        actions: [
          LiquidGlassAction(
            id: 'nav-probe-display',
            label: 'Display options',
            icon: Icons.tune,
            menu: LiquidGlassNavigationMenu(
              items: _displayItems,
              onSelected: (value) => setState(() => _display = value),
            ),
          ),
          LiquidGlassAction(
            id: 'nav-probe-bookmark',
            label: 'Bookmark options',
            iconPng: _bookmarkPng,
            badge: _badge,
            menu: LiquidGlassNavigationMenu(
              items: _bookmarkItems,
              onSelected: (value) => setState(() => _bookmark = value),
            ),
          ),
        ],
      ),
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
                  Text('Edits: $_edits'),
                  Text('Layout: $_display'),
                  Text('Bookmark: $_bookmark'),
                  Text('Badge: ${_badge ?? 'none'}'),
                  TextButton(
                    onPressed: () => setState(
                      () => _badge = switch (_badge) {
                        '3' => '8',
                        '8' => null,
                        _ => '3',
                      },
                    ),
                    child: const Text('Cycle badge'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _rtl = !_rtl),
                    child: const Text('Switch direction'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
