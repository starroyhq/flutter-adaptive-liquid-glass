import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Install once at the app root with the same mode as MaterialApp.themeMode.
///
/// Native platform views otherwise inherit the device appearance even when
/// Flutter uses a manually selected theme. Passing [ThemeMode.system] removes
/// the UIKit override; using resolved brightness here would create a feedback
/// loop and prevent the app from following subsequent system changes.
class LiquidGlassAppearance extends StatefulWidget {
  const LiquidGlassAppearance({
    super.key,
    required this.mode,
    required this.child,
  });
  final ThemeMode mode;
  final Widget child;

  @override
  State<LiquidGlassAppearance> createState() => _LiquidGlassAppearanceState();
}

class _LiquidGlassAppearanceState extends State<LiquidGlassAppearance> {
  static const _channel = MethodChannel(
    'flutter_adaptive_liquid_glass/appearance',
  );
  static Future<void> _writes = Future<void>.value();

  void _synchronize() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final mode = widget.mode.name;
    _writes = _writes.then((_) async {
      try {
        await _channel.invokeMethod<void>('setAppearance', mode);
      } on MissingPluginException {
        // The Dart-only test/embedder path has no UIKit window to synchronize.
      } on PlatformException catch (error) {
        debugPrint(
          'flutter_adaptive_liquid_glass appearance unavailable: ${error.code}',
        );
      }
    });
    unawaited(_writes);
  }

  @override
  void initState() {
    super.initState();
    _synchronize();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassAppearance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _synchronize();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
