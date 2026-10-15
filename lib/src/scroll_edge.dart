import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// How content is treated where it scrolls beneath floating chrome, after
/// iOS 26's scroll edge effect styles.
enum LiquidGlassEdgeEffectStyle {
  /// A progressive blur that fades into the page background.
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
/// [LiquidGlassEdgeEffectStyle.hard]. Native platform views inside the
/// scrolling content are composited by the system and may not be blurred.
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
        child: BackdropGroup(
          child: Stack(children: [widget.child, edge(true), edge(false)]),
        ),
      ),
    );
  }
}

/// A progressive blur: nested slices that share one backdrop read, each
/// shorter one nearer the edge and blurred more, under a fade into the page
/// colour that hides the steps between them.
class _SoftEdge extends StatelessWidget {
  const _SoftEdge({required this.top, required this.color});
  final bool top;
  final Color color;

  // Small steps keep the boundaries between slices from showing.
  static const _sigmas = [0.5, 1.0, 1.75, 2.5, 3.5, 4.75, 6.0, 8.0];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final slice = constraints.maxHeight / _sigmas.length;
      return Stack(
        children: [
          for (var i = 0; i < _sigmas.length; i++)
            Positioned(
              left: 0,
              right: 0,
              // Grouped filters read the same backdrop, so the shortest,
              // strongest slice painted last wins nearest the edge.
              top: top ? 0 : slice * i,
              bottom: top ? slice * i : 0,
              child: ClipRect(
                child: BackdropFilter.grouped(
                  filter: ui.ImageFilter.blur(
                    sigmaX: _sigmas[i],
                    sigmaY: _sigmas[i],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [
                    color.withValues(alpha: color.a * .8),
                    color.withValues(alpha: color.a * .35),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
          ),
        ],
      );
    },
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
