import 'package:flutter/material.dart';
import 'fallback_activity_indicator.dart';
import 'native_status.dart';
import 'theme.dart';

enum LiquidGlassActivityIndicatorStyle { medium, large }

/// An indeterminate status indicator. It does not add a glass content surface.
class LiquidGlassActivityIndicator extends StatelessWidget {
  const LiquidGlassActivityIndicator({
    super.key,
    this.animating = true,
    this.hidesWhenStopped = true,
    this.style = LiquidGlassActivityIndicatorStyle.medium,
    this.size = 44,
    this.color,
    this.semanticLabel,
  }) : assert(size > 0 && size < double.infinity);

  final bool animating;
  final bool hidesWhenStopped;
  final LiquidGlassActivityIndicatorStyle style;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (!animating && hidesWhenStopped) return SizedBox.square(dimension: size);
    final glass = LiquidGlassTheme.of(context);
    final foreground =
        color ??
        glass.colors.foreground ??
        Theme.of(context).colorScheme.onSurface;
    final moving =
        animating &&
        !glass.reduceMotion &&
        !MediaQuery.disableAnimationsOf(context);
    final radius =
        (style == LiquidGlassActivityIndicatorStyle.large ? 14.0 : 10.0).clamp(
          0.0,
          size / 2,
        );
    final Widget indicator;
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      indicator = NativeStatus(
        kind: 'activity',
        animating: moving,
        style: style.name,
        color: foreground,
        height: size,
        width: size,
      );
    } else {
      indicator = SizedBox.square(
        dimension: size,
        child: Center(
          child: FallbackGlassActivityIndicator(
            animating: moving,
            radius: radius,
            color: foreground,
          ),
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: indicator),
    );
  }
}

/// A determinate progress value from zero to one, without an extra glass layer.
class LiquidGlassProgressView extends StatelessWidget {
  const LiquidGlassProgressView({
    super.key,
    required this.progress,
    this.height = 4,
    this.color,
    this.trackColor,
    this.semanticLabel,
    this.semanticValue,
  }) : assert(progress >= 0 && progress <= 1),
       assert(height > 0 && height < double.infinity);

  final double progress;
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final glass = LiquidGlassTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = color ?? glass.colors.accent ?? scheme.primary;
    final track =
        trackColor ?? glass.colors.selection ?? scheme.surfaceContainerHighest;
    final Widget indicator =
        LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native
        ? NativeStatus(
            kind: 'progress',
            progress: progress,
            height: height,
            color: active,
            trackColor: track,
          )
        : LinearProgressIndicator(
            value: progress,
            minHeight: height,
            borderRadius: BorderRadius.circular(height / 2),
            color: active,
            backgroundColor: track,
          );
    return Semantics(
      label: semanticLabel,
      value: semanticValue ?? '${(progress * 100).round()}%',
      child: ExcludeSemantics(child: indicator),
    );
  }
}
