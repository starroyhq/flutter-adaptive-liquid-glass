import 'package:flutter/material.dart';

import 'theme.dart';

/// How content is treated where it scrolls beneath floating chrome, after
/// iOS 26's scroll edge effect styles.
enum LiquidGlassEdgeEffectStyle {
  /// A color fade into the page background.
  soft,

  /// An opaque band of the page background with a hairline divider.
  hard,
}

/// Softens scrolling content where it passes beneath floating chrome, such as
/// a glass navigation bar, the status bar or a floating tab bar.
///
/// iOS 26 applies this effect to `UIScrollView` only, so Flutter scrollables
/// never receive it from the system; this widget draws it in every mode. Wrap
/// the scrollable whose content runs under the chrome and give the extent the
/// chrome covers at each edge, 0 for none. An edge shows its effect only while
/// content is actually beneath it: not at rest at the top, and not once the end
/// has been reached at the bottom.
///
/// Reduced transparency, high contrast and the opaque mode use
/// [LiquidGlassEdgeEffectStyle.hard].
class LiquidGlassScrollEdgeEffect extends StatefulWidget {
  const LiquidGlassScrollEdgeEffect({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 0,
    this.topStyle = LiquidGlassEdgeEffectStyle.soft,
    this.bottomStyle = LiquidGlassEdgeEffectStyle.soft,
    this.color,
  }) : assert(top >= 0 && bottom >= 0);

  final Widget child;

  /// Height of the band at the top and bottom edges, in logical pixels.
  final double top, bottom;
  final LiquidGlassEdgeEffectStyle topStyle, bottomStyle;

  /// The page background the content fades into; defaults to the theme's
  /// scaffold background colour.
  final Color? color;

  @override
  State<LiquidGlassScrollEdgeEffect> createState() =>
      _LiquidGlassScrollEdgeEffectState();
}

class _LiquidGlassScrollEdgeEffectState
    extends State<LiquidGlassScrollEdgeEffect> {
  bool _underTop = false, _underBottom = false;

  bool _observe(ScrollMetrics metrics) {
    final top = metrics.pixels > metrics.minScrollExtent + .5;
    final bottom = metrics.pixels < metrics.maxScrollExtent - .5;
    if (top != _underTop || bottom != _underBottom) {
      // Notifications arrive during layout; update after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _underTop = top;
            _underBottom = bottom;
          });
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mode = LiquidGlassTheme.modeOf(context);
    final solid =
        mode == LiquidGlassMode.opaque || MediaQuery.highContrastOf(context);
    final color = widget.color ?? Theme.of(context).scaffoldBackgroundColor;
    final duration =
        LiquidGlassTheme.of(context).reduceMotion ||
            MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    Widget edge(bool top) {
      final extent = top ? widget.top : widget.bottom;
      if (extent <= 0) return const SizedBox.shrink();
      final style = solid
          ? LiquidGlassEdgeEffectStyle.hard
          : top
          ? widget.topStyle
          : widget.bottomStyle;
      return Positioned(
        left: 0,
        right: 0,
        top: top ? 0 : null,
        bottom: top ? null : 0,
        height: extent,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: (top ? _underTop : _underBottom) ? 1 : 0,
            duration: duration,
            child: style == LiquidGlassEdgeEffectStyle.hard
                ? _HardEdge(top: top, color: color)
                : _SoftEdge(top: top, color: color),
          ),
        ),
      );
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) =>
          notification.depth == 0 ? _observe(notification.metrics) : false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            notification.depth == 0 ? _observe(notification.metrics) : false,
        child: Stack(children: [widget.child, edge(true), edge(false)]),
      ),
    );
  }
}

class _SoftEdge extends StatelessWidget {
  const _SoftEdge({required this.top, required this.color});
  final bool top;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: top ? Alignment.topCenter : Alignment.bottomCenter,
        end: top ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [color, color.withValues(alpha: 0)],
      ),
    ),
  );
}

class _HardEdge extends StatelessWidget {
  const _HardEdge({required this.top, required this.color});
  final bool top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: Theme.of(context).dividerColor,
      width: 1 / MediaQuery.devicePixelRatioOf(context),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 1),
        border: Border(
          bottom: top ? divider : BorderSide.none,
          top: top ? BorderSide.none : divider,
        ),
      ),
    );
  }
}
