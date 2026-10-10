import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'native_value_control.dart';
import 'surface.dart';
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
    final reduceMotion =
        glass.reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativeValueControl(
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
      );
    }
    double snap(double next) {
      if (divisions == null) return next;
      final fraction =
          ((next - min) / (max - min) * divisions!).round() / divisions!;
      return (min + fraction * (max - min)).clamp(min, max);
    }

    final increment = (max - min) / (divisions ?? 20);
    void adjust(double next) {
      onChangeStart?.call(value);
      onChanged?.call(next);
      onChangeEnd?.call(next);
    }

    final next = (value + increment).clamp(min, max);
    final previous = (value - increment).clamp(min, max);
    return Semantics(
      label: semanticLabel,
      value: _format(value),
      enabled: onChanged != null,
      slider: true,
      increasedValue: onChanged != null && value < max ? _format(next) : null,
      decreasedValue: onChanged != null && value > min
          ? _format(previous)
          : null,
      onIncrease: onChanged != null && value < max ? () => adjust(next) : null,
      onDecrease: onChanged != null && value > min
          ? () => adjust(previous)
          : null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: CupertinoSlider(
            // A continuous SDK slider installs its value immediately. Snapping
            // at the callback boundary retains discrete semantics without its
            // built-in position animation (which ignores package reduceMotion).
            key: ValueKey(reduceMotion),
            value: value,
            min: min,
            max: max,
            divisions: reduceMotion ? null : divisions,
            activeColor: accent ?? Theme.of(context).colorScheme.primary,
            onChanged: onChanged == null
                ? null
                : (next) => onChanged!(snap(next)),
            onChangeStart: onChanged == null ? null : onChangeStart,
            onChangeEnd: onChanged == null || onChangeEnd == null
                ? null
                : (next) => onChangeEnd!(snap(next)),
          ),
        ),
      ),
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
    final reduceMotion =
        glass.reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativeValueControl(
        kind: 'switch',
        value: value ? 1 : 0,
        enabled: onChanged != null,
        accent: accent,
        semanticLabel: semanticLabel,
        onChanged: (value) => onChanged?.call(value >= .5),
      );
    }
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: _FallbackSwitch(
            value: value,
            onChanged: onChanged,
            reduceMotion: reduceMotion,
            color: accent ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// CupertinoSwitch has no animation-duration setting. In reduced-motion mode,
// retain its SDK gesture/keyboard behavior but recreate its paint state at each
// accepted endpoint, with tickers muted. Its drag decision uses a logical value
// independently of the animation, so rejected edits and RTL drags still work.
class _FallbackSwitch extends StatefulWidget {
  const _FallbackSwitch({
    required this.value,
    required this.onChanged,
    required this.reduceMotion,
    required this.color,
  });
  final bool value, reduceMotion;
  final ValueChanged<bool>? onChanged;
  final Color color;
  @override
  State<_FallbackSwitch> createState() => _FallbackSwitchState();
}

class _FallbackSwitchState extends State<_FallbackSwitch> {
  final _focusNode = FocusNode();
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: !widget.reduceMotion,
    child: CupertinoSwitch(
      key: ValueKey(widget.reduceMotion ? widget.value : null),
      value: widget.value,
      onChanged: widget.onChanged,
      focusNode: _focusNode,
      activeTrackColor: widget.color,
    ),
  );
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

  double _next(int direction) {
    final next = value + direction * step;
    if (wraps && next > max) return min;
    if (wraps && next < min) return max;
    return next.clamp(min, max);
  }

  bool _enabled(int direction) =>
      onChanged != null &&
      (wraps || (direction > 0 ? value < max : value > min));

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
      return NativeValueControl(
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
      );
    }
    final increase = _enabled(1), decrease = _enabled(-1);
    return Semantics(
      label: semanticLabel,
      value: _format(value),
      enabled: onChanged != null,
      increasedValue: increase ? _format(_next(1)) : null,
      decreasedValue: decrease ? _format(_next(-1)) : null,
      onIncrease: increase ? () => onChanged!(_next(1)) : null,
      onDecrease: decrease ? () => onChanged!(_next(-1)) : null,
      child: ExcludeSemantics(
        child: LiquidGlassSurface(
          radius: 24,
          style: LiquidGlassSurfaceStyle.control,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final direction in [-1, 1])
                _RepeatingStepButton(
                  key: ValueKey(direction),
                  onPressed: _enabled(direction)
                      ? () => onChanged!(_next(direction))
                      : null,
                  color:
                      colors.foreground ??
                      Theme.of(context).colorScheme.onSurface,
                  icon: direction < 0
                      ? CupertinoIcons.minus
                      : CupertinoIcons.plus,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepeatingStepButton extends StatefulWidget {
  const _RepeatingStepButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.color,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;

  @override
  State<_RepeatingStepButton> createState() => _RepeatingStepButtonState();
}

class _RepeatingStepButtonState extends State<_RepeatingStepButton>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _awaitingFrame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _repeat() {
    _stop();
    _invoke();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (widget.onPressed == null) {
        _stop();
      } else {
        _invoke();
      }
    });
  }

  void _invoke() {
    // If a frame is delayed, repeating must not propose the same stale value
    // several times before the controlled parent has had a chance to rebuild.
    if (_awaitingFrame || widget.onPressed == null) return;
    _awaitingFrame = true;
    widget.onPressed!();
    WidgetsBinding.instance.addPostFrameCallback((_) => _awaitingFrame = false);
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didUpdateWidget(_RepeatingStepButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _stop();
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: widget.onPressed == null ? null : (_) => _repeat(),
    onLongPressEnd: (_) => _stop(),
    onLongPressCancel: _stop,
    child: CupertinoButton(
      padding: const EdgeInsets.all(12),
      minimumSize: const Size(48, 48),
      onPressed: widget.onPressed,
      child: Icon(
        widget.icon,
        size: 20,
        color: widget.color.withValues(
          alpha: widget.onPressed == null ? .4 : 1,
        ),
      ),
    ),
  );
}
