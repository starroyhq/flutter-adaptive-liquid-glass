import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'surface.dart';
import 'theme.dart';

/// A centered alert or an action sheet presented near the bottom safe area.
enum LiquidGlassAlertStyle { alert, actionSheet }

/// The initial and resting heights of a glass sheet.
enum LiquidGlassSheetDetent {
  medium(.5),
  large(.92);

  const LiquidGlassSheetDetent(this.fraction);
  final double fraction;
}

/// A typed alert action. Cancel actions always complete the result with null.
@immutable
class LiquidGlassAlertAction<T> {
  const LiquidGlassAlertAction({
    required this.label,
    required this.value,
    this.enabled = true,
    this.destructive = false,
    this.cancel = false,
    this.icon,
  });

  final String label;
  final T value;
  final bool enabled;
  final bool destructive;
  final bool cancel;
  final IconData? icon;
}

/// Shows a glass alert using Flutter navigation, focus and text rendering.
///
/// Attach a LiquidGlassNavigatorObserver to the selected Navigator when native
/// glass is in use. Like a dialog, local inherited themes are captured on open.
/// Barrier, back, escape and cancel actions return null. Programmatic
/// `Navigator.pop<T>(context, result)` has the usual Navigator behavior.
Future<T?> showLiquidGlassAlert<T>({
  required BuildContext context,
  required List<LiquidGlassAlertAction<T>> actions,
  Widget? title,
  Widget? content,
  LiquidGlassAlertStyle style = LiquidGlassAlertStyle.alert,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? semanticLabel,
}) {
  if (actions.isEmpty) {
    throw ArgumentError.value(actions, 'actions', 'Must not be empty.');
  }
  final stableActions = List<LiquidGlassAlertAction<T>>.unmodifiable(actions);
  return _showPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    settings: routeSettings,
    slide: style == LiquidGlassAlertStyle.actionSheet,
    builder: (context) => _Alert<T>(
      title: title,
      content: content,
      actions: stableActions,
      style: style,
      semanticLabel: semanticLabel,
    ),
  );
}

/// Shows arbitrary Flutter content in a sheet with medium and large detents.
///
/// The builder receives a [PrimaryScrollController]. Set `primary: true` on a
/// single scroll view (or use `PrimaryScrollController.of(context)`) to hand
/// scrolling to the sheet until its largest detent is reached. Non-scrollable
/// content can still resize and dismiss the sheet using the drag handle.
/// Keyboard space and system safe areas are removed from the available height.
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  List<LiquidGlassSheetDetent> detents = const [
    LiquidGlassSheetDetent.medium,
    LiquidGlassSheetDetent.large,
  ],
  LiquidGlassSheetDetent initialDetent = LiquidGlassSheetDetent.medium,
  bool barrierDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  RouteSettings? routeSettings,
  String? semanticLabel,
}) {
  if (detents.isEmpty || !detents.contains(initialDetent)) {
    throw ArgumentError('detents must contain the initialDetent.');
  }
  final heights = detents.map((value) => value.fraction).toSet().toList()
    ..sort();
  return _showPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    settings: routeSettings,
    slide: true,
    builder: (context) => _Sheet(
      builder: builder,
      heights: heights,
      initial: initialDetent.fraction,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      semanticLabel: semanticLabel,
    ),
  );
}

/// Shows content anchored to a mounted widget, following its layout and scroll.
///
/// The popover prefers the space below its anchor, flips above when necessary,
/// and clamps within the keyboard and safe-area bounds. Removing the anchor
/// dismisses only this route, including when another popup is above it.
Future<T?> showLiquidGlassPopover<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
  double width = 320,
  double maxHeight = 480,
  double gap = 8,
  RouteSettings? routeSettings,
  String? semanticLabel,
}) {
  if (!width.isFinite ||
      width <= 0 ||
      !maxHeight.isFinite ||
      maxHeight <= 0 ||
      !gap.isFinite ||
      gap < 0) {
    throw ArgumentError('Popover dimensions must be finite and positive.');
  }
  if (!anchorContext.mounted) return Future<T?>.value();
  return _showPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    settings: routeSettings,
    barrierOpacity: .08,
    builder: (context) => _Popover(
      anchorContext: anchorContext,
      builder: builder,
      width: width,
      maxHeight: maxHeight,
      gap: gap,
      semanticLabel: semanticLabel,
    ),
  );
}

Future<T?> _showPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool useRootNavigator,
  required bool barrierDismissible,
  required RouteSettings? settings,
  bool slide = false,
  double barrierOpacity = .2,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localGlass = LiquidGlassTheme.of(context);
  return navigator.push<T>(
    _GlassPopupRoute<T>(
      builder: builder,
      dismissible: barrierDismissible,
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      // Global themes remain live. A locally scoped theme is captured, matching
      // Flutter's dialog behavior for a theme below the selected Navigator.
      localGlass: localGlass == LiquidGlassTheme.of(navigator.context)
          ? null
          : localGlass,
      reduceMotion:
          localGlass.reduceMotion || MediaQuery.disableAnimationsOf(context),
      slide: slide,
      barrierOpacity: barrierOpacity,
      settings: settings,
    ),
  );
}

class _GlassPopupRoute<T> extends PopupRoute<T> {
  _GlassPopupRoute({
    required this.builder,
    required this.dismissible,
    required this.label,
    required this.themes,
    required this.localGlass,
    required this.reduceMotion,
    required this.slide,
    required this.barrierOpacity,
    super.settings,
  }) : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final WidgetBuilder builder;
  final bool dismissible;
  final String label;
  final CapturedThemes themes;
  final LiquidGlassThemeData? localGlass;
  final bool reduceMotion;
  final bool slide;
  final double barrierOpacity;

  @override
  Color get barrierColor => Colors.black.withValues(alpha: barrierOpacity);
  @override
  bool get barrierDismissible => dismissible;
  @override
  String get barrierLabel => label;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    Widget result = Builder(builder: builder);
    if (localGlass != null) {
      result = LiquidGlassTheme(data: localGlass!, child: result);
    }
    return themes.wrap(result);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion ||
        LiquidGlassTheme.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: slide
          ? SlideTransition(
              position: Tween(
                begin: const Offset(0, .1),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            )
          : ScaleTransition(
              scale: Tween(begin: .96, end: 1.0).animate(curve),
              child: child,
            ),
    );
  }
}

class _Alert<T> extends StatefulWidget {
  const _Alert({
    required this.title,
    required this.content,
    required this.actions,
    required this.style,
    required this.semanticLabel,
  });

  final Widget? title;
  final Widget? content;
  final List<LiquidGlassAlertAction<T>> actions;
  final LiquidGlassAlertStyle style;
  final String? semanticLabel;

  @override
  State<_Alert<T>> createState() => _AlertState<T>();
}

class _AlertState<T> extends State<_Alert<T>> {
  bool _submitted = false;

  void _select(LiquidGlassAlertAction<T> action) {
    if (_submitted || !action.enabled || !ModalRoute.of(context)!.isCurrent) {
      return;
    }
    _submitted = true;
    Navigator.of(context).pop<T>(action.cancel ? null : action.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isSheet = widget.style == LiquidGlassAlertStyle.actionSheet;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Align(
          alignment: isSheet ? Alignment.bottomCenter : Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isSheet ? 480 : 360),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              label:
                  widget.semanticLabel ??
                  MaterialLocalizations.of(context).alertDialogLabel,
              explicitChildNodes: true,
              child: LiquidGlassSurface(
                radius: 28,
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.title != null || widget.content != null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.title != null)
                                  DefaultTextStyle.merge(
                                    style: theme.textTheme.titleLarge,
                                    textAlign: TextAlign.center,
                                    child: widget.title!,
                                  ),
                                if (widget.title != null &&
                                    widget.content != null)
                                  const SizedBox(height: 12),
                                if (widget.content != null) widget.content!,
                              ],
                            ),
                          ),
                        for (final action in widget.actions) ...[
                          const Divider(height: 1),
                          TextButton(
                            onPressed: action.enabled
                                ? () => _select(action)
                                : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 52),
                              foregroundColor: action.destructive
                                  ? theme.colorScheme.error
                                  : LiquidGlassTheme.of(
                                          context,
                                        ).colors.accent ??
                                        theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: const RoundedRectangleBorder(),
                              textStyle: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: action.cancel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (action.icon != null) ...[
                                  Icon(action.icon),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    action.label,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.builder,
    required this.heights,
    required this.initial,
    required this.enableDrag,
    required this.showDragHandle,
    required this.semanticLabel,
  });

  final WidgetBuilder builder;
  final List<double> heights;
  final double initial;
  final bool enableDrag;
  final bool showDragHandle;
  final String? semanticLabel;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> with SingleTickerProviderStateMixin {
  final _controller = DraggableScrollableController();
  bool _closing = false;
  double _availableHeight = 1;
  late double _manualSize = widget.initial;
  late final AnimationController _manualAnimation;

  @override
  void initState() {
    super.initState();
    _manualAnimation = AnimationController.unbounded(
      vsync: this,
      value: widget.initial,
    )..addListener(() => setState(() => _manualSize = _manualAnimation.value));
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualAnimation.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_closing || !mounted || !ModalRoute.of(context)!.isCurrent) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _settle(DragEndDetails details) {
    if (_closing) return;
    final size = _controller.isAttached ? _controller.size : _manualSize;
    if (size < widget.heights.first * .75 ||
        (details.primaryVelocity ?? 0) > 900 && size <= widget.heights.first) {
      _dismiss();
      return;
    }
    final target = widget.heights.reduce(
      (a, b) => (a - size).abs() < (b - size).abs() ? a : b,
    );
    if (!_controller.isAttached) {
      if (LiquidGlassTheme.of(context).reduceMotion ||
          MediaQuery.disableAnimationsOf(context)) {
        _manualAnimation.value = target;
      } else {
        _manualAnimation.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (LiquidGlassTheme.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final min = widget.enableDrag ? .15 : widget.initial;
    final max = widget.enableDrag ? widget.heights.last : widget.initial;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _availableHeight = constraints.maxHeight;
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    if (widget.enableDrag &&
                        notification.depth == 0 &&
                        notification.extent <= min + .005) {
                      _dismiss();
                    }
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    controller: _controller,
                    initialChildSize: _manualSize,
                    minChildSize: min,
                    maxChildSize: max,
                    expand: false,
                    snap: widget.enableDrag,
                    snapSizes: widget.enableDrag ? widget.heights : null,
                    builder: (context, scrollController) => Semantics(
                      scopesRoute: true,
                      namesRoute: true,
                      label:
                          widget.semanticLabel ??
                          MaterialLocalizations.of(context).dialogLabel,
                      explicitChildNodes: true,
                      child: LiquidGlassSurface(
                        radius: 28,
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              if (widget.showDragHandle)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onVerticalDragUpdate: widget.enableDrag
                                      ? (details) {
                                          if (_closing) {
                                            return;
                                          }
                                          final size = _controller.isAttached
                                              ? _controller.size
                                              : _manualSize;
                                          final next =
                                              (size -
                                                      details.delta.dy /
                                                          _availableHeight)
                                                  .clamp(min, max);
                                          if (_controller.isAttached) {
                                            _controller.jumpTo(next);
                                          } else {
                                            _manualAnimation.value = next;
                                          }
                                        }
                                      : null,
                                  onVerticalDragEnd: widget.enableDrag
                                      ? _settle
                                      : null,
                                  onVerticalDragCancel: widget.enableDrag
                                      ? () => _settle(DragEndDetails())
                                      : null,
                                  child: SizedBox(
                                    key: const ValueKey(
                                      'liquid-glass-sheet-handle',
                                    ),
                                    height: 32,
                                    width: double.infinity,
                                    child: Center(
                                      child: Container(
                                        height: 5,
                                        width: 36,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: .25),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: PrimaryScrollController(
                                  controller: scrollController,
                                  child: MediaQuery.removePadding(
                                    context: context,
                                    removeTop: true,
                                    removeBottom: true,
                                    child: MediaQuery.removeViewInsets(
                                      context: context,
                                      removeBottom: true,
                                      child: Builder(builder: widget.builder),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Uses only frames the application already produces. One process-wide frame
/// hook avoids keeping a ticker (and the GPU) running while a popover is idle.
class _AnchorFrames {
  static final Set<VoidCallback> _listeners = {};
  static bool _installed = false;

  static void add(VoidCallback callback) {
    _listeners.add(callback);
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final listener in _listeners.toList()) {
          if (_listeners.contains(listener)) listener();
        }
      });
    });
  }

  static void remove(VoidCallback callback) => _listeners.remove(callback);
}

class _Popover extends StatefulWidget {
  const _Popover({
    required this.anchorContext,
    required this.builder,
    required this.width,
    required this.maxHeight,
    required this.gap,
    required this.semanticLabel,
  });

  final BuildContext anchorContext;
  final WidgetBuilder builder;
  final double width;
  final double maxHeight;
  final double gap;
  final String? semanticLabel;

  @override
  State<_Popover> createState() => _PopoverState();
}

class _PopoverState extends State<_Popover> {
  Rect? _anchor;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _AnchorFrames.add(_updateAnchor);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAnchor());
  }

  @override
  void dispose() {
    _AnchorFrames.remove(_updateAnchor);
    super.dispose();
  }

  void _updateAnchor() {
    if (!mounted || _closing) return;
    final source = widget.anchorContext;
    final box = source.mounted ? source.findRenderObject() : null;
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        overlay is! RenderBox ||
        !overlay.attached) {
      _closing = true;
      final route = ModalRoute.of(context)!;
      if (!route.isActive) return;
      final navigator = Navigator.of(context);
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
      return;
    }
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
    if (!rect.isFinite) return;
    if (_anchor != rect) setState(() => _anchor = rect);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Rect.fromLTRB(
          math.min(media.padding.left + 12, constraints.maxWidth / 2),
          math.min(media.padding.top + 12, constraints.maxHeight / 2),
          math.max(
            constraints.maxWidth / 2,
            constraints.maxWidth - media.padding.right - 12,
          ),
          math.max(
            media.padding.top + 12,
            constraints.maxHeight -
                math.max(media.padding.bottom, media.viewInsets.bottom) -
                12,
          ),
        );
        final anchor = _anchor;
        if (anchor == null) return const SizedBox.expand();
        return CustomSingleChildLayout(
          delegate: _PopoverLayout(
            anchor: anchor,
            bounds: bounds,
            width: widget.width,
            maxHeight: widget.maxHeight,
            gap: widget.gap,
            direction: Directionality.of(context),
          ),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label:
                widget.semanticLabel ??
                MaterialLocalizations.of(context).popupMenuLabel,
            explicitChildNodes: true,
            child: LiquidGlassSurface(
              key: const ValueKey('liquid-glass-popover-surface'),
              radius: 24,
              child: Material(
                color: Colors.transparent,
                child: Builder(builder: widget.builder),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout({
    required this.anchor,
    required this.bounds,
    required this.width,
    required this.maxHeight,
    required this.gap,
    required this.direction,
  });

  final Rect anchor;
  final Rect bounds;
  final double width;
  final double maxHeight;
  final double gap;
  final TextDirection direction;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: math.min(width, bounds.width),
        maxWidth: math.min(width, bounds.width),
        maxHeight: math.min(maxHeight, bounds.height),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = bounds.bottom - anchor.bottom - gap;
    final above = anchor.top - bounds.top - gap;
    final useBelow = below >= childSize.height || below >= above;
    final x = direction == TextDirection.ltr
        ? anchor.left
        : anchor.right - childSize.width;
    final y = useBelow
        ? anchor.bottom + gap
        : anchor.top - gap - childSize.height;
    return Offset(
      x.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      y.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      width != oldDelegate.width ||
      maxHeight != oldDelegate.maxHeight ||
      gap != oldDelegate.gap ||
      direction != oldDelegate.direction;
}
