import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'surface.dart';
import 'fallback_pressable.dart';
import 'theme.dart';
import 'native_button_layout.dart';
import 'native_capsule.dart';

class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    this.label,
    this.icon,
    this.sfSymbol,
    this.semanticLabel,
    this.onPressed,
    this.prominent = false,
    this.loading = false,
  }) : assert(label != null || icon != null),
       assert(
         label != null || semanticLabel != null,
         'Icon buttons require a semantic label.',
       );

  final String? label;
  final IconData? icon;
  final String? sfSymbol;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool prominent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final callback = loading ? null : onPressed;
    final colors = Theme.of(context).colorScheme;
    final textColor = prominent ? colors.onPrimary : colors.onSurface;
    final nativeIcon = sfSymbol != null
        ? native.NativeLiquidGlassIcon.sfSymbol(sfSymbol!)
        : icon != null
        ? native.NativeLiquidGlassIcon.iconData(icon!)
        : null;
    final useNative =
        LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native &&
        !loading &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;
    if (useNative) {
      if (label != null) {
        return NativeCapsule(
          prominent: prominent,
          items: [
            NativeCapsuleItem(
              id: 'button',
              label: semanticLabel ?? label!,
              title: label,
              icon: icon,
              sfSymbol: sfSymbol,
              onPressed: callback,
            ),
          ],
        );
      }
      final button = native.LiquidGlassButton.icon(
        icon: nativeIcon!,
        onPressed: callback,
        tooltip: semanticLabel,
        size: NativeButtonLayout.height,
        iconSize: NativeButtonLayout.iconSize,
        padding: const EdgeInsets.all(12),
        iconColor: textColor,
        tint: prominent ? colors.primary : null,
        style: prominent
            ? native.LiquidGlassButtonStyle.prominentGlass
            : native.LiquidGlassButtonStyle.glass,
      );
      return Semantics(label: semanticLabel, child: button);
    }
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
          )
        else if (icon != null)
          Icon(icon, size: 22),
        if ((icon != null || loading) && label != null)
          const SizedBox(width: 8),
        if (label != null)
          Flexible(child: Text(label!, textAlign: TextAlign.center)),
      ],
    );
    final button = Material(
      color: prominent ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: FallbackPressable(
        borderRadius: BorderRadius.circular(24),
        onTap: callback,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 12 : 18,
              vertical: 10,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: IconTheme.merge(
                data: IconThemeData(color: textColor),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: callback != null,
      label: semanticLabel,
      child: Opacity(
        opacity: callback == null && !loading ? .48 : 1,
        child: prominent
            ? button
            : LiquidGlassSurface(
                radius: 24,
                style: LiquidGlassSurfaceStyle.control,
                child: button,
              ),
      ),
    );
  }
}

@immutable
class LiquidGlassSegment<T> {
  const LiquidGlassSegment({required this.value, required this.label});
  final T value;
  final String label;
}

class LiquidGlassSegmentedControl<T> extends StatelessWidget {
  LiquidGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  }) : assert(segments.isNotEmpty),
       assert(
         segments.map((segment) => segment.value).toSet().length ==
             segments.length,
       ),
       assert(segments.any((segment) => segment.value == selected));

  final List<LiquidGlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native &&
        MediaQuery.textScalerOf(context).scale(14) <= 20) {
      return native.LiquidGlassSegmentedControl(
        labels: [for (final segment in segments) segment.label],
        selectedIndex: segments.indexWhere(
          (segment) => segment.value == selected,
        ),
        enabled: onChanged != null,
        color: Theme.of(context).colorScheme.primary,
        height: 48,
        onValueChanged: (index) {
          if (index >= 0 && index < segments.length) {
            onChanged?.call(segments[index].value);
          }
        },
      );
    }
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(28);
    // Segments are a solid track and thumb, not nested translucent capsules.
    return Opacity(
      opacity: onChanged == null ? .5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: radius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final segment in segments)
                  Expanded(
                    child: Semantics(
                      selected: segment.value == selected,
                      button: true,
                      enabled: onChanged != null,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: segment.value == selected
                              ? (dark
                                    ? colors.surfaceContainerHighest
                                    : colors.surface)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: segment.value == selected
                              ? Border.all(
                                  color: colors.onSurface.withValues(
                                    alpha: highContrast ? .22 : .06,
                                  ),
                                  width: .5,
                                )
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: FallbackPressable(
                            borderRadius: BorderRadius.circular(24),
                            onTap: onChanged == null
                                ? null
                                : () => onChanged!(segment.value),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Center(
                                  child: Text(
                                    segment.label,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: segment.value == selected
                                              ? colors.onSurface
                                              : colors.onSurfaceVariant,
                                          fontWeight: segment.value == selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                  ),
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
          ),
        ),
      ),
    );
  }
}
