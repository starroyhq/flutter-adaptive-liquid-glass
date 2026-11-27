import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

/// Reproduces a near-white primary in dark mode and a dark primary in light
/// mode, using actual package buttons for each interaction state.
class ProminentButtonContrastProbe extends StatefulWidget {
  const ProminentButtonContrastProbe({super.key});

  @override
  State<ProminentButtonContrastProbe> createState() =>
      _ProminentButtonContrastProbeState();
}

class _ProminentButtonContrastProbeState
    extends State<ProminentButtonContrastProbe> {
  static const _channel = MethodChannel('glass_example/button_probe');
  bool _lightFill = true;
  bool _highlighted = false;
  int _presses = 0;

  void _press() => setState(() => _presses++);

  Future<void> _highlight() async {
    try {
      final highlighted = await _channel.invokeMethod<bool>(
        'highlightContrastSample',
      );
      if (mounted) setState(() => _highlighted = highlighted == true);
    } on MissingPluginException {
      // Only the native example can drive UIKit's highlighted state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _lightFill
        ? const ColorScheme.dark(
            primary: Color(0xfff5f5f7),
            onPrimary: Color(0xff19191c),
            surface: Color(0xff191a20),
          )
        : const ColorScheme.light(
            primary: Color(0xff26376a),
            onPrimary: Colors.white,
            surface: Color(0xfff6f7fb),
          );
    return Theme(
      data: ThemeData(colorScheme: scheme),
      child: LiquidGlassTheme(
        data: const LiquidGlassThemeData(),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Prominent button contrast')),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _lightFill
                        ? 'Light fill #F5F5F7 · Dark theme'
                        : 'Dark fill #26376A · Light theme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Contrast renderer: ${LiquidGlassTheme.modeOf(context).name}',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      LiquidGlassButton(
                        id: 'contrast-title',
                        label: 'Continue',
                        prominent: true,
                        onPressed: _press,
                      ),
                      LiquidGlassButton.icon(
                        id: 'contrast-symbol',
                        icon: Icons.arrow_upward,
                        sfSymbol: 'arrow.up',
                        semanticLabel: 'Send',
                        prominent: true,
                        onPressed: _press,
                      ),
                      LiquidGlassButton.icon(
                        id: 'contrast-bitmap',
                        icon: Icons.file_download,
                        semanticLabel: 'Download',
                        prominent: true,
                        onPressed: _press,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      LiquidGlassButton(
                        id: 'contrast-highlighted',
                        label: 'Pressed',
                        prominent: true,
                        onPressed: _press,
                      ),
                      LiquidGlassButton.icon(
                        id: 'contrast-loading',
                        icon: Icons.refresh,
                        semanticLabel: 'Loading',
                        prominent: true,
                        loading: true,
                        onPressed: _press,
                      ),
                      const LiquidGlassButton(
                        id: 'contrast-disabled',
                        label: 'Disabled',
                        prominent: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: LiquidGlassButton(
                      id: 'contrast-custom',
                      label: 'Custom foreground',
                      icon: Icons.star,
                      sfSymbol: 'star.fill',
                      prominent: true,
                      foregroundColor: _lightFill
                          ? const Color(0xff126046)
                          : const Color(0xffffd991),
                      onPressed: _press,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Button presses: $_presses'),
                  Text(
                    _highlighted
                        ? 'Press state: highlighted'
                        : 'Press state: normal',
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: liquidGlassNativeAvailable ? _highlight : null,
                      child: const Text('Highlight sample'),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _lightFill = !_lightFill;
                        _highlighted = false;
                      }),
                      child: const Text('Switch background'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
