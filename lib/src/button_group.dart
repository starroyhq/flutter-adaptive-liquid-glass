import 'package:flutter/material.dart';

import 'actions.dart';
import 'fallback_pressable.dart';
import 'native_button_layout.dart';
import 'native_capsule.dart';
import 'surface.dart';
import 'theme.dart';

/// Adjacent actions share one continuous glass capsule, including on iOS.
/// Individual actions are plain buttons, never nested glass circles.
class LiquidGlassButtonGroup extends StatelessWidget {
  LiquidGlassButtonGroup({super.key, required this.actions})
    : assert(actions.isNotEmpty),
      assert(
        actions.map((action) => action.id).toSet().length == actions.length,
      );

  final List<LiquidGlassAction> actions;

  @override
  Widget build(BuildContext context) {
    final foreground = LiquidGlassTheme.of(context).colors.foreground;
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native &&
        MediaQuery.textScalerOf(context).scale(17) <= 24) {
      return NativeCapsule(
        items: [
          for (final action in actions)
            NativeCapsuleItem(
              id: action.id,
              label: action.label,
              title: action.icon == null && action.sfSymbol == null
                  ? action.label
                  : null,
              icon: action.icon,
              sfSymbol: action.sfSymbol,
              onPressed: action.onPressed,
            ),
        ],
        grouped: true,
      );
    }
    return LiquidGlassSurface(
      radius: 24,
      style: LiquidGlassSurfaceStyle.control,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            Tooltip(
              message: action.label,
              child: Semantics(
                button: true,
                enabled: action.onPressed != null,
                onTap: action.onPressed,
                label: action.label,
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: FallbackPressable(
                    key: ValueKey(action.id),
                    borderRadius: BorderRadius.circular(24),
                    onTap: action.onPressed,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Opacity(
                        opacity: action.onPressed == null ? .4 : 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: action.icon != null
                              ? Icon(
                                  action.icon,
                                  size: NativeButtonLayout.iconSize,
                                  color: foreground,
                                )
                              : Text(
                                  action.label,
                                  style: foreground == null
                                      ? null
                                      : TextStyle(color: foreground),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
