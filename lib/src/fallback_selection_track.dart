import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// One moving thumb shared by tabs and segments. The content determines height,
/// so larger text can grow the track without clipping labels or hit targets.
class FallbackSelectionTrack extends StatelessWidget {
  const FallbackSelectionTrack({
    super.key,
    required this.selectedIndex,
    required this.children,
    this.radius = 26,
  }) : assert(children.length > 0),
       assert(selectedIndex >= 0 && selectedIndex < children.length);

  final int selectedIndex;
  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overrides = LiquidGlassTheme.of(context).colors;
    final dark = colors.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final reduced =
        LiquidGlassTheme.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    final position = children.length == 1
        ? 0.0
        : 2 * selectedIndex / (children.length - 1) - 1;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedAlign(
                  // A zero duration alone does not stop an in-flight implicit
                  // animation. Reset only the decorative thumb when this
                  // preference changes; interactive children stay mounted.
                  key: ValueKey(reduced),
                  alignment: AlignmentDirectional(position, 0),
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: const _SelectionSpring(),
                  child: FractionallySizedBox(
                    widthFactor: 1 / children.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            overrides.selection ??
                            colors.onSurface.withValues(
                              alpha: highContrast ? .22 : (dark ? .10 : .08),
                            ),
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: highContrast
                              ? colors.onSurface
                              : overrides.border ??
                                    (dark ? Colors.white : colors.onSurface)
                                        .withValues(alpha: dark ? .12 : .06),
                          width: highContrast ? 1 : .6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final child in children) Expanded(child: child)],
          ),
        ),
      ],
    );
  }
}

/// A bounded damped response: quick departure and a soft landing, with no
/// overshoot outside the capsule when switching between the end destinations.
class _SelectionSpring extends Curve {
  const _SelectionSpring();

  @override
  double transformInternal(double t) {
    const damping = .90;
    final omega = 2 * math.pi;
    final damped = omega * math.sqrt(1 - damping * damping);
    double response(double x) =>
        1 -
        math.exp(-damping * omega * x) *
            (math.cos(damped * x) +
                damping * omega / damped * math.sin(damped * x));
    return response(t) / response(1);
  }
}
