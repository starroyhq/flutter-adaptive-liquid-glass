import 'package:flutter/material.dart';

import 'native_value_control.dart';
import 'fallback_value_controls.dart';
import 'native_visibility.dart';
import 'theme.dart';

/// A controlled slider. A null [onChanged] disables interaction.
class LiquidGlassSlider extends StatelessWidget {
  const LiquidGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.semanticLabel,
    this.semanticFormatterCallback,
  }) : assert(min < max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final String? semanticLabel;
  final String Function(double)? semanticFormatterCallback;

  String _format(double number) =>
      semanticFormatterCallback?.call(number) ??
      '${((number - min) / (max - min) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    assert(
      value.isFinite && min.isFinite && max.isFinite && (max - min).isFinite,
    );
    final glass = LiquidGlassTheme.of(context);
    final accent = glass.colors.accent;
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativeCoverFallback(
        fallback: (_) => this,
        child: NativeValueControl(
          kind: 'slider',
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          enabled: onChanged != null,
          accent: accent,
          semanticLabel: semanticLabel,
          semanticValue: _format(value),
          onChanged: (value) => onChanged?.call(value),
          onChangeStart: onChangeStart,
          onChangeEnd: onChangeEnd,
        ),
      );
    }
    return FallbackGlassSlider(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      divisions: divisions,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      semanticLabel: semanticLabel,
      semanticFormatterCallback: semanticFormatterCallback,
    );
  }
}

/// A controlled binary switch with native UIKit interaction on iOS 26+.
class LiquidGlassSwitch extends StatelessWidget {
  const LiquidGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glass = LiquidGlassTheme.of(context);
    final accent = glass.colors.accent;
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativeCoverFallback(
        fallback: (_) => this,
        child: NativeValueControl(
          kind: 'switch',
          value: value ? 1 : 0,
          enabled: onChanged != null,
          accent: accent,
          semanticLabel: semanticLabel,
          onChanged: (value) => onChanged?.call(value >= .5),
        ),
      );
    }
    return FallbackGlassSwitch(
      value: value,
      onChanged: onChanged,
      semanticLabel: semanticLabel,
    );
  }
}

/// Shared-capsule increment/decrement control with press-and-hold repetition.
class LiquidGlassStepper extends StatelessWidget {
  const LiquidGlassStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.wraps = false,
    this.semanticLabel,
  }) : assert(min < max),
       assert(value >= min && value <= max),
       assert(step > 0);

  final double value, min, max, step;
  final bool wraps;
  final ValueChanged<double>? onChanged;
  final String? semanticLabel;

  String _format(double number) => number == number.truncateToDouble()
      ? number.toStringAsFixed(0)
      : double.parse(number.toStringAsPrecision(12)).toString();

  @override
  Widget build(BuildContext context) {
    assert(
      value.isFinite &&
          min.isFinite &&
          max.isFinite &&
          step.isFinite &&
          (max - min).isFinite,
    );
    final colors = LiquidGlassTheme.of(context).colors;
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativeCoverFallback(
        fallback: (_) => this,
        child: NativeValueControl(
          kind: 'stepper',
          value: value,
          min: min,
          max: max,
          step: step,
          wraps: wraps,
          enabled: onChanged != null,
          accent: colors.accent,
          semanticLabel: semanticLabel,
          semanticValue: _format(value),
          onChanged: (value) => onChanged?.call(value),
        ),
      );
    }
    return FallbackGlassStepper(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      step: step,
      wraps: wraps,
      semanticLabel: semanticLabel,
    );
  }
}
