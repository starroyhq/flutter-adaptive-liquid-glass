import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// A small, synthetic native accessibility regression surface.
class NativeAccessibilityExample extends StatefulWidget {
  const NativeAccessibilityExample({super.key});

  @override
  State<NativeAccessibilityExample> createState() =>
      _NativeAccessibilityExampleState();
}

class _NativeAccessibilityExampleState
    extends State<NativeAccessibilityExample> {
  bool _dark = false, _renamed = false, _enabled = true;
  int _navigationCalls = 0, _colorCalls = 0;
  Color _color = const Color(0xff808080);
  String _activation = 'none';

  String get _colorLabel => _renamed ? 'Accent color' : 'Sample color';

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(brightness: _dark ? Brightness.dark : Brightness.light),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: LiquidGlassNavigationBar(
          title: 'Accessibility probe',
          leading: [
            LiquidGlassAction(
              id: 'back',
              label: 'Back to catalog',
              sfSymbol: 'chevron.left',
              onPressed: () => Navigator.pop(context),
            ),
          ],
          actions: [
            LiquidGlassAction(
              id: 'theme',
              label: _renamed ? 'Switch appearance' : 'Toggle theme',
              sfSymbol: 'circle.lefthalf.filled',
              onPressed: () => setState(() {
                _navigationCalls++;
                _dark = !_dark;
              }),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Accessibility renderer: ${LiquidGlassTheme.modeOf(context).name}',
            ),
            Text('Navigation calls: $_navigationCalls'),
            Text('Appearance: ${_dark ? 'dark' : 'light'}'),
            Text('Color calls: $_colorCalls'),
            Text('Color value: ${_color.toARGB32().toRadixString(16)}'),
            Text('Accessibility activation: $_activation'),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassColorPicker(
                title: 'Sample palette',
                semanticLabel: _colorLabel,
                selectedColor: _color,
                supportsAlpha: false,
                onChanged: !_enabled
                    ? null
                    : (value) => setState(() {
                        _color = value;
                        _colorCalls++;
                      }),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() => _renamed = !_renamed),
              child: const Text('Rename controls'),
            ),
            TextButton(
              onPressed: () => setState(() => _enabled = !_enabled),
              child: Text(_enabled ? 'Disable color' : 'Enable color'),
            ),
            TextButton(
              onPressed: () => setState(() => _color = const Color(0xffff0000)),
              child: const Text('Set red programmatically'),
            ),
            TextButton(
              onPressed:
                  LiquidGlassTheme.modeOf(context) != LiquidGlassMode.native
                  ? null
                  : () async {
                      // The example-only host driver invokes UIKit's public
                      // accessibility action, separately from XCTest's physical tap.
                      final activated = await const MethodChannel(
                        'glass_example/accessibility',
                      ).invokeMethod<bool>('activateColor', _colorLabel);
                      if (mounted) {
                        setState(() => _activation = activated.toString());
                      }
                    },
              child: const Text('Activate color accessibility'),
            ),
          ],
        ),
      ),
    ),
  );
}
