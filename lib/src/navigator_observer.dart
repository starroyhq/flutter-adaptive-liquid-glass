import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'native_visibility.dart';

/// Hides the package's native views beneath popups, counting nested popups
/// so that only the first and the last reach the platform.
///
/// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
abstract final class _NativeGlassLifecycle {
  static const _channel = MethodChannel(
    'flutter_adaptive_liquid_glass/lifecycle',
  );
  static int _count = 0;

  static Future<void> suppress() async {
    _count++;
    if (_count == 1) await _channel.invokeMethod<void>('suppressGlassEffects');
  }

  static Future<void> unsuppress() async {
    _count--;
    if (_count <= 0) {
      _count = 0;
      await _channel.invokeMethod<void>('unsuppressGlassEffects');
    }
  }
}

/// Add a distinct instance to each Navigator that presents dialogs or sheets.
///
/// Native views under popup routes must not float above a Flutter overlay.
/// Calls are platform gated, balanced per route, and sequenced across observers.
///
/// Other popups isolate the routes below them: their native views leave
/// composition and controls paint their Flutter rendering instead until the
/// popup has fully exited. The package's alerts, sheets and popovers keep the
/// native views below them, under their barrier, except while a text field,
/// selectable text or selection area in them has focus, or while a
/// `LiquidGlassOverlayGuard` is mounted.
class LiquidGlassNavigatorObserver extends NavigatorObserver {
  LiquidGlassNavigatorObserver()
    : _nativeAvailable = (() => liquidGlassNativeAvailable);

  /// Allows lifecycle tests to exercise the native channel on any test host.
  @visibleForTesting
  LiquidGlassNavigatorObserver.debug({required bool nativeAvailable})
    : _nativeAvailable = (() => nativeAvailable);

  final bool Function() _nativeAvailable;
  final Map<Route<dynamic>, Object> _popups = {};
  final Map<Route<dynamic>, VoidCallback> _keepers = {};
  final List<Route<dynamic>> _routes = [];
  final Object _keptToken = Object();
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
    _enqueue(false);
  }

  /// Whether [route] currently keeps the native views below it.
  bool _keeps(Route<dynamic> route) =>
      _keepers.containsKey(route) &&
      (route as NativeKeepingPopup).keepsNativeBelow.value;

  /// Starts following a popup that can keep the native views below it, and
  /// isolates or keeps them as it asks.
  void _track(Route<dynamic>? route) {
    if (_disposed || route == null) return;
    if (route is NativeKeepingPopup && !_keepers.containsKey(route)) {
      void changed() => _apply(route);
      _keepers[route] = changed;
      (route as NativeKeepingPopup).keepsNativeBelow.addListener(changed);
    }
    _apply(route);
  }

  /// Stops following [route]: once it is popped or removed, it keeps the mode
  /// it had for the rest of its exit.
  void _untrack(Route<dynamic>? route) {
    final changed = _keepers.remove(route);
    if (changed != null) {
      (route as NativeKeepingPopup).keepsNativeBelow.removeListener(changed);
    }
  }

  void _apply(Route<dynamic> route) {
    if (_disposed) return;
    if (_keeps(route)) {
      _release(route);
    } else {
      _retain(route);
    }
    _publishKept();
  }

  /// Routes that are not current only because every route above them in their
  /// navigator is a popup that keeps the native views below it.
  ///
  /// Routers such as go_router also report a nested navigator's routes to the
  /// observers of the root navigator, so the routes seen here are grouped by
  /// navigator before each stack is walked from its top.
  void _publishKept() {
    final kept = <Route<dynamic>>{};
    if (!_disposed && _nativeAvailable()) {
      final stacks = <NavigatorState?, List<Route<dynamic>>>{};
      for (final route in _routes) {
        (stacks[route.navigator] ??= []).add(route);
      }
      for (final stack in stacks.values) {
        for (var index = stack.length - 1; index > 0; index--) {
          if (!_keeps(stack[index])) break;
          kept.add(stack[index - 1]);
        }
      }
    }
    nativeRouteCoverage.keep(_keptToken, kept);
  }

  void _enqueue(bool add) {
    final pending = (_pending ?? Future<void>.value()).then((_) async {
      try {
        if (add) {
          await _NativeGlassLifecycle.suppress();
        } else {
          await _NativeGlassLifecycle.unsuppress();
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
    _track(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _untrack(route);
    final token = _popups[route];
    if (token == null) {
      _routes.remove(route);
      _publishKept();
      return;
    }
    if (route is TransitionRoute) {
      // `popped` resolves when Navigator.pop is called. Native views must stay
      // hidden until the exit animation and overlay removal finish instead.
      unawaited(route.completed.then((_) => _finish(route, token)));
    } else {
      _finish(route, token);
    }
  }

  void _finish(Route<dynamic> route, Object token) {
    if (!identical(_popups[route], token)) return;
    _release(route, token: token);
    _routes.remove(route);
    _publishKept();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _untrack(route);
    _release(route);
    _routes.remove(route);
    _publishKept();
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
    _untrack(oldRoute);
    _track(newRoute);
    _release(oldRoute);
    _routes.remove(oldRoute);
    _publishKept();
  }

  /// Balance active overlays when an application discards this navigator.
  void dispose() {
    if (_disposed) return;
    for (final route in _keepers.keys.toList()) {
      _untrack(route);
    }
    _disposed = true;
    for (final route in _popups.keys.toList()) {
      _release(route);
    }
    _routes.clear();
    nativeRouteCoverage.keep(_keptToken, const {});
  }
}
