import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'theme.dart';
import 'native_visibility.dart';

/// Add a distinct instance to each Navigator that presents dialogs or sheets.
///
/// Native views under popup routes must not float above a Flutter overlay.
/// Calls are platform gated, balanced per route, and sequenced across observers.
class LiquidGlassNavigatorObserver extends NavigatorObserver {
  LiquidGlassNavigatorObserver()
    : _nativeAvailable = (() => liquidGlassNativeAvailable);

  /// Allows lifecycle tests to exercise the native channel on any test host.
  @visibleForTesting
  LiquidGlassNavigatorObserver.debug({required bool nativeAvailable})
    : _nativeAvailable = (() => nativeAvailable);

  final bool Function() _nativeAvailable;
  final Map<Route<dynamic>, Object> _popups = {};
  final List<Route<dynamic>> _routes = [];
  bool _disposed = false;
  static Future<void>? _pending;

  void _retain(Route<dynamic>? route) {
    if (_disposed ||
        route is! PopupRoute ||
        _popups.containsKey(route) ||
        !_nativeAvailable()) {
      return;
    }
    final token = Object();
    _popups[route] = token;
    nativeRouteCoverage.retain(
      token,
      _routes.takeWhile((candidate) => !identical(candidate, route)),
    );
    _enqueue(true);
  }

  void _release(Route<dynamic>? route, {Object? token}) {
    if (!_popups.containsKey(route) ||
        (token != null && !identical(_popups[route], token))) {
      return;
    }
    nativeRouteCoverage.release(_popups.remove(route)!);
    _routes.remove(route);
    _enqueue(false);
  }

  void _enqueue(bool add) {
    final pending = (_pending ?? Future<void>.value()).then((_) async {
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
    _pending = pending;
    unawaited(
      pending.whenComplete(() {
        if (identical(_pending, pending)) _pending = null;
      }),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) return;
    if (previousRoute != null && !_routes.contains(previousRoute)) {
      _routes.add(previousRoute);
    }
    if (!_routes.contains(route)) _routes.add(route);
    _retain(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final token = _popups[route];
    if (token == null) {
      _routes.remove(route);
      return;
    }
    if (route is TransitionRoute) {
      // `popped` resolves when Navigator.pop is called. Native views must stay
      // hidden until the exit animation and overlay removal finish instead.
      unawaited(route.completed.then((_) => _release(route, token: token)));
    } else {
      _release(route, token: token);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _release(route);
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_disposed || identical(newRoute, oldRoute)) return;
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null && !_routes.contains(newRoute)) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
    }
    if (oldRoute != null && newRoute != null) {
      nativeRouteCoverage.replace(oldRoute, newRoute);
    }
    // Retain first so popup-to-popup replacement cannot briefly restore the
    // covered platform views between two serialized channel calls.
    _retain(newRoute);
    _release(oldRoute);
    _routes.remove(oldRoute);
  }

  /// Balance active overlays when an application discards this navigator.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final route in _popups.keys.toList()) {
      _release(route);
    }
    _routes.clear();
  }
}
