import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'theme.dart';
import 'native_visibility.dart';

/// Fallback materials differ by placement; native system material is unchanged.
enum LiquidGlassSurfaceStyle { floating, control }

/// A bounded glass background. Text, editing and gestures remain in Flutter.
///
/// Keep these surfaces on navigation and floating controls. Large scrolling
/// regions need a solid background to keep reading contrast and raster cost stable.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.style = LiquidGlassSurfaceStyle.floating,
  }) : assert(radius >= 0);

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Overrides the neutral material color. Custom tints must be paired with
  /// suitable foreground colors by the caller; their contrast is not inferred.
  final Color? tint;
  final LiquidGlassSurfaceStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overrides = LiquidGlassTheme.of(context).colors;
    final mode = LiquidGlassTheme.modeOf(context);
    final dark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final resolvedTint = tint ?? overrides.surfaceTint;
    // Keep the subtree shape stable when adding/removing a palette so editors
    // and other stateful content are not recreated during a color change.
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: overrides.foreground),
      child: IconTheme.merge(
        data: IconThemeData(color: overrides.foreground),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (mode == LiquidGlassMode.native) {
      // Flutter content remains painted; only the native material leaves the
      // compositor while its route is covered by another native/Flutter layer.
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: NativeVisibility(
                child: native.LiquidGlassContainer(
                  config: native.LiquidGlassConfig(
                    cornerRadius: radius,
                    tint: resolvedTint,
                    backgroundColor:
                        (overrides.surfaceTint ?? theme.colorScheme.surface)
                            .withValues(alpha: .35),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          content,
        ],
      );
    }
    final opaque = mode == LiquidGlassMode.opaque;
    final highContrast = MediaQuery.highContrastOf(context);
    final control = style == LiquidGlassSurfaceStyle.control;
    final colors = theme.colorScheme;
    final foreground = overrides.foreground ?? colors.onSurface;
    if (opaque || highContrast) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color:
              (resolvedTint ??
                      (dark ? colors.surfaceContainer : colors.surface))
                  .withValues(alpha: 1),
          borderRadius: borderRadius,
          border: Border.all(
            color: highContrast
                ? foreground.withValues(alpha: .65)
                : overrides.border ?? foreground.withValues(alpha: .24),
            width: highContrast ? 1.25 : .75,
          ),
        ),
        child: ClipRRect(borderRadius: borderRadius, child: content),
      );
    }
    // A protective neutral wash preserves foreground contrast even when the
    // backdrop is the opposite brightness. Keep a subtle lift on black while
    // leaving enough backdrop visible for the blur and rim to read as glass.
    final base =
        resolvedTint ??
        (dark
            ? Color.lerp(colors.surface, colors.onSurface, .10)!
            : colors.surface);
    final fill = base.withValues(
      alpha: control ? (dark ? .78 : .64) : (dark ? .76 : .60),
    );
    final requestedBlur = LiquidGlassTheme.of(context).blurSigma;
    final blur = control ? requestedBlur.clamp(0.0, 8.0) : requestedBlur;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color:
                overrides.shadow ??
                Colors.black.withValues(
                  alpha: control ? (dark ? .16 : .08) : (dark ? .20 : .10),
                ),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: ColoredBox(color: fill),
                  ),
                ),
              ),
            ),
          ),
          // Keep animated controls and text separate from the material. The
          // backdrop still needs repainting whenever the scene beneath changes.
          RepaintBoundary(
            child: ClipRRect(borderRadius: borderRadius, child: content),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlassRim(
                  radius: radius,
                  dark: dark,
                  border: overrides.border,
                  highlight: overrides.highlight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRim extends CustomPainter {
  const _GlassRim({
    required this.radius,
    required this.dark,
    this.border,
    this.highlight,
  });

  final double radius;
  final bool dark;
  final Color? border;
  final Color? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const width = .8;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlight ?? Colors.white.withValues(alpha: dark ? .30 : .76),
          border ??
              (dark ? Colors.white : Colors.black).withValues(
                alpha: dark ? .07 : .11,
              ),
          highlight?.withValues(alpha: highlight!.a * .5) ??
              Colors.white.withValues(alpha: dark ? .14 : .44),
        ],
      ).createShader(rect);
    // Deflate both the outline and its radius, keeping the stroke inside the
    // same rounded rectangle as the backdrop clip, including small surfaces.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(width / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.dark != dark ||
      oldDelegate.border != border ||
      oldDelegate.highlight != highlight;
}
