import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

class NativeButtonGlassProbePage extends StatefulWidget {
  const NativeButtonGlassProbePage({super.key});

  @override
  State<NativeButtonGlassProbePage> createState() =>
      _NativeButtonGlassProbePageState();
}

class _NativeButtonGlassProbePageState
    extends State<NativeButtonGlassProbePage> {
  static const _channel = MethodChannel('glass_example/button_probe');
  var _presses = 0;
  var _group = 'none';
  var _menu = 'not attached';

  void _press() => setState(() => _presses++);

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'selected' && mounted) {
        setState(() => _menu = call.arguments as String);
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _attachMenus() async {
    try {
      await _channel.invokeMethod<void>('attachMenus');
      if (mounted) setState(() => _menu = 'attached');
    } on PlatformException catch (error) {
      if (mounted) setState(() => _menu = error.message ?? error.code);
    } on MissingPluginException {
      if (mounted) setState(() => _menu = 'UIKit unavailable');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Glass button probe')),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffd5e7f2), Color(0xfff2e0c1)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              LiquidGlassButton(
                id: 'glass-probe-regular',
                label: 'Regular',
                onPressed: _press,
              ),
              LiquidGlassButton.icon(
                id: 'glass-probe-prominent',
                icon: Icons.star,
                sfSymbol: 'star',
                semanticLabel: 'Prominent',
                prominent: true,
                onPressed: _press,
              ),
              LiquidGlassButton(
                id: 'glass-probe-loading',
                label: 'Loading',
                loading: true,
                onPressed: _press,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: LiquidGlassButton(
                id: 'glass-probe-large',
                label: 'Large text',
                onPressed: _press,
              ),
            ),
          ),
          Text('Button presses: $_presses'),
          TextButton(
            onPressed: _attachMenus,
            child: const Text('Attach UIKit menus'),
          ),
          Text('UIKit menu: $_menu'),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidGlassButtonGroup(
              actions: [
                LiquidGlassAction(
                  id: 'glass-probe-group-cut',
                  label: 'Cut',
                  onPressed: () => setState(() => _group = 'cut'),
                ),
                LiquidGlassAction(
                  id: 'glass-probe-group-paste',
                  label: 'Paste',
                  onPressed: () => setState(() => _group = 'paste'),
                ),
              ],
            ),
          ),
          Text('Group choice: $_group'),
        ],
      ),
    ),
  );
}
