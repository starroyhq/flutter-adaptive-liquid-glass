import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DatePickerDateOrder, DatePickerDateTimeOrder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';
import 'theme.dart';

enum FallbackDateWheelMode { date, time, dateAndTime }

/// The selectable instants on one local day, including both sides of a DST
/// fold. Walking elapsed minutes skips nonexistent wall times in a spring gap.
List<DateTime> fallbackDateMinutes(
  DateTime day, {
  required int interval,
  DateTime? minimum,
  DateTime? maximum,
}) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  return [
    for (
      var date = start;
      date.isBefore(end);
      date = date.add(const Duration(minutes: 1))
    )
      if (date.minute % interval == 0 &&
          (minimum == null || !date.isBefore(minimum)) &&
          (maximum == null || !date.isAfter(maximum)))
        date,
  ];
}

int _dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime _dayFromNumber(int number) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    number * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

/// Package-owned wheels; only localized strings and date ordering come from
/// the SDK's Cupertino resources. No Cupertino control is instantiated.
class FallbackDateWheels extends StatelessWidget {
  const FallbackDateWheels({
    super.key,
    required this.value,
    required this.mode,
    required this.onChanged,
    this.minimumDate,
    this.maximumDate,
    this.minuteInterval = 1,
    this.enabled = true,
  });

  final DateTime value;
  final FallbackDateWheelMode mode;
  final ValueChanged<DateTime> onChanged;
  final DateTime? minimumDate, maximumDate;
  final int minuteInterval;
  final bool enabled;

  DateTime _nearest(List<DateTime> options, int hour, int minute) {
    if (options.isEmpty) return value;
    final target = hour * 60 + minute;
    int compare(DateTime a, DateTime b) {
      final wall = (a.hour * 60 + a.minute - target).abs().compareTo(
        (b.hour * 60 + b.minute - target).abs(),
      );
      if (wall != 0) return wall;
      final offset = (a.timeZoneOffset == value.timeZoneOffset ? 0 : 1)
          .compareTo(b.timeZoneOffset == value.timeZoneOffset ? 0 : 1);
      if (offset != 0) return offset;
      return a.difference(value).abs().compareTo(b.difference(value).abs());
    }

    return options.reduce((a, b) => compare(a, b) <= 0 ? a : b);
  }

  List<DateTime> _minutes(DateTime day) => fallbackDateMinutes(
    day,
    interval: minuteInterval,
    minimum: minimumDate,
    maximum: maximumDate,
  );

  bool _emit(DateTime candidate) {
    if (!enabled || candidate == value) return false;
    onChanged(candidate);
    return true;
  }

  bool _date({int? year, int? month, int? day}) {
    final lower = minimumDate ?? DateTime(1);
    final upper = maximumDate ?? DateTime(9999, 12, 31);
    final y = (year ?? value.year).clamp(lower.year, upper.year);
    final m = (month ?? value.month).clamp(
      y == lower.year ? lower.month : 1,
      y == upper.year ? upper.month : 12,
    );
    final d = (day ?? value.day).clamp(
      y == lower.year && m == lower.month ? lower.day : 1,
      y == upper.year && m == upper.month
          ? upper.day
          : DateUtils.getDaysInMonth(y, m),
    );
    return _emit(DateTime(y, m, d));
  }

  @override
  Widget build(BuildContext context) {
    final strings = CupertinoLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final columns = <_WheelSpec>[];
    if (mode == FallbackDateWheelMode.date) {
      final lower = minimumDate ?? DateTime(1);
      final upper = maximumDate ?? DateTime(9999, 12, 31);
      final monthStart = value.year == lower.year ? lower.month : 1;
      final monthEnd = value.year == upper.year ? upper.month : 12;
      final dayStart = value.year == lower.year && value.month == lower.month
          ? lower.day
          : 1;
      final dayEnd = value.year == upper.year && value.month == upper.month
          ? upper.day
          : DateUtils.getDaysInMonth(value.year, value.month);
      final fields = <String, _WheelSpec>{
        'year': _WheelSpec(
          'year',
          (lower.year, upper.year),
          upper.year - lower.year + 1,
          value.year - lower.year,
          76,
          material.selectYearSemanticsLabel,
          (index) => strings.datePickerYear(index + lower.year),
          (index) => _date(year: index + lower.year),
        ),
        'month': _WheelSpec(
          'month',
          (value.year, monthStart, monthEnd),
          monthEnd - monthStart + 1,
          value.month - monthStart,
          100,
          material.datePickerHelpText,
          (index) => strings.datePickerMonth(index + monthStart),
          (index) => _date(month: index + monthStart),
        ),
        'day': _WheelSpec(
          'day',
          (value.year, value.month, dayStart, dayEnd),
          dayEnd - dayStart + 1,
          value.day - dayStart,
          52,
          material.datePickerHelpText,
          (index) => strings.datePickerDayOfMonth(index + dayStart),
          (index) => _date(day: index + dayStart),
        ),
      };
      final order = switch (strings.datePickerDateOrder) {
        DatePickerDateOrder.dmy => ['day', 'month', 'year'],
        DatePickerDateOrder.mdy => ['month', 'day', 'year'],
        DatePickerDateOrder.ymd => ['year', 'month', 'day'],
        DatePickerDateOrder.ydm => ['year', 'day', 'month'],
      };
      columns.addAll(order.map((field) => fields[field]!));
    } else {
      final format = material.timeOfDayFormat(
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      final use24h =
          format != TimeOfDayFormat.h_colon_mm_space_a &&
          format != TimeOfDayFormat.a_space_h_colon_mm;
      final minutes = _minutes(value);
      final day = _dayNumber(value);
      final periods = minutes.map((date) => date.hour ~/ 12).toSet().toList()
        ..sort();
      final hours =
          minutes
              .where((date) => use24h || date.hour ~/ 12 == value.hour ~/ 12)
              .map((date) => date.hour)
              .toSet()
              .toList()
            ..sort();
      final minuteValues =
          minutes
              .where((date) => date.hour == value.hour)
              .map((date) => date.minute)
              .toSet()
              .toList()
            ..sort();
      // Policies guarantee a nonempty selectable range; a skipped local date
      // can nevertheless have no instants and should remain noninteractive.
      if (hours.isEmpty || minuteValues.isEmpty) return const SizedBox.shrink();
      final hour = _WheelSpec(
        'hour',
        (day, use24h, hours.join(',')),
        hours.length,
        hours.indexOf(value.hour),
        52,
        material.timePickerHourLabel,
        (index) => material.formatHour(
          TimeOfDay(hour: hours[index], minute: 0),
          alwaysUse24HourFormat: use24h,
        ),
        (index) => _emit(
          _nearest(
            minutes.where((date) => date.hour == hours[index]).toList(),
            hours[index],
            value.minute,
          ),
        ),
      );
      final minute = _WheelSpec(
        'minute',
        (day, value.hour, minuteValues.join(',')),
        minuteValues.length,
        minuteValues.indexOf(value.minute),
        52,
        material.timePickerMinuteLabel,
        (index) => strings.datePickerMinute(minuteValues[index]),
        (index) => _emit(
          _nearest(
            minutes.where((date) => date.hour == value.hour).toList(),
            value.hour,
            minuteValues[index],
          ),
        ),
      );
      final period = _WheelSpec(
        'period',
        (day, periods.join(',')),
        periods.length,
        periods.indexOf(value.hour ~/ 12),
        56,
        material.timePickerDialHelpText,
        (index) => periods[index] == 0
            ? material.anteMeridiemAbbreviation
            : material.postMeridiemAbbreviation,
        (index) => _emit(
          _nearest(
            minutes.where((date) => date.hour ~/ 12 == periods[index]).toList(),
            value.hour % 12 + periods[index] * 12,
            value.minute,
          ),
        ),
      );
      columns.addAll([
        if (!use24h && format == TimeOfDayFormat.a_space_h_colon_mm) period,
        hour,
        minute,
        if (!use24h && format != TimeOfDayFormat.a_space_h_colon_mm) period,
      ]);
      if (mode == FallbackDateWheelMode.dateAndTime) {
        final start = _dayNumber(minimumDate ?? DateTime(1));
        final end = _dayNumber(maximumDate ?? DateTime(9999, 12, 31));
        final date = _WheelSpec(
          'date',
          (start, end),
          end - start + 1,
          day - start,
          148,
          material.datePickerHelpText,
          (index) =>
              strings.datePickerMediumDate(_dayFromNumber(index + start)),
          (index) => _emit(
            _nearest(
              _minutes(_dayFromNumber(index + start)),
              value.hour,
              value.minute,
            ),
          ),
        );
        switch (strings.datePickerDateTimeOrder) {
          case DatePickerDateTimeOrder.date_time_dayPeriod:
          case DatePickerDateTimeOrder.date_dayPeriod_time:
            columns.insert(0, date);
          case DatePickerDateTimeOrder.time_dayPeriod_date:
          case DatePickerDateTimeOrder.dayPeriod_time_date:
            columns.add(date);
        }
      }
    }
    final palette = LiquidGlassTheme.of(context).colors;
    final scale = MediaQuery.textScalerOf(context).scale(20) / 20;
    final extent = math.max(40.0, 20 * scale + 16);
    final minimumWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width) * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth.isFinite ? constraints.maxWidth : minimumWidth,
          minimumWidth,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: extent * 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: extent,
                    decoration: BoxDecoration(
                      color:
                          palette.selection ??
                          Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final column in columns)
                      Expanded(
                        flex: column.width.round(),
                        child: _DateWheelColumn(
                          key: ValueKey('liquid-glass-date-${column.name}'),
                          spec: column,
                          extent: extent,
                          enabled: enabled,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WheelSpec {
  const _WheelSpec(
    this.name,
    this.identity,
    this.count,
    this.selected,
    this.width,
    this.label,
    this.text,
    this.select,
  );
  final String name, label;
  final Object identity;
  final int count, selected;
  final double width;
  final String Function(int) text;
  final bool Function(int) select;
}

class _DateWheelColumn extends StatefulWidget {
  const _DateWheelColumn({
    super.key,
    required this.spec,
    required this.extent,
    required this.enabled,
  });
  final _WheelSpec spec;
  final double extent;
  final bool enabled;
  @override
  State<_DateWheelColumn> createState() => _DateWheelColumnState();
}

class _DateWheelColumnState extends State<_DateWheelColumn>
    with WidgetsBindingObserver {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.spec.selected,
  );
  late int _selected = widget.spec.selected;
  bool _userScroll = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!LiquidGlassFeedback.canInteract(context)) _cancelScroll();
  }

  void _cancelScroll() {
    _userScroll = false;
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == _revision && _controller.hasClients) {
        _controller.jumpToItem(widget.spec.selected);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancelScroll();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_DateWheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spec.selected != _selected ||
        widget.spec.identity != oldWidget.spec.identity ||
        widget.extent != oldWidget.extent ||
        widget.enabled != oldWidget.enabled) {
      _selected = widget.spec.selected;
      _userScroll = false;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _revision && _controller.hasClients) {
          _controller.jumpToItem(widget.spec.selected);
        }
      });
    }
  }

  void _select(int index) {
    if (!widget.enabled ||
        !LiquidGlassFeedback.canInteract(context) ||
        index < 0 ||
        index >= widget.spec.count ||
        index == _selected) {
      return;
    }
    setState(() => _selected = index);
    if (widget.spec.select(index)) LiquidGlassFeedback.wheel(context);
  }

  void _adjust(int delta) {
    if (!widget.enabled || !LiquidGlassFeedback.canInteract(context)) return;
    _userScroll = false;
    final index = (_selected + delta).clamp(0, widget.spec.count - 1);
    _select(index);
    if (_controller.hasClients) _controller.jumpToItem(index);
  }

  @override
  Widget build(BuildContext context) {
    final revision = _revision;
    final spec = widget.spec;
    final canInteract =
        widget.enabled && LiquidGlassFeedback.canInteract(context);
    final palette = LiquidGlassTheme.of(context).colors;
    final foreground =
        palette.foreground ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: spec.label,
      value: spec.text(_selected.clamp(0, spec.count - 1)),
      enabled: widget.enabled,
      increasedValue: widget.enabled && _selected + 1 < spec.count
          ? spec.text(_selected + 1)
          : null,
      decreasedValue: widget.enabled && _selected > 0
          ? spec.text(_selected - 1)
          : null,
      onIncrease: widget.enabled && _selected + 1 < spec.count
          ? () => _adjust(1)
          : null,
      onDecrease: widget.enabled && _selected > 0 ? () => _adjust(-1) : null,
      child: Focus(
        canRequestFocus: widget.enabled,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _adjust(event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ExcludeSemantics(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _userScroll = true;
              }
              if (notification is ScrollEndNotification) _userScroll = false;
              return false;
            },
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.extent,
              diameterRatio: 2.4,
              perspective: .002,
              physics: canInteract
                  ? const FixedExtentScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onSelectedItemChanged: (index) {
                if (revision == _revision && _userScroll) _select(index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: spec.count,
                builder: (context, index) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      spec.text(index),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 20,
                        color: index == _selected
                            ? palette.selectedForeground ?? foreground
                            : foreground.withValues(alpha: foreground.a * .5),
                      ),
                    ),
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
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }
}
