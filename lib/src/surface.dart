import 'package:flutter/material.dart';

import 'theme.dart';
import 'native_surface.dart';
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
                // While a route above hides the native material, the content
                // keeps an opaque Flutter material instead of floating over
                // the page, as a sheet does under an alert.
                // Its tone is the system material's over a plain page: 6% of
                // the way from the surface to the foreground.
                replacement: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        resolvedTint?.withValues(alpha: 1) ??
                        Color.lerp(
                          theme.colorScheme.surface,
                          theme.colorScheme.onSurface,
                          .06,
                        ),
                    borderRadius: borderRadius,
                  ),
                ),
                child: NativeSurface(
                  radius: radius,
                  dark: dark,
                  tint: resolvedTint,
                  backgroundColor:
                      (overrides.surfaceTint ?? theme.colorScheme.surface)
                          .withValues(alpha: .35),
                ),
              ),
            ),
          ),
          // Ink, scroll viewports and row highlights are rectangular; clip them
          // to the glass shape as the fallback paths do.
          ClipRRect(borderRadius: borderRadius, child: content),
        ],
      );
    }
    final opaque = mode == LiquidGlassMode.opaque;
    final highContrast = MediaQuery.highContrastOf(context);
    final control = style == LiquidGlassSurfaceStyle.control;
    final colors = theme.colorScheme;
    final foreground = overrides.foreground ?? colors.onSurface;
    final solid = opaque || highContrast;
    final neutral = dark
        ? (control ? const Color(0xff2c2c2e) : const Color(0xff1c1c1e))
        : Colors.white;
    final fill =
        (resolvedTint ??
                (solid
                    ? (dark ? colors.surfaceContainer : colors.surface)
                    : neutral))
            .withValues(alpha: 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(
          color: highContrast
              ? foreground.withValues(alpha: .65)
              : overrides.border ??
                    (opaque
                        ? foreground.withValues(alpha: .24)
                        : (dark ? Colors.white : Colors.black).withValues(
                            alpha: dark ? .13 : .09,
                          )),
          width: highContrast ? 1.25 : (opaque ? .75 : 1),
        ),
        boxShadow: solid
            ? null
            : [
                BoxShadow(
                  color:
                      overrides.shadow ??
                      Colors.black.withValues(alpha: dark ? .28 : .08),
                  blurRadius: control ? 12 : 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
  }
}
