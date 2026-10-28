import 'package:flutter/material.dart';

import 'actions.dart';
import 'fallback_pressable.dart';
import 'feedback.dart';
import 'native_button_layout.dart';
import 'native_capsule.dart';
import 'native_fallback_report.dart';
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
    Widget icon(LiquidGlassAction action) =>
        Icon(action.icon, size: NativeButtonLayout.iconSize, color: foreground);
    Widget label(LiquidGlassAction action) => Text(
      action.label,
      style: foreground == null ? null : TextStyle(color: foreground),
    );
    final nativeMode =
        LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native;
    final largeText = MediaQuery.textScalerOf(context).scale(17) > 24;
    if (nativeMode && largeText) {
      reportNativeFallback(
        'LiquidGlassButtonGroup',
        'the text scale is above the native capsule\'s fixed height',
        'The native capsule returns at a smaller text size.',
      );
    }
    if (nativeMode && !largeText) {
      return NativeCapsule(
        items: [
          for (final action in actions)
            NativeCapsuleItem(
              id: action.id,
              label: action.label,
              title:
                  action.showLabel ||
                      action.icon == null && action.sfSymbol == null
                  ? action.label
                  : null,
              icon: action.icon,
              sfSymbol: action.sfSymbol,
              onPressed: action.onPressed,
              onLongPress: action.onLongPress,
              longPressSemanticLabel: action.longPressSemanticLabel,
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
              triggerMode: action.onLongPress == null
                  ? null
                  : TooltipTriggerMode.manual,
              child: Semantics(
                button: true,
                enabled: action.onPressed != null || action.onLongPress != null,
                onTap: action.onPressed == null
                    ? null
                    : () {
                        if (!LiquidGlassFeedback.canInteract(context)) return;
                        LiquidGlassFeedback.tap(context);
                        action.onPressed!();
                      },
                onLongPress: action.onLongPress == null
                    ? null
                    : () {
                        if (!LiquidGlassFeedback.canInteract(context)) return;
                        LiquidGlassFeedback.longPress(context);
                        action.onLongPress!();
                      },
                onLongPressHint: action.longPressSemanticLabel,
                label: action.label,
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: FallbackPressable(
                    key: ValueKey(action.id),
                    borderRadius: BorderRadius.circular(24),
                    onTap: action.onPressed,
                    onLongPress: action.onLongPress,
                    longPressSemanticLabel: action.longPressSemanticLabel,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Opacity(
                        opacity:
                            action.onPressed == null &&
                                action.onLongPress == null
                            ? .48
                            : 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: action.icon == null
                              ? label(action)
                              : action.showLabel
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    icon(action),
                                    const SizedBox(
                                      width: NativeButtonLayout.imagePadding,
                                    ),
                                    label(action),
                                  ],
                                )
                              : icon(action),
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
