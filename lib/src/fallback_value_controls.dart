import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';
import 'surface.dart';
import 'theme.dart';

bool _reduced(BuildContext context) =>
    LiquidGlassTheme.of(context).reduceMotion ||
    (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

/// Package-owned controlled slider, also used by the fallback color editor.
/// [continuousFeedback] suppresses intermediate discrete ticks when false;
/// entering an endpoint can still provide feedback. Continuous sliders only
/// provide boundary feedback, regardless of how many drag updates they emit.
class FallbackGlassSlider extends StatefulWidget {
  const FallbackGlassSlider({
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
    this.continuousFeedback = true,
  }) : assert(min < max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final String? semanticLabel;
  final String Function(double)? semanticFormatterCallback;
  final bool continuousFeedback;

  @override
  State<FallbackGlassSlider> createState() => _FallbackGlassSliderState();
}

class _FallbackGlassSliderState extends State<FallbackGlassSlider>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  bool _active = false, _pressed = false, _focused = false;
  double? _lastProposed;
  double _width = 240;
  // Distance between the touch and the thumb centre when the pointer landed on
  // the thumb, so grabbing its edge does not make the value jump.
  double _grabOffset = 0;

  bool get _enabled => widget.onChanged != null;
  bool get _interactive => _enabled && LiquidGlassFeedback.canInteract(context);
  // Debug builds assert the range; release builds stay on the track.
  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  double get _increment => (widget.max - widget.min) / (widget.divisions ?? 20);
  String _format(double value) =>
      widget.semanticFormatterCallback?.call(value) ??
      '${((value - widget.min) / (widget.max - widget.min) * 100).round()}%';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!LiquidGlassFeedback.canInteract(context)) _cancelLater();
  }

  @override
  void didUpdateWidget(FallbackGlassSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.divisions != widget.divisions ||
        (_active &&
            oldWidget.value != widget.value &&
            !_isProposalEcho(widget.value))) {
      _cancelLater(callback: oldWidget.onChangeEnd);
    }
  }

  bool _isProposalEcho(double value) =>
      _lastProposed != null &&
      (value - _lastProposed!).abs() <=
          math.max(1.0, widget.max - widget.min) * 1e-10;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      _finish(cancelled: true);
    }
  }

  void _cancelLater({ValueChanged<double>? callback}) {
    final notify = _active ? callback ?? widget.onChangeEnd : null;
    _active = _pressed = false;
    _lastProposed = null;
    if (notify != null) {
      final value = widget.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notify(value);
      });
    }
  }

  double _snap(double value) {
    final clamped = value.clamp(widget.min, widget.max);
    if (widget.divisions == null) return clamped;
    final tick =
        ((clamped - widget.min) / (widget.max - widget.min) * widget.divisions!)
            .round();
    return (widget.min + tick / widget.divisions! * (widget.max - widget.min))
        .clamp(widget.min, widget.max);
  }

  double get _thumbX {
    final span = math.max(1.0, _width - 36);
    final visual = Directionality.of(context) == TextDirection.rtl
        ? 1 - _fraction
        : _fraction;
    return 18 + visual * span;
  }

  double _grabOffsetAt(double x) {
    final delta = x - _thumbX;
    return delta.abs() <= 24 ? delta : 0;
  }

  double _at(double x) {
    final span = math.max(1.0, _width - 36);
    var fraction = ((x - 18 - _grabOffset) / span).clamp(0.0, 1.0);
    if (Directionality.of(context) == TextDirection.rtl) {
      fraction = 1 - fraction;
    }
    return _snap(widget.min + fraction * (widget.max - widget.min));
  }

  void _begin() {
    if (_active || !_interactive) return;
    _focusNode.requestFocus();
    setState(() {
      _active = _pressed = true;
      _lastProposed = widget.value;
    });
    LiquidGlassFeedback.tap(context);
    widget.onChangeStart?.call(widget.value);
  }

  void _propose(double next) {
    if (!_active || !_interactive || next == _lastProposed) return;
    final previous = _lastProposed;
    _lastProposed = next;
    final endpoint = next == widget.min || next == widget.max;
    if ((widget.divisions != null && widget.continuousFeedback) ||
        (endpoint && previous != next)) {
      LiquidGlassFeedback.selection(context);
    }
    widget.onChanged!(next);
  }

  void _finish({bool cancelled = false}) {
    if (!_active) {
      if (_pressed && mounted) setState(() => _pressed = false);
      return;
    }
    final value = cancelled ? widget.value : _lastProposed ?? widget.value;
    setState(() {
      _active = _pressed = false;
      _lastProposed = null;
    });
    widget.onChangeEnd?.call(value);
  }

  void _adjust(double next) {
    if (!_interactive) return;
    next = _snap(next);
    if (next == widget.value) return;
    if ((widget.divisions != null && widget.continuousFeedback) ||
        next == widget.min ||
        next == widget.max) {
      LiquidGlassFeedback.selection(context);
    }
    widget.onChangeStart?.call(widget.value);
    widget.onChanged!(next);
    widget.onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.value.isFinite && widget.min.isFinite && widget.max.isFinite);
    final next = _snap(widget.value + _increment);
    final previous = _snap(widget.value - _increment);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: widget.semanticLabel,
      value: _format(widget.value),
      enabled: _enabled,
      slider: true,
      increasedValue: _enabled && next > widget.value ? _format(next) : null,
      decreasedValue: _enabled && previous < widget.value
          ? _format(previous)
          : null,
      onIncrease: _enabled && next > widget.value ? () => _adjust(next) : null,
      onDecrease: _enabled && previous < widget.value
          ? () => _adjust(previous)
          : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: _enabled,
          focusNode: _focusNode,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): _ValueIntent(
              rtl ? -1 : 1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _ValueIntent(
              rtl ? 1 : -1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                const _ValueIntent(1),
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const _ValueIntent(-1),
            const SingleActivator(LogicalKeyboardKey.home): const _ValueIntent(
              -2,
            ),
            const SingleActivator(LogicalKeyboardKey.end): const _ValueIntent(
              2,
            ),
          },
          actions: {
            _ValueIntent: CallbackAction<_ValueIntent>(
              onInvoke: (intent) {
                _adjust(switch (intent.direction) {
                  -2 => widget.min,
                  2 => widget.max,
                  final direction => widget.value + direction * _increment,
                });
                return null;
              },
            ),
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.hasBoundedWidth ? constraints.maxWidth : 240;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragDown: _enabled
                    ? (details) =>
                          _grabOffset = _grabOffsetAt(details.localPosition.dx)
                    : null,
                onTapDown: _enabled
                    ? (_) => setState(() => _pressed = true)
                    : null,
                onTapUp: _enabled
                    ? (details) {
                        _begin();
                        _propose(_at(details.localPosition.dx));
                        _finish();
                      }
                    : null,
                onTapCancel: () {
                  if (!_active) setState(() => _pressed = false);
                },
                onHorizontalDragStart: _enabled
                    ? (details) {
                        _begin();
                        _propose(_at(details.localPosition.dx));
                      }
                    : null,
                onHorizontalDragUpdate: _enabled
                    ? (details) => _propose(_at(details.localPosition.dx))
                    : null,
                onHorizontalDragEnd: _enabled ? (_) => _finish() : null,
                onHorizontalDragCancel: () => _finish(cancelled: true),
                child: SizedBox(
                  width: _width,
                  height: 48,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: _pressed && !_reduced(context) ? 1.0 : 0.0,
                    ),
                    duration: _reduced(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 100),
                    builder: (context, press, _) => CustomPaint(
                      painter: _SliderPainter(
                        fraction: _fraction,
                        rtl: rtl,
                        enabled: _enabled,
                        focused: _focused,
                        press: press,
                        colors: _ValueColors.of(context, enabled: _enabled),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }
}

class _ValueIntent extends Intent {
  const _ValueIntent(this.direction);
  final int direction;
}

/// Independently painted switch retaining its focus node across theme changes.
class FallbackGlassSwitch extends StatefulWidget {
  const FallbackGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<FallbackGlassSwitch> createState() => _FallbackGlassSwitchState();
}

class _FallbackGlassSwitchState extends State<FallbackGlassSwitch>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  bool _focused = false, _pressed = false, _dragging = false;
  double _drag = 0;
  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!LiquidGlassFeedback.canInteract(context)) {
      _dragging = _pressed = false;
    }
  }

  @override
  void didUpdateWidget(FallbackGlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled || oldWidget.value != widget.value) {
      _dragging = _pressed = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) _reset();
  }

  void _reset() => setState(() => _dragging = _pressed = false);

  void _change(bool value) {
    if (!_enabled || !LiquidGlassFeedback.canInteract(context)) return;
    _focusNode.requestFocus();
    if (value == widget.value) return;
    LiquidGlassFeedback.selection(context);
    widget.onChanged!(value);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final fraction = _dragging ? _drag : (widget.value ? 1.0 : 0.0);
    return Semantics(
      label: widget.semanticLabel,
      enabled: _enabled,
      toggled: widget.value,
      onTap: _enabled ? () => _change(!widget.value) : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          focusNode: _focusNode,
          enabled: _enabled,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _change(!widget.value);
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTap: _enabled
                ? () {
                    _reset();
                    _change(!widget.value);
                  }
                : null,
            onTapCancel: () {
              if (!_dragging) _reset();
            },
            onHorizontalDragStart: _enabled
                ? (_) {
                    if (!LiquidGlassFeedback.canInteract(context)) return;
                    _focusNode.requestFocus();
                    setState(() {
                      _pressed = _dragging = true;
                      _drag = widget.value ? 1 : 0;
                    });
                  }
                : null,
            onHorizontalDragUpdate: _enabled
                ? (details) {
                    if (!_dragging) return;
                    setState(() {
                      _drag = (_drag + details.delta.dx / 24 * (rtl ? -1 : 1))
                          .clamp(0.0, 1.0);
                    });
                  }
                : null,
            onHorizontalDragEnd: _enabled
                ? (_) {
                    if (!_dragging) return;
                    final next = _drag >= .5;
                    _reset();
                    _change(next);
                  }
                : null,
            onHorizontalDragCancel: _reset,
            child: SizedBox(
              width: 60,
              height: 48,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: fraction, end: fraction),
                duration: _reduced(context) || _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, position, _) => CustomPaint(
                  painter: _SwitchPainter(
                    fraction: position,
                    rtl: rtl,
                    enabled: _enabled,
                    focused: _focused,
                    pressed: _pressed && !_reduced(context),
                    colors: _ValueColors.of(context, enabled: _enabled),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }
}

class FallbackGlassStepper extends StatelessWidget {
  const FallbackGlassStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
    required this.wraps,
    this.semanticLabel,
  });
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

  void _change(BuildContext context, int direction) {
    if (!_enabled(direction) || !LiquidGlassFeedback.canInteract(context)) {
      return;
    }
    LiquidGlassFeedback.tap(context);
    onChanged!(_next(direction));
  }

  @override
  Widget build(BuildContext context) {
    final increase = _enabled(1), decrease = _enabled(-1);
    final colors = _ValueColors.of(context);
    return Semantics(
      label: semanticLabel,
      value: _format(value),
      enabled: onChanged != null,
      increasedValue: increase ? _format(_next(1)) : null,
      decreasedValue: decrease ? _format(_next(-1)) : null,
      onIncrease: increase ? () => _change(context, 1) : null,
      onDecrease: decrease ? () => _change(context, -1) : null,
      child: ExcludeSemantics(
        child: LiquidGlassSurface(
          radius: 24,
          style: LiquidGlassSurfaceStyle.control,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepButton(
                key: const ValueKey('liquid-glass-stepper-decrease'),
                nextValue: _next(-1),
                onPressed: decrease ? () => onChanged!(_next(-1)) : null,
                direction: -1,
                color: colors.foreground,
              ),
              SizedBox(
                width: 1,
                height: 20,
                child: ColoredBox(
                  color: colors.foreground.withValues(alpha: .12),
                ),
              ),
              _StepButton(
                key: const ValueKey('liquid-glass-stepper-increase'),
                nextValue: _next(1),
                onPressed: increase ? () => onChanged!(_next(1)) : null,
                direction: 1,
                color: colors.foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.onPressed,
    required this.nextValue,
    required this.direction,
    required this.color,
  });
  final VoidCallback? onPressed;
  final double nextValue;
  final int direction;
  final Color color;
  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  Timer? _timer;
  bool _pressed = false, _focused = false, _holding = false;
  bool _awaitingFrame = false;
  double? _lastRequested;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!LiquidGlassFeedback.canInteract(context)) _stop();
  }

  @override
  void didUpdateWidget(_StepButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stop();
      if (mounted) setState(() {});
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _holding = _pressed = false;
    _lastRequested = null;
  }

  void _invoke({bool feedback = true}) {
    if (_awaitingFrame ||
        widget.onPressed == null ||
        !LiquidGlassFeedback.canInteract(context) ||
        (_holding && _lastRequested == widget.nextValue)) {
      return;
    }
    _focusNode.requestFocus();
    _awaitingFrame = true;
    _lastRequested = widget.nextValue;
    if (feedback) LiquidGlassFeedback.tap(context);
    widget.onPressed!();
    WidgetsBinding.instance.addPostFrameCallback((_) => _awaitingFrame = false);
    WidgetsBinding.instance.scheduleFrame();
  }

  void _repeat() {
    if (widget.onPressed == null || !LiquidGlassFeedback.canInteract(context)) {
      return;
    }
    setState(() => _holding = _pressed = true);
    LiquidGlassFeedback.longPress(context);
    _invoke(feedback: false);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (widget.onPressed == null ||
          !LiquidGlassFeedback.canInteract(context)) {
        _stop();
      } else {
        _invoke(feedback: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduced = _reduced(context);
    return FocusableActionDetector(
      enabled: enabled,
      focusNode: _focusNode,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _invoke();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(_stop);
                _invoke();
              }
            : null,
        onTapCancel: () {
          if (!_holding) setState(() => _pressed = false);
        },
        // GestureDetector's standard long-press recognizer starts at 500 ms.
        onLongPressStart: enabled ? (_) => _repeat() : null,
        onLongPressEnd: (_) => setState(_stop),
        onLongPressCancel: () => setState(_stop),
        onLongPressMoveUpdate: (details) {
          if (details.localPosition.dx < 0 ||
              details.localPosition.dx > 56 ||
              details.localPosition.dy < 0 ||
              details.localPosition.dy > 48) {
            setState(_stop);
          }
        },
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 100),
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: widget.color.withValues(
              alpha: _pressed || _focused ? .09 : 0,
            ),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _StepGlyphPainter(
                increment: widget.direction > 0,
                color: widget.color.withValues(alpha: enabled ? 1 : .38),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stop();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _ValueColors {
  const _ValueColors(
    this.accent,
    this.track,
    this.thumb,
    this.foreground,
    this.border,
    this.highlight,
    this.shadow,
  );
  factory _ValueColors.of(BuildContext context, {bool enabled = true}) {
    final palette = LiquidGlassTheme.of(context).colors;
    final scheme = Theme.of(context).colorScheme;
    Color tone(Color value) =>
        enabled ? value : value.withValues(alpha: value.a * .4);
    return _ValueColors(
      tone(palette.accent ?? scheme.primary),
      tone(palette.selection ?? scheme.onSurface.withValues(alpha: .16)),
      tone(palette.surfaceTint ?? scheme.surfaceContainerLowest),
      tone(palette.foreground ?? scheme.onSurface),
      tone(palette.border ?? scheme.onSurface.withValues(alpha: .15)),
      tone(palette.highlight ?? Colors.white.withValues(alpha: .75)),
      tone(palette.shadow ?? Colors.black.withValues(alpha: .18)),
    );
  }
  final Color accent, track, thumb, foreground, border, highlight, shadow;

  @override
  bool operator ==(Object other) =>
      other is _ValueColors &&
      accent == other.accent &&
      track == other.track &&
      thumb == other.thumb &&
      foreground == other.foreground &&
      border == other.border &&
      highlight == other.highlight &&
      shadow == other.shadow;

  @override
  int get hashCode =>
      Object.hash(accent, track, thumb, foreground, border, highlight, shadow);
}

void _drawThumb(Canvas canvas, RRect thumb, _ValueColors colors, bool focused) {
  canvas.drawShadow(Path()..addRRect(thumb), colors.shadow, 2, false);
  canvas.drawRRect(thumb, Paint()..color = colors.thumb);
  canvas.drawRRect(
    thumb.deflate(.5),
    Paint()
      ..color = focused ? colors.accent : colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 2 : 1,
  );
  canvas.drawLine(
    Offset(thumb.left + 10, thumb.top + 1),
    Offset(thumb.right - 10, thumb.top + 1),
    Paint()
      ..color = colors.highlight
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round,
  );
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.fraction,
    required this.rtl,
    required this.enabled,
    required this.focused,
    required this.press,
    required this.colors,
  });
  final double fraction, press;
  final bool rtl, enabled, focused;
  final _ValueColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final left = math.min(18.0, size.width / 2);
    final right = math.max(left, size.width - 18);
    final track = Rect.fromLTRB(
      left,
      size.height / 2 - 3,
      right,
      size.height / 2 + 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(3)),
      Paint()..color = colors.track,
    );
    final x = left + (right - left) * (rtl ? 1 - fraction : fraction);
    final active = Rect.fromLTRB(
      rtl ? x : left,
      track.top,
      rtl ? right : x,
      track.bottom,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(active, const Radius.circular(3)),
      Paint()..color = colors.accent,
    );
    _drawThumb(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: 32 + press * 4,
          height: 24 + press * 2,
        ),
        const Radius.circular(14),
      ),
      colors,
      focused,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      rtl != oldDelegate.rtl ||
      enabled != oldDelegate.enabled ||
      focused != oldDelegate.focused ||
      press != oldDelegate.press ||
      colors != oldDelegate.colors;
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({
    required this.fraction,
    required this.rtl,
    required this.enabled,
    required this.focused,
    required this.pressed,
    required this.colors,
  });
  final double fraction;
  final bool rtl, enabled, focused, pressed;
  final _ValueColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: 56, height: 32),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Color.lerp(colors.track, colors.accent, fraction)!,
    );
    final logical = rtl ? 1 - fraction : fraction;
    final x = track.left + 16 + 24 * logical;
    _drawThumb(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: pressed ? 29 : 26,
          height: 26,
        ),
        const Radius.circular(14),
      ),
      colors,
      focused,
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      rtl != oldDelegate.rtl ||
      enabled != oldDelegate.enabled ||
      focused != oldDelegate.focused ||
      pressed != oldDelegate.pressed ||
      colors != oldDelegate.colors;
}

class _StepGlyphPainter extends CustomPainter {
  const _StepGlyphPainter({required this.increment, required this.color});
  final bool increment;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(3, size.height / 2),
      Offset(size.width - 3, size.height / 2),
      paint,
    );
    if (increment) {
      canvas.drawLine(
        Offset(size.width / 2, 3),
        Offset(size.width / 2, size.height - 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StepGlyphPainter oldDelegate) =>
      increment != oldDelegate.increment || color != oldDelegate.color;
}
