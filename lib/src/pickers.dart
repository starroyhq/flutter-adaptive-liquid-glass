import 'dart:ui' show ColorSpace;

import 'package:flutter/material.dart';

import 'controls.dart';
import 'fallback_date_wheels.dart';
import 'fallback_pressable.dart';
import 'fallback_value_controls.dart';
import 'feedback.dart';
import 'native_picker.dart';
import 'presentation.dart';
import 'surface.dart';
import 'theme.dart';

enum LiquidGlassDatePickerMode { date, time, dateAndTime }

enum LiquidGlassDatePickerStyle { compact, inline, wheels }

/// A controlled picker displaying local calendar values on every platform.
///
/// Outputs preserve [value]'s UTC/local representation. Date-only changes keep
/// the existing local time; time-only changes keep the existing local date.
/// Time selections use [minuteInterval] with seconds cleared. Bounds for date
/// mode compare local dates; time modes compare instants on the minute grid.
class LiquidGlassDatePicker extends StatefulWidget {
  const LiquidGlassDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.mode = LiquidGlassDatePickerMode.dateAndTime,
    this.style = LiquidGlassDatePickerStyle.compact,
    this.minimumDate,
    this.maximumDate,
    this.minuteInterval = 1,
    this.locale,
    this.semanticLabel,
  });

  final DateTime value;
  final ValueChanged<DateTime>? onChanged;
  final LiquidGlassDatePickerMode mode;
  final LiquidGlassDatePickerStyle style;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final int minuteInterval;
  final Locale? locale;
  final String? semanticLabel;

  @override
  State<LiquidGlassDatePicker> createState() => _LiquidGlassDatePickerState();
}

class _LiquidGlassDatePickerState extends State<LiquidGlassDatePicker> {
  final _updates = ValueNotifier<int>(0);
  bool _presented = false;

  @override
  void didUpdateWidget(LiquidGlassDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updates.value++;
    });
  }

  void _changed(DateTime candidate) {
    if (!mounted || widget.onChanged == null) return;
    final result = _DatePolicy(widget).output(candidate);
    if (result != widget.value) widget.onChanged!(result);
  }

  Future<void> _open() async {
    if (_presented || widget.onChanged == null) return;
    _presented = true;
    try {
      await showLiquidGlassSheet<void>(
        context: context,
        initialDetent: LiquidGlassSheetDetent.large,
        builder: (context) => ValueListenableBuilder<int>(
          valueListenable: _updates,
          builder: (context, _, child) {
            if (!mounted) return const SizedBox.shrink();
            return _localized(
              context,
              SingleChildScrollView(
                primary: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DateEditor(
                      picker: widget,
                      currentPicker: () => widget,
                      style: LiquidGlassDatePickerStyle.inline,
                      onChanged: _changed,
                    ),
                    const SizedBox(height: 12),
                    LiquidGlassButton(
                      label: MaterialLocalizations.of(context).closeButtonLabel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _presented = false;
      if (!mounted) _updates.dispose();
    }
  }

  Widget _localized(BuildContext context, Widget child) => widget.locale == null
      ? child
      : Localizations.override(
          context: context,
          locale: widget.locale,
          child: child,
        );

  @override
  Widget build(BuildContext context) {
    final policy = _DatePolicy(widget);
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativePicker(
        kind: 'date',
        height: switch (widget.style) {
          LiquidGlassDatePickerStyle.compact => 48,
          LiquidGlassDatePickerStyle.wheels => 216,
          LiquidGlassDatePickerStyle.inline =>
            widget.mode == LiquidGlassDatePickerMode.time ? 216 : 390,
        },
        configuration: {
          'value': policy.display.millisecondsSinceEpoch,
          'mode': widget.mode.name,
          'style': widget.style.name,
          'minimumDate': policy.minimum?.millisecondsSinceEpoch,
          'maximumDate': policy.maximum?.millisecondsSinceEpoch,
          'minuteInterval': widget.minuteInterval,
          'locale': widget.locale?.toLanguageTag(),
          'enabled': widget.onChanged != null,
          'semanticLabel': widget.semanticLabel,
          'tint': LiquidGlassTheme.of(context).colors.accent?.toARGB32(),
        },
        onChanged: (value) {
          if (value is num && value.isFinite) {
            _changed(DateTime.fromMillisecondsSinceEpoch(value.toInt()));
          }
        },
      );
    }
    return _localized(
      context,
      Builder(
        builder: (context) {
          if (widget.style != LiquidGlassDatePickerStyle.compact) {
            return LiquidGlassSurface(
              child: _DateEditor(
                picker: widget,
                currentPicker: () => widget,
                style: widget.style,
                onChanged: _changed,
              ),
            );
          }
          final localizations = MaterialLocalizations.of(context);
          final date = localizations.formatMediumDate(policy.display);
          final time = localizations.formatTimeOfDay(
            TimeOfDay.fromDateTime(policy.display),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
          return LiquidGlassButton(
            label: switch (widget.mode) {
              LiquidGlassDatePickerMode.date => date,
              LiquidGlassDatePickerMode.time => time,
              LiquidGlassDatePickerMode.dateAndTime => '$date $time',
            },
            semanticLabel: widget.semanticLabel,
            icon: widget.mode == LiquidGlassDatePickerMode.time
                ? Icons.schedule
                : Icons.calendar_today_outlined,
            onPressed: widget.onChanged == null ? null : _open,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // A presented route can outlive its initiating widget during navigation.
    // It observes this notifier until its own exit and removes its listener.
    if (!_presented) _updates.dispose();
    super.dispose();
  }
}

class _DatePolicy {
  _DatePolicy(this.picker) {
    if (![
      1,
      2,
      3,
      4,
      5,
      6,
      10,
      12,
      15,
      20,
      30,
    ].contains(picker.minuteInterval)) {
      throw ArgumentError.value(picker.minuteInterval, 'minuteInterval');
    }
    final local = picker.value.toLocal();
    if (local.year < 1 || local.year > 9999) {
      throw ArgumentError.value(picker.value, 'value', 'Year must be 1–9999.');
    }
    final lower = picker.minimumDate?.toLocal();
    final upper = picker.maximumDate?.toLocal();
    for (final bound in [lower, upper]) {
      if (bound != null && (bound.year < 1 || bound.year > 9999)) {
        throw ArgumentError('Date bounds must use years 1–9999.');
      }
    }
    if (picker.mode == LiquidGlassDatePickerMode.date) {
      minimum = lower == null ? null : DateUtils.dateOnly(lower);
      maximum = upper == null ? null : DateUtils.dateOnly(upper);
    } else {
      minimum = lower == null ? null : _ceil(lower);
      maximum = upper == null ? null : _floor(upper);
      if (picker.mode == LiquidGlassDatePickerMode.time) {
        final dayStart = DateUtils.dateOnly(local);
        final dayEnd = DateTime(local.year, local.month, local.day, 23, 59);
        if (minimum == null || minimum!.isBefore(dayStart)) minimum = dayStart;
        if (maximum == null || maximum!.isAfter(dayEnd)) {
          maximum = _floor(dayEnd);
        }
      }
    }
    if (minimum != null && maximum != null && minimum!.isAfter(maximum!)) {
      throw ArgumentError('The date range contains no selectable value.');
    }
    display = normalize(local);
  }

  final LiquidGlassDatePicker picker;
  late final DateTime display;
  DateTime? minimum;
  DateTime? maximum;

  // Walk actual minutes without reconstructing wall time: folds must retain
  // their occurrence, and a DST offset change need not divide the interval.
  DateTime _minuteStart(DateTime date) => date.subtract(
    Duration(
      seconds: date.second,
      milliseconds: date.millisecond,
      microseconds: date.microsecond,
    ),
  );

  DateTime _floor(DateTime date) {
    var result = _minuteStart(date);
    while (result.minute % picker.minuteInterval != 0) {
      result = result.subtract(const Duration(minutes: 1));
    }
    return result;
  }

  DateTime _ceil(DateTime date) {
    var result = _minuteStart(date);
    if (result.isBefore(date)) result = result.add(const Duration(minutes: 1));
    while (result.minute % picker.minuteInterval != 0) {
      result = result.add(const Duration(minutes: 1));
    }
    return result;
  }

  DateTime normalize(DateTime candidate) {
    candidate = candidate.toLocal();
    final original = picker.value.toLocal();
    var result = switch (picker.mode) {
      LiquidGlassDatePickerMode.date => DateUtils.dateOnly(candidate),
      LiquidGlassDatePickerMode.time => _floor(
        DateUtils.isSameDay(candidate, original)
            ? candidate
            : DateTime(
                original.year,
                original.month,
                original.day,
                candidate.hour,
                candidate.minute,
              ),
      ),
      LiquidGlassDatePickerMode.dateAndTime => _floor(candidate),
    };
    if (minimum != null && result.isBefore(minimum!)) result = minimum!;
    if (maximum != null && result.isAfter(maximum!)) result = maximum!;
    return result;
  }

  DateTime output(DateTime candidate) {
    var result = normalize(candidate);
    if (picker.mode == LiquidGlassDatePickerMode.date) {
      final original = picker.value.toLocal();
      if (DateUtils.isSameDay(result, original)) return picker.value;
      result = DateTime(
        result.year,
        result.month,
        result.day,
        original.hour,
        original.minute,
        original.second,
        original.millisecond,
        original.microsecond,
      );
    }
    return picker.value.isUtc ? result.toUtc() : result;
  }
}

class _DateEditor extends StatefulWidget {
  const _DateEditor({
    required this.picker,
    required this.style,
    required this.onChanged,
    required this.currentPicker,
  });

  final LiquidGlassDatePicker picker;
  final LiquidGlassDatePickerStyle style;
  final ValueChanged<DateTime> onChanged;
  final LiquidGlassDatePicker Function() currentPicker;

  @override
  State<_DateEditor> createState() => _DateEditorState();
}

class _DateEditorState extends State<_DateEditor> {
  late DateTime _display = _DatePolicy(widget.picker).display;
  int _revision = 0;

  @override
  void didUpdateWidget(_DateEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final display = _DatePolicy(widget.picker).display;
    if (display != _display ||
        oldWidget.picker.mode != widget.picker.mode ||
        oldWidget.picker.minuteInterval != widget.picker.minuteInterval ||
        oldWidget.picker.minimumDate != widget.picker.minimumDate ||
        oldWidget.picker.maximumDate != widget.picker.maximumDate ||
        oldWidget.picker.locale != widget.picker.locale) {
      _display = display;
      _revision++;
    }
  }

  void _select(DateTime date) {
    if (widget.picker.onChanged == null) return;
    final selected = _DatePolicy(widget.picker).normalize(date);
    setState(() => _display = selected);
    widget.onChanged(selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = _DatePolicy(widget.currentPicker()).display;
      if (_display != accepted) {
        setState(() {
          _display = accepted;
          _revision++;
        });
      }
    });
  }

  Widget _wheels(BuildContext context, {bool timeOnly = false}) {
    final picker = widget.picker;
    final policy = _DatePolicy(picker);
    final mode = timeOnly
        ? FallbackDateWheelMode.time
        : switch (picker.mode) {
            LiquidGlassDatePickerMode.date => FallbackDateWheelMode.date,
            LiquidGlassDatePickerMode.time => FallbackDateWheelMode.time,
            LiquidGlassDatePickerMode.dateAndTime =>
              FallbackDateWheelMode.dateAndTime,
          };
    return FallbackDateWheels(
      key: ValueKey(('wheels', _revision, timeOnly, mode)),
      value: _display,
      mode: mode,
      enabled: picker.onChanged != null,
      minimumDate: policy.minimum,
      maximumDate: policy.maximum,
      minuteInterval: picker.mode == LiquidGlassDatePickerMode.date
          ? 1
          : picker.minuteInterval,
      onChanged: _select,
    );
  }

  @override
  Widget build(BuildContext context) {
    final picker = widget.picker;
    final policy = _DatePolicy(picker);
    final palette = LiquidGlassTheme.of(context).colors;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme.copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      onSurface: palette.foreground,
      surface: palette.surfaceTint,
    );
    final wheels =
        widget.style == LiquidGlassDatePickerStyle.wheels ||
        picker.mode == LiquidGlassDatePickerMode.time;
    final editor = wheels
        ? _wheels(context)
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalendarDatePicker(
                key: ValueKey(('calendar', _revision)),
                initialDate: _display,
                firstDate: policy.minimum ?? DateTime(1),
                lastDate: policy.maximum ?? DateTime(9999, 12, 31),
                onDateChanged: (date) {
                  // Calendar changes preserve the currently chosen time.
                  _select(
                    DateTime(
                      date.year,
                      date.month,
                      date.day,
                      _display.hour,
                      _display.minute,
                    ),
                  );
                  // CalendarDatePicker never adopts a new initialDate, so
                  // remount it only when the accepted day differs from the
                  // tapped one (a bound clamped it). Remounting on every tap
                  // would drop keyboard focus and the displayed month/year view.
                  if (!DateUtils.isSameDay(_display, date)) {
                    setState(() => _revision++);
                  }
                },
              ),
              if (picker.mode == LiquidGlassDatePickerMode.dateAndTime)
                _wheels(context, timeOnly: true),
            ],
          );
    return Semantics(
      label: picker.semanticLabel,
      enabled: picker.onChanged != null,
      child: ExcludeSemantics(
        excluding: picker.onChanged == null,
        child: ExcludeFocus(
          excluding: picker.onChanged == null,
          child: IgnorePointer(
            ignoring: picker.onChanged == null,
            child: Opacity(
              opacity: picker.onChanged == null ? .48 : 1,
              child: Theme(
                data: theme.copyWith(colorScheme: scheme),
                child: editor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A controlled sRGB color well. Edits are delivered continuously; closing the
/// palette never commits a second value. A null callback disables the well.
class LiquidGlassColorPicker extends StatefulWidget {
  const LiquidGlassColorPicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
    this.title,
    this.supportsAlpha = true,
    this.semanticLabel,
  });

  final Color selectedColor;
  final ValueChanged<Color>? onChanged;

  /// Heading for the presented color picker. The Flutter fallback also uses
  /// this as its well label when [semanticLabel] is absent.
  final String? title;
  final bool supportsAlpha;

  /// Accessibility label for the color well, independent of the picker title.
  /// Omitting it retains the native system label on the native path.
  final String? semanticLabel;

  @override
  State<LiquidGlassColorPicker> createState() => _LiquidGlassColorPickerState();
}

class _LiquidGlassColorPickerState extends State<LiquidGlassColorPicker> {
  final _updates = ValueNotifier<int>(0);
  bool _presented = false;

  Color get _color => widget.supportsAlpha
      ? widget.selectedColor.withValues(colorSpace: ColorSpace.sRGB)
      : widget.selectedColor.withValues(colorSpace: ColorSpace.sRGB, alpha: 1);

  @override
  void didUpdateWidget(LiquidGlassColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updates.value++;
    });
  }

  void _changed(Color color) {
    if (!mounted || widget.onChanged == null) return;
    color = widget.supportsAlpha ? color : color.withValues(alpha: 1);
    if (color.toARGB32() != _color.toARGB32()) widget.onChanged!(color);
  }

  Future<void> _open() async {
    if (!mounted ||
        _presented ||
        widget.onChanged == null ||
        !LiquidGlassFeedback.canInteract(context)) {
      return;
    }
    _presented = true;
    try {
      await showLiquidGlassSheet<void>(
        context: context,
        initialDetent: LiquidGlassSheetDetent.large,
        builder: (context) => ValueListenableBuilder<int>(
          valueListenable: _updates,
          builder: (context, _, child) => mounted
              ? _ColorEditor(
                  color: _color,
                  enabled: widget.onChanged != null,
                  supportsAlpha: widget.supportsAlpha,
                  title: widget.title,
                  onChanged: _changed,
                  currentColor: () => _color,
                )
              : const SizedBox.shrink(),
        ),
      );
    } finally {
      _presented = false;
      if (!mounted) _updates.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
      return NativePicker(
        kind: 'color',
        height: 48,
        width: 48,
        configuration: {
          'value': _color.toARGB32(),
          'enabled': widget.onChanged != null,
          'supportsAlpha': widget.supportsAlpha,
          'title': widget.title,
          'semanticLabel': widget.semanticLabel,
          'tint': LiquidGlassTheme.of(context).colors.accent?.toARGB32(),
        },
        onChanged: (value) {
          if (value is int) _changed(Color(value));
        },
      );
    }
    final hex = _hex(_color, widget.supportsAlpha);
    return Semantics(
      button: true,
      enabled: widget.onChanged != null,
      label: widget.semanticLabel ?? widget.title ?? 'Color',
      value: hex,
      onTap: widget.onChanged == null ? null : _open,
      child: ExcludeSemantics(
        child: LiquidGlassSurface(
          style: LiquidGlassSurfaceStyle.control,
          child: Material(
            type: MaterialType.transparency,
            child: FallbackPressable(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onChanged == null ? null : _open,
              child: Opacity(
                opacity: widget.onChanged == null ? .48 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 24,
                        child: CustomPaint(painter: _ColorSample(_color)),
                      ),
                      if (widget.title != null) ...[
                        const SizedBox(width: 8),
                        Flexible(child: Text(widget.title!)),
                      ],
                    ],
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
    if (!_presented) _updates.dispose();
    super.dispose();
  }
}

String _hex(Color color, bool alpha) {
  final argb = color.toARGB32();
  final rgb = (argb & 0xffffff).toRadixString(16).padLeft(6, '0');
  final a = (argb >>> 24).toRadixString(16).padLeft(2, '0');
  return '#${rgb.toUpperCase()}${alpha ? a.toUpperCase() : ''}';
}

class _ColorEditor extends StatefulWidget {
  const _ColorEditor({
    required this.color,
    required this.enabled,
    required this.supportsAlpha,
    required this.onChanged,
    required this.currentColor,
    this.title,
  });
  final Color color;
  final bool enabled;
  final bool supportsAlpha;
  final ValueChanged<Color> onChanged;
  final Color Function() currentColor;
  final String? title;

  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  late Color _color = widget.color;
  late final _hexController = TextEditingController(
    text: _hex(_color, widget.supportsAlpha),
  );
  String? _hexError;

  @override
  void didUpdateWidget(_ColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color.toARGB32() != _color.toARGB32() ||
        oldWidget.supportsAlpha != widget.supportsAlpha) {
      _color = widget.color;
      _hexController.text = _hex(_color, widget.supportsAlpha);
      _hexError = null;
    }
  }

  void _change(Color color, {bool updateText = true}) {
    if (!widget.enabled) return;
    if (!widget.supportsAlpha) color = color.withValues(alpha: 1);
    final changed = color.toARGB32() != _color.toARGB32();
    setState(() {
      _color = color;
      _hexError = null;
      if (updateText) _hexController.text = _hex(color, widget.supportsAlpha);
    });
    if (changed) widget.onChanged(color);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = widget.currentColor();
      if (accepted.toARGB32() != _color.toARGB32()) {
        setState(() {
          _color = accepted;
          _hexController.text = _hex(accepted, widget.supportsAlpha);
        });
      }
    });
  }

  void _parseHex(String text) {
    final raw = text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(raw)) {
      setState(() => _hexError = 'Use RRGGBB or RRGGBBAA');
      return;
    }
    final rgb = int.parse(raw.substring(0, 6), radix: 16);
    final alpha = raw.length == 8 && widget.supportsAlpha
        ? int.parse(raw.substring(6), radix: 16)
        : 255;
    _change(Color((alpha << 24) | rgb), updateText: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = LiquidGlassTheme.of(context).colors;
    final scheme = Theme.of(context).colorScheme;
    final foreground = palette.foreground ?? scheme.onSurface;
    final channels = [
      ('R', (_color.r * 255).round()),
      ('G', (_color.g * 255).round()),
      ('B', (_color.b * 255).round()),
      if (widget.supportsAlpha) ('A', (_color.a * 255).round()),
    ];
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(widget.title!, style: TextStyle(color: foreground)),
            ),
          Semantics(
            label: _hex(_color, widget.supportsAlpha),
            child: SizedBox(
              height: 48,
              child: CustomPaint(painter: _ColorSample(_color)),
            ),
          ),
          for (var i = 0; i < channels.length; i++)
            Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    channels[i].$1,
                    style: TextStyle(color: foreground),
                  ),
                ),
                Expanded(
                  child: FallbackGlassSlider(
                    key: ValueKey('liquid-glass-color-${channels[i].$1}'),
                    value: channels[i].$2.toDouble(),
                    max: 255,
                    divisions: 255,
                    continuousFeedback: false,
                    semanticFormatterCallback: (value) =>
                        '${channels[i].$1} ${value.round()}',
                    onChanged: widget.enabled
                        ? (value) {
                            final parts = [
                              (_color.r * 255).round(),
                              (_color.g * 255).round(),
                              (_color.b * 255).round(),
                              (_color.a * 255).round(),
                            ];
                            parts[i] = value.round();
                            _change(
                              Color.fromARGB(
                                parts[3],
                                parts[0],
                                parts[1],
                                parts[2],
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${channels[i].$2}',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: foreground),
                  ),
                ),
              ],
            ),
          TextField(
            key: const ValueKey('liquid-glass-color-hex'),
            controller: _hexController,
            enabled: widget.enabled,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(color: foreground),
            cursorColor: palette.accent ?? scheme.primary,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: widget.supportsAlpha
                  ? 'HEX (RRGGBBAA)'
                  : 'HEX (RRGGBB)',
              errorText: _hexError,
            ),
            onChanged: _parseHex,
          ),
          const SizedBox(height: 16),
          LiquidGlassButton(
            label: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }
}

class _ColorSample extends CustomPainter {
  const _ColorSample(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += 8) {
      for (var x = 0.0; x < size.width; x += 8) {
        paint.color = ((x / 8).floor() + (y / 8).floor()).isEven
            ? const Color(0xffeeeeee)
            : const Color(0xffbbbbbb);
        canvas.drawRect(Rect.fromLTWH(x, y, 8, 8), paint);
      }
    }
    canvas.drawRect(rect, paint..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ColorSample oldDelegate) => color != oldDelegate.color;
}
