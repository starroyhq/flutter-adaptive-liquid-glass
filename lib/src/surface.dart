import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'theme.dart';

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
  final Color? tint;
  final LiquidGlassSurfaceStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = LiquidGlassTheme.modeOf(context);
    final dark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    if (mode == LiquidGlassMode.native) {
      return native.LiquidGlassContainer(
        config: native.LiquidGlassConfig(
          cornerRadius: radius,
          tint: tint,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: .35),
        ),
        child: content,
      );
    }
    final opaque = mode == LiquidGlassMode.opaque;
    final highContrast = MediaQuery.highContrastOf(context);
    final control = style == LiquidGlassSurfaceStyle.control;
    final colors = theme.colorScheme;
    // One neutral material, not a painted reflection. Dark surfaces need a
    // small tonal lift above a black canvas; the host still owns the palette.
    final base = tint ?? (dark ? colors.surfaceContainer : colors.surface);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(
          alpha: opaque
              ? 1
              : control
              ? (dark ? .84 : .82)
              : (dark ? .90 : .92),
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.onSurface.withValues(
            alpha: highContrast
                ? (dark ? .22 : .16)
                : control
                ? (dark ? .14 : .06)
                : (dark ? .12 : .08),
          ),
          width: .5,
        ),
      ),
      child: content,
    );
    if (opaque) return surface;
    final requestedBlur = LiquidGlassTheme.of(context).blurSigma;
    final blur = control ? requestedBlur.clamp(0.0, 8.0) : requestedBlur;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: control ? (dark ? .12 : .04) : (dark ? .16 : .06),
            ),
            blurRadius: control ? 8 : 12,
            spreadRadius: -3,
            offset: Offset(0, control ? 2 : 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: surface,
        ),
      ),
    );
  }
}
