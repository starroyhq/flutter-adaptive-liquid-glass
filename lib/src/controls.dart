import 'package:flutter/material.dart';

import 'surface.dart';
import 'fallback_pressable.dart';
import 'fallback_selection_track.dart';
import 'feedback.dart';
import 'theme.dart';
import 'native_visibility.dart';
import 'native_capsule.dart';
import 'native_fallback_report.dart';
import 'native_segmented_control.dart';

class LiquidGlassButton extends StatelessWidget {
  /// An icon-only button with a required accessibility label.
  const LiquidGlassButton.icon({
    super.key,
    required IconData this.icon,
    required String this.semanticLabel,
    this.sfSymbol,
    this.onPressed,
    this.onLongPress,
    this.longPressSemanticLabel,
    this.prominent = false,
    this.loading = false,
    this.id,
  }) : label = null,
       detail = null,
       iconColor = null,
       iconSize = null,
       menuIndicator = false;

  const LiquidGlassButton({
    super.key,
    this.label,
    this.icon,
    this.sfSymbol,
    this.semanticLabel,
    this.onPressed,
    this.onLongPress,
    this.longPressSemanticLabel,
    this.prominent = false,
    this.loading = false,
    this.id,
    this.detail,
    this.iconColor,
    this.iconSize,
    this.menuIndicator = false,
  }) : assert(label != null || icon != null),
       assert(detail == null || label != null, 'A detail follows a label.'),
       assert(iconSize == null || iconSize > 0),
       assert(
         label != null || semanticLabel != null,
         'Icon buttons require a semantic label.',
       );

  final String? label;
  final IconData? icon;
  final String? sfSymbol;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? longPressSemanticLabel;

  /// Fills the button with the accent color. A disabled button is drawn without
  /// the fill, like any other disabled button, until it can be pressed.
  final bool prominent;
  final bool loading;

  /// Names the button to UI tests and accessibility tooling: it becomes the
  /// accessibility identifier of the native button, `button` when null. Flutter
  /// finders use [key] instead.
  final String? id;

  /// Secondary text after [label] on the same line, in a quieter colour, such
  /// as a state ("Online") or the current choice of a picker.
  final String? detail;

  /// Colours the icon instead of the foreground, for example a status dot.
  /// Pick a colour that stays legible on the glass in both brightnesses.
  final Color? iconColor;

  /// Icon size in logical pixels; 22 by default. Smaller sizes suit marks such
  /// as a status dot.
  final double? iconSize;

  /// Shows the platform's pop-up indicator after the label, marking a button
  /// that opens a menu or a picker.
  final bool menuIndicator;

  String? get _accessibleLabel =>
      semanticLabel ?? (detail == null ? label : '$label, $detail');

  @override
  Widget build(BuildContext context) {
    final callback = loading ? null : onPressed;
    final longCallback = loading ? null : onLongPress;
    final enabled = callback != null || longCallback != null;
    // A solid accent fill under a faded label reads as broken, so a disabled
    // button gives up its emphasis. A loading one keeps it: the fill is what
    // shows that work is under way.
    final emphasized = prominent && (enabled || loading);
    final colors = Theme.of(context).colorScheme;
    final glassColors = LiquidGlassTheme.of(context).colors;
    final textColor = emphasized
        ? glassColors.onAccent ?? colors.onPrimary
        : glassColors.foreground ?? colors.onSurface;
    final accent = glassColors.accent ?? colors.primary;
    final nativeMode =
        LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    if (nativeMode && loading) {
      reportNativeFallback(
        'LiquidGlassButton',
        'loading is true',
        'The native button returns once loading is false.',
      );
    } else if (nativeMode && largeText) {
      reportNativeFallback(
        'LiquidGlassButton',
        'the text scale is above the native button\'s fixed height',
        'The native button returns at a smaller text size.',
      );
    }
    if (nativeMode && !loading && !largeText) {
      // An icon-only button keeps its standalone look, with or without a
      // long press.
      return NativeCoverFallback(
        fallback: (_) => this,
        child: NativeCapsule(
          standaloneIcon: label == null,
          prominent: emphasized,
          items: [
            NativeCapsuleItem(
              id: id ?? 'button',
              label: _accessibleLabel ?? label!,
              title: label,
              detail: detail,
              icon: icon,
              sfSymbol: sfSymbol,
              iconColor: iconColor,
              iconSize: iconSize,
              menuIndicator: menuIndicator,
              onPressed: callback,
              onLongPress: longCallback,
              longPressSemanticLabel: longPressSemanticLabel,
            ),
          ],
        ),
      );
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
          Icon(icon, size: iconSize ?? 22, color: iconColor),
        if ((icon != null || loading) && label != null)
          const SizedBox(width: 8),
        if (label != null)
          Flexible(child: Text(label!, textAlign: TextAlign.center)),
        if (detail != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              detail!,
              style: TextStyle(
                color: textColor.withValues(alpha: textColor.a * .6),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
        if (menuIndicator) ...[
          const SizedBox(width: 4),
          const Icon(Icons.unfold_more, size: 18),
        ],
      ],
    );
    final button = Material(
      color: emphasized ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: FallbackPressable(
        borderRadius: BorderRadius.circular(24),
        onTap: callback,
        onLongPress: longCallback,
        longPressSemanticLabel: longPressSemanticLabel,
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
      enabled: enabled,
      label: detail == null ? semanticLabel : _accessibleLabel,
      excludeSemantics: detail != null,
      child: Opacity(
        opacity: !enabled && !loading ? .48 : 1,
        child: emphasized
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
    final glassColors = LiquidGlassTheme.of(context).colors;
    final nativeMode =
        LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    if (nativeMode && largeText) {
      reportNativeFallback(
        'LiquidGlassSegmentedControl',
        'the text scale is above the native control\'s fixed height',
        'The native control returns at a smaller text size.',
      );
    }
    if (nativeMode && !largeText) {
      return NativeCoverFallback(
        fallback: (_) => this,
        child: NativeVisibility(
          child: NativeSegmentedControl(
            labels: [for (final segment in segments) segment.label],
            selectedIndex: segments.indexWhere(
              (segment) => segment.value == selected,
            ),
            enabled: onChanged != null,
            color: glassColors.accent ?? Theme.of(context).colorScheme.primary,
            onValueChanged: (index) {
              if (index >= 0 && index < segments.length) {
                onChanged?.call(segments[index].value);
              }
            },
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    void select(T value) {
      if (onChanged == null || !LiquidGlassFeedback.canInteract(context)) {
        return;
      }
      if (value != selected) LiquidGlassFeedback.selection(context);
      onChanged!(value);
    }

    return Opacity(
      opacity: onChanged == null ? .5 : 1,
      child: LiquidGlassSurface(
        radius: 28,
        style: LiquidGlassSurfaceStyle.control,
        padding: const EdgeInsets.all(4),
        child: FallbackSelectionTrack(
          selectedIndex: segments.indexWhere(
            (segment) => segment.value == selected,
          ),
          radius: 24,
          children: [
            for (final segment in segments)
              Semantics(
                selected: segment.value == selected,
                button: true,
                enabled: onChanged != null,
                label: segment.label,
                excludeSemantics: true,
                onTap: onChanged == null ? null : () => select(segment.value),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: FallbackPressable(
                    borderRadius: BorderRadius.circular(24),
                    scaleOnPress: false,
                    feedbackOnTap: false,
                    onTap: onChanged == null
                        ? null
                        : () => select(segment.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Center(
                          child: Text(
                            segment.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: segment.value == selected
                                      ? glassColors.selectedForeground ??
                                            glassColors.foreground ??
                                            colors.onSurface
                                      : glassColors.foreground ??
                                            colors.onSurface,
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
          ],
        ),
      ),
    );
  }
}
