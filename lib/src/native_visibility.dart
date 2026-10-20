import 'package:flutter/material.dart';

/// Route coverage is separate from UIKit alpha: a transparent platform view can
/// still reserve a composition slice and clip Flutter content in the overlay.
final nativeRouteCoverage = NativeRouteCoverage();

/// Internal, shared across navigator observers so nested navigators can inspect
/// coverage of both their own route and the route containing their navigator.
class NativeRouteCoverage extends ChangeNotifier {
  final Map<Object, Set<Route<dynamic>>> _covered = {};

  bool covers(Route<dynamic> route) =>
      _covered.values.any((routes) => routes.contains(route));

  void retain(Object token, Iterable<Route<dynamic>> routes) {
    _covered[token] = routes.toSet();
    notifyListeners();
  }

  void release(Object token) {
    if (_covered.remove(token) != null) notifyListeners();
  }

  void replace(Route<dynamic> oldRoute, Route<dynamic> newRoute) {
    var changed = false;
    for (final routes in _covered.values) {
      if (routes.remove(oldRoute)) {
        routes.add(newRoute);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}

/// The routes around [context], innermost first, through enclosing navigators.
List<Route<dynamic>> nativeRouteChain(BuildContext context) {
  Route<dynamic>? route = ModalRoute.of(context);
  final routes = <Route<dynamic>>{};
  while (route != null && routes.add(route)) {
    final navigator = route.navigator;
    route = navigator == null ? null : ModalRoute.of(navigator.context);
  }
  return routes.toList();
}

/// Whether a native view at [context] must hide: an active route around it is
/// not current, or a popup still covers it. [popupOwner] marks a view inside a
/// popup, which the global suppression for that popup must not hide.
({bool suppressed, bool popupOwner}) nativeRouteState(BuildContext context) {
  final routes = nativeRouteChain(context);
  return (
    suppressed: routes.any(
      (route) =>
          (route.isActive && !route.isCurrent) ||
          nativeRouteCoverage.covers(route),
    ),
    popupOwner: routes.any((route) => route is PopupRoute),
  );
}

/// Keeps a covered native subtree laid out and alive, but excludes it from
/// painting, hit testing and accessibility until its overlay has fully exited.
class NativeVisibility extends StatelessWidget {
  const NativeVisibility({super.key, required this.child, this.replacement});

  final Widget child;

  /// Painted in place of [child] while it is covered, such as an opaque
  /// material under a sheet's content while an alert is above it.
  final Widget? replacement;

  bool _isVisible(BuildContext context) {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      // A popped route is no longer current, but its native content must remain
      // visible during its own reverse transition. Active non-current routes
      // are covered; observer coverage also protects the newly-current route
      // underneath until that reverse transition has finished.
      if ((!route.isCurrent && route.isActive) ||
          nativeRouteCoverage.covers(route)) {
        return false;
      }
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: nativeRouteCoverage,
    child: child,
    builder: (context, child) {
      final visible = _isVisible(context);
      final kept = Visibility(
        visible: visible,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: child!,
      );
      if (replacement == null) return kept;
      return Stack(
        fit: StackFit.passthrough,
        children: [
          if (!visible) Positioned.fill(child: replacement!),
          kept,
        ],
      );
    },
  );
}
