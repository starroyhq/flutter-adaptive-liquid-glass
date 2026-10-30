import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Route coverage is separate from UIKit alpha: a transparent platform view can
/// still reserve a composition slice and clip Flutter content in the overlay.
final nativeRouteCoverage = NativeRouteCoverage();

/// Internal, shared across navigator observers so nested navigators can inspect
/// coverage of both their own route and the route containing their navigator.
///
/// A covered route is isolated: a popup above it requires its native views to
/// leave composition. A kept route is not current only because the routes
/// above it in its navigator are all popups that keep the native views below
/// them, so its native views stay.
class NativeRouteCoverage extends ChangeNotifier {
  final Map<Object, Set<Route<dynamic>>> _covered = {};
  final Map<Object, Set<Route<dynamic>>> _kept = {};

  bool covers(Route<dynamic> route) =>
      _covered.values.any((routes) => routes.contains(route));

  bool keeps(Route<dynamic> route) =>
      _kept.values.any((routes) => routes.contains(route));

  /// Whether any route currently keeps its native views under a popup.
  bool get keepsAny => _kept.isNotEmpty;

  void retain(Object token, Iterable<Route<dynamic>> routes) {
    _covered[token] = routes.toSet();
    notifyListeners();
  }

  void release(Object token) {
    if (_covered.remove(token) != null) notifyListeners();
  }

  /// Publishes the routes that [token]'s navigator keeps; empty clears them.
  void keep(Object token, Set<Route<dynamic>> routes) {
    if (setEquals(_kept[token] ?? const {}, routes)) return;
    if (routes.isEmpty) {
      _kept.remove(token);
    } else {
      _kept[token] = routes;
    }
    notifyListeners();
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

/// Whether the native views of [route] must leave composition: a popup that
/// isolates the routes below it covers [route], or [route] is active but not
/// current and not kept. Without an observer nothing is kept, so a route that
/// is not current always hides. A popped route is no longer active, so its
/// native content stays through its own reverse transition.
bool nativeRouteHidden(Route<dynamic> route) =>
    nativeRouteCoverage.covers(route) ||
    (route.isActive && !route.isCurrent && !nativeRouteCoverage.keeps(route));

/// A popup that can leave the native views of the routes below it in
/// composition. The package's own popups implement it; the observer follows
/// [keepsNativeBelow] and isolates the routes below whenever it is false.
abstract interface class NativeKeepingPopup {
  ValueListenable<bool> get keepsNativeBelow;
}

/// The number of mounted `LiquidGlassOverlayGuard`s. While it is above zero,
/// every [NativeKeepingPopup] isolates the routes below it.
final nativeOverlayGuards = ValueNotifier<int>(0);

/// Whether [node] is the focus of a text field, selectable text or selection
/// area, which may paint a selection toolbar, handles or a magnifier outside
/// the popup that contains it.
bool nativeSelectionFocus(FocusNode node) {
  final context = node.context;
  if (context == null || !context.mounted) return false;
  if (context.findAncestorStateOfType<EditableTextState>()?.widget.focusNode ==
      node) {
    return true;
  }
  // A selection area's own focus sits a few widgets below it, with no other
  // focus in between; a focused control inside the area has its own.
  var found = false;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is SelectableRegion) {
      found = true;
      return false;
    }
    return widget is! Focus;
  });
  return found;
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

/// Whether a native view at [context] must hide (see [nativeRouteHidden]).
/// [popupOwner] marks a view inside a popup, which the global suppression for
/// that popup must not hide.
({bool suppressed, bool popupOwner}) nativeRouteState(BuildContext context) {
  final routes = nativeRouteChain(context);
  return (
    suppressed: routes.any(nativeRouteHidden),
    popupOwner: routes.any((route) => route is PopupRoute),
  );
}

/// How long a stand-in stays under a native view that returns to composition,
/// until UIKit has made the view opaque again after the channel round trip.
const nativeFadeInCover = Duration(milliseconds: 350);

/// Builds its content while [shown], and for [nativeFadeInCover] after.
class _StandIn extends StatefulWidget {
  const _StandIn({required this.shown, required this.builder});

  final bool shown;
  final WidgetBuilder builder;

  @override
  State<_StandIn> createState() => _StandInState();
}

class _StandInState extends State<_StandIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: nativeFadeInCover)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) setState(() {});
        });

  @override
  void didUpdateWidget(_StandIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown) {
      _hold.reset();
    } else if (oldWidget.shown) {
      _hold.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.shown || _hold.isAnimating
      ? widget.builder(context)
      : const SizedBox.shrink();
}

/// Paints the control's Flutter rendering in the layout box of [child] while a
/// popup that isolates the routes below it covers [child]'s route, so the page
/// keeps the control in view instead of an empty gap. [child]'s native views
/// leave composition in the same frame through [NativeVisibility], and return
/// once the popup has fully exited, with the stand-in under them until UIKit
/// has shown them again.
///
/// [fallback] runs under a fallback [LiquidGlassTheme], so passing the public
/// widget itself builds its Flutter branch. The stand-in ignores input and
/// accessibility; the popup's barrier blocks both anyway. A control whose own
/// key is a [GlobalKey] gets no stand-in, as one key cannot be mounted twice.
class NativeCoverFallback extends StatelessWidget {
  const NativeCoverFallback({
    super.key,
    required this.fallback,
    required this.child,
    this.alignment = Alignment.center,
  });

  final WidgetBuilder fallback;
  final Widget child;

  /// Where the Flutter rendering sits when its height differs from [child]'s.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: nativeRouteCoverage,
    child: child,
    builder: (context, child) {
      final covered = nativeRouteChain(context).any(nativeRouteCoverage.covers);
      // The stand-in paints under the native child, so that it shows through
      // until UIKit has shown the returning view again.
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: _StandIn(
              shown: covered,
              builder: (context) => IgnorePointer(
                child: ExcludeSemantics(
                  // The Flutter rendering keeps the native width but its own
                  // height, which can exceed the native box (the fallback tab
                  // bar is taller than the native one).
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: MediaQuery.sizeOf(context).height,
                    alignment: alignment,
                    child: LiquidGlassTheme(
                      data: LiquidGlassTheme.of(
                        context,
                      ).copyWith(mode: LiquidGlassMode.fallback),
                      child: Builder(
                        builder: (context) {
                          final stand = fallback(context);
                          return stand.key is GlobalKey
                              ? const SizedBox.shrink()
                              : stand;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child!,
        ],
      );
    },
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

  bool _isVisible(BuildContext context) =>
      !nativeRouteChain(context).any(nativeRouteHidden);

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
          Positioned.fill(
            child: _StandIn(shown: !visible, builder: (_) => replacement!),
          ),
          kept,
        ],
      );
    },
  );
}
