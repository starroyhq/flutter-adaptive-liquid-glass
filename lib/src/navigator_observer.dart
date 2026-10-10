import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'theme.dart';

/// Add a distinct instance to each Navigator that presents dialogs or sheets.
///
/// Native views under popup routes must not float above a Flutter overlay.
/// Calls are platform gated, balanced per route, and sequenced across observers.
class LiquidGlassNavigatorObserver extends NavigatorObserver {
  final Set<Route<dynamic>> _popups = {};
  static Future<void> _pending = Future<void>.value();

  void _change(Route<dynamic>? route, bool add) {
    if (route is! PopupRoute || !liquidGlassNativeAvailable) return;
    final changed = add ? _popups.add(route) : _popups.remove(route);
    if (!changed) return;
    _pending = _pending.then((_) async {
      try {
        if (add) {
          await native.NativeLiquidGlassLifecycle.suppressGlassEffects();
        } else {
          await native.NativeLiquidGlassLifecycle.unsuppressGlassEffects();
        }
      } on MissingPluginException {
        // Rendering still works through Flutter when an embedder omits iOS plugins.
      } on PlatformException catch (error) {
        debugPrint(
          'flutter_adaptive_liquid_glass overlay presentation unavailable: ${error.code}',
        );
      }
    });
    unawaited(_pending);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, true);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, false);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, false);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _change(oldRoute, false);
    _change(newRoute, true);
  }

  /// Balance active overlays when an application discards this navigator.
  void dispose() {
    for (final route in _popups.toList()) {
      _change(route, false);
    }
  }
}
