import 'package:flutter/material.dart';

import 'theme.dart';

/// Keeps the hit region still while giving fallback controls tactile feedback.
/// Explicit colors also work when the embedding app disables Material splashes.
class FallbackPressable extends StatefulWidget {
  const FallbackPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.scaleOnPress = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool scaleOnPress;

  @override
  State<FallbackPressable> createState() => _FallbackPressableState();
}

class _FallbackPressableState extends State<FallbackPressable> {
  bool _pressed = false;

  @override
  void didUpdateWidget(FallbackPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context).colors;
    final reduced =
        LiquidGlassTheme.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return InkWell(
      borderRadius: widget.borderRadius,
      onTap: widget.onTap,
      onHighlightChanged: (pressed) {
        if (_pressed != pressed) setState(() => _pressed = pressed);
      },
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return (colors.foreground ?? Theme.of(context).colorScheme.onSurface)
              .withValues(alpha: .06);
        }
        return Colors.transparent;
      }),
      child: AnimatedScale(
        scale: _pressed && !reduced && widget.scaleOnPress ? .97 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
