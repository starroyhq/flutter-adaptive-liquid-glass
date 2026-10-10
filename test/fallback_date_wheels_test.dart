import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_date_wheels.dart';
import 'package:flutter_adaptive_liquid_glass/src/pickers.dart';
import 'package:flutter_adaptive_liquid_glass/src/theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  bool use24h = false,
  double textScale = 1,
  LiquidGlassFeedbackData feedback = const LiquidGlassFeedbackData(),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [
    Locale('en'),
    Locale('en', 'GB'),
    Locale('zh'),
    Locale('zh', 'TW'),
    Locale('ja'),
    Locale('ar'),
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      alwaysUse24HourFormat: use24h,
      textScaler: TextScaler.linear(textScale),
    ),
    child: LiquidGlassTheme(
      data: LiquidGlassThemeData(
        mode: LiquidGlassMode.fallback,
        feedback: feedback,
      ),
      child: child!,
    ),
  ),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 320, child: child)),
  ),
);

Finder _field(String name) => find.byKey(ValueKey('liquid-glass-date-$name'));

Semantics _semantics(WidgetTester tester, String name) =>
    tester.widget<Semantics>(
      find.descendant(of: _field(name), matching: find.byType(Semantics)).first,
    );

Future<void> _adjust(
  WidgetTester tester,
  String name, {
  bool increase = true,
}) async {
  final properties = _semantics(tester, name).properties;
  (increase ? properties.onIncrease : properties.onDecrease)!();
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final feedbackCalls = <MethodCall>[];
  setUp(() {
    feedbackCalls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate' ||
            call.method == 'SystemSound.play') {
          feedbackCalls.add(call);
        }
        return null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  testWidgets('SDK locale resources order package-owned date columns', (
    tester,
  ) async {
    for (final entry in <(Locale, List<String>)>[
      (const Locale('en'), ['month', 'day', 'year']),
      (const Locale('en', 'GB'), ['day', 'month', 'year']),
      (const Locale('zh'), ['year', 'month', 'day']),
      (const Locale('zh', 'TW'), ['year', 'month', 'day']),
      (const Locale('ja'), ['year', 'month', 'day']),
    ]) {
      await tester.pumpWidget(
        _app(
          LiquidGlassDatePicker(
            value: DateTime(2026, 10, 10),
            mode: LiquidGlassDatePickerMode.date,
            style: LiquidGlassDatePickerStyle.wheels,
            onChanged: (_) {},
          ),
          locale: entry.$1,
        ),
      );
      await tester.pumpAndSettle();
      final x = entry.$2
          .map((name) => tester.getCenter(_field(name)).dx)
          .toList();
      expect(x[0], lessThan(x[1]));
      expect(x[1], lessThan(x[2]));
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byType(FallbackDateWheels),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString().startsWith('Cupertino'),
          ),
        ),
        findsNothing,
      );
    }
  });

  testWidgets(
    'locale hour cycle, 24-hour override and AM PM preserve the date',
    (tester) async {
      var value = DateTime(2026, 10, 10, 0, 15);
      Widget picker() => StatefulBuilder(
        builder: (context, setState) => LiquidGlassDatePicker(
          value: value,
          mode: LiquidGlassDatePickerMode.time,
          style: LiquidGlassDatePickerStyle.wheels,
          onChanged: (date) => setState(() => value = date),
        ),
      );
      await tester.pumpWidget(_app(picker()));
      await tester.pumpAndSettle();
      expect(_field('period'), findsOneWidget);
      expect(_semantics(tester, 'hour').properties.value, '12');
      await _adjust(tester, 'period');
      expect(value, DateTime(2026, 10, 10, 12, 15));
      await tester.pumpWidget(_app(picker(), use24h: true));
      await tester.pumpAndSettle();
      expect(_field('period'), findsNothing);
      for (final (locale, hasPeriod) in [
        (const Locale('en', 'GB'), false),
        (const Locale('zh'), true),
        (const Locale('ja'), false),
      ]) {
        await tester.pumpWidget(_app(picker(), locale: locale));
        await tester.pumpAndSettle();
        expect(
          _field('period'),
          hasPeriod ? findsOneWidget : findsNothing,
          reason: '$locale',
        );
        if (hasPeriod) {
          expect(
            tester.getCenter(_field('period')).dx,
            lessThan(tester.getCenter(_field('hour')).dx),
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'year and month changes clamp invalid days and preserve UTC time',
    (tester) async {
      var value = DateTime(2024, 1, 31, 15, 12, 34).toUtc();
      final changes = <DateTime>[];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => LiquidGlassDatePicker(
              value: value,
              mode: LiquidGlassDatePickerMode.date,
              style: LiquidGlassDatePickerStyle.wheels,
              onChanged: (date) {
                changes.add(date);
                setState(() => value = date);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _adjust(tester, 'month');
      expect(value.toLocal(), DateTime(2024, 2, 29, 15, 12, 34));
      await _adjust(tester, 'year');
      expect(value.toLocal(), DateTime(2025, 2, 28, 15, 12, 34));
      expect(value.isUtc, isTrue);
      expect(changes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hour changes choose only minute-grid values within bounds', (
    tester,
  ) async {
    var value = DateTime(2026, 10, 10, 8);
    final changes = <DateTime>[];
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassDatePicker(
            value: value,
            mode: LiquidGlassDatePickerMode.time,
            minuteInterval: 15,
            minimumDate: DateTime(2026, 10, 10, 10, 7),
            maximumDate: DateTime(2026, 10, 10, 11, 14),
            onChanged: (date) {
              changes.add(date);
              setState(() => value = date);
            },
            style: LiquidGlassDatePickerStyle.wheels,
          ),
        ),
        use24h: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await _adjust(tester, 'hour');
    expect(value, DateTime(2026, 10, 10, 11));
    expect(_semantics(tester, 'minute').properties.onIncrease, isNull);
    expect(_semantics(tester, 'hour').properties.onIncrease, isNull);
    expect(changes, hasLength(1));
  });

  testWidgets(
    'real wheel scrolling emits once per changed value; echoes stay silent',
    (tester) async {
      var value = DateTime(2026, 10, 10);
      final changes = <DateTime>[];
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidGlassDatePicker(
                value: value,
                mode: LiquidGlassDatePickerMode.date,
                style: LiquidGlassDatePickerStyle.wheels,
                onChanged: (date) {
                  changes.add(date);
                  setState(() => value = date);
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(feedbackCalls, isEmpty);
      await tester.drag(_field('day'), const Offset(0, -96));
      await tester.pumpAndSettle();
      expect(value.day, greaterThan(10));
      expect(changes.toSet(), hasLength(changes.length));
      expect(
        feedbackCalls.where((call) => call.method == 'HapticFeedback.vibrate'),
        hasLength(changes.length),
      );
      expect(
        feedbackCalls.where((call) => call.method == 'SystemSound.play'),
        hasLength(changes.length),
      );
      final count = changes.length;
      final feedbackCount = feedbackCalls.length;
      update(() => value = DateTime(2026, 11, 22));
      await tester.pumpAndSettle();
      expect(changes, hasLength(count));
      expect(feedbackCalls, hasLength(feedbackCount));
      expect(_semantics(tester, 'day').properties.value, '22');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('external reset cancels an in-flight wheel gesture', (
    tester,
  ) async {
    var value = DateTime(2026, 10, 10);
    final changes = <DateTime>[];
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidGlassDatePicker(
              value: value,
              mode: LiquidGlassDatePickerMode.date,
              style: LiquidGlassDatePickerStyle.wheels,
              onChanged: (date) {
                changes.add(date);
                setState(() => value = date);
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(_field('day')));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    update(() => value = DateTime(2026, 12, 25));
    await tester.pump();
    final count = changes.length;
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(value, DateTime(2026, 12, 25));
    expect(changes, hasLength(count));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabled wheels and disabled feedback stay quiet',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _app(
          LiquidGlassDatePicker(
            value: DateTime(2026, 10, 10),
            mode: LiquidGlassDatePickerMode.date,
            style: LiquidGlassDatePickerStyle.wheels,
            onChanged: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        _field('day'),
        const Offset(0, -80),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(feedbackCalls, isEmpty);
      await tester.pumpWidget(
        _app(
          LiquidGlassDatePicker(
            value: DateTime(2026, 10, 10),
            mode: LiquidGlassDatePickerMode.date,
            style: LiquidGlassDatePickerStyle.wheels,
            onChanged: (_) => changes++,
          ),
          feedback: const LiquidGlassFeedbackData(haptics: false, sound: false),
        ),
      );
      await tester.pumpAndSettle();
      await _adjust(tester, 'day');
      expect(changes, 1);
      expect(feedbackCalls, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('keyboard adjustment retains focus through controlled echoes', (
    tester,
  ) async {
    var value = DateTime(2026, 10, 10, 10);
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassDatePicker(
            value: value,
            mode: LiquidGlassDatePickerMode.time,
            style: LiquidGlassDatePickerStyle.wheels,
            onChanged: (date) => setState(() => value = date),
          ),
        ),
        use24h: true,
      ),
    );
    await tester.pumpAndSettle();
    final wheel = find.descendant(
      of: _field('hour'),
      matching: find.byType(ListWheelScrollView),
    );
    Focus.of(tester.element(wheel)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(value.hour, 11);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(value.hour, 12);
    expect(Focus.of(tester.element(wheel)).hasFocus, isTrue);
  });

  testWidgets('backgrounding cancels a wheel gesture without a late change', (
    tester,
  ) async {
    var value = DateTime(2026, 10, 10);
    final changes = <DateTime>[];
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassDatePicker(
            value: value,
            mode: LiquidGlassDatePickerMode.date,
            style: LiquidGlassDatePickerStyle.wheels,
            onChanged: (date) {
              changes.add(date);
              setState(() => value = date);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(_field('day')));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    final count = changes.length;
    final feedbackCount = feedbackCalls.length;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(changes, hasLength(count));
    expect(feedbackCalls, hasLength(feedbackCount));
    expect(tester.takeException(), isNull);
  });

  testWidgets('covered and backgrounded wheels reject queued adjustments', (
    tester,
  ) async {
    final changes = <DateTime>[];
    await tester.pumpWidget(
      _app(
        LiquidGlassDatePicker(
          value: DateTime(2026, 10, 10),
          mode: LiquidGlassDatePickerMode.date,
          style: LiquidGlassDatePickerStyle.wheels,
          onChanged: changes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final queuedIncrease = _semantics(tester, 'day').properties.onIncrease!;
    final wheel = tester.widget<ListWheelScrollView>(
      find.descendant(
        of: _field('day'),
        matching: find.byType(ListWheelScrollView),
      ),
    );
    final controller = wheel.controller! as FixedExtentScrollController;
    final originalIndex = controller.selectedItem;
    final context = tester.element(_field('day'));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('Covered')),
    );
    await tester.pumpAndSettle();
    queuedIncrease();
    await tester.pumpAndSettle();
    expect(controller.selectedItem, originalIndex);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(controller.selectedItem, originalIndex);
    expect(_semantics(tester, 'day').properties.value, '10');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    queuedIncrease();
    await tester.pump();
    expect(controller.selectedItem, originalIndex);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.selectedItem, originalIndex);
    expect(changes, isEmpty);
    expect(feedbackCalls, isEmpty);
  });

  testWidgets(
    'RTL and large text keep wheels available without layout overflow',
    (tester) async {
      await tester.pumpWidget(
        _app(
          LiquidGlassDatePicker(
            value: DateTime(2026, 10, 10, 14, 15),
            style: LiquidGlassDatePickerStyle.wheels,
            onChanged: (_) {},
          ),
          locale: const Locale('ar'),
          textScale: 2.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(_field('hour'))),
        TextDirection.rtl,
      );
      expect(
        tester.getCenter(_field('hour')).dx,
        greaterThan(tester.getCenter(_field('minute')).dx),
      );
      expect(find.byType(ListWheelScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('DST fold minute edits retain the original occurrence', (
    tester,
  ) async {
    var value = DateTime.utc(2026, 11, 1, 6, 30);
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassDatePicker(
            value: value,
            mode: LiquidGlassDatePickerMode.time,
            style: LiquidGlassDatePickerStyle.wheels,
            minuteInterval: 15,
            onChanged: (date) => setState(() => value = date),
          ),
        ),
        use24h: true,
      ),
    );
    await tester.pumpAndSettle();
    await _adjust(tester, 'minute');
    expect(value, DateTime.utc(2026, 11, 1, 6, 45));
  });

  test('day-minute generation follows elapsed DST time and minute bounds', () {
    for (final day in [DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
      final end = DateTime(day.year, day.month, day.day + 1);
      final minutes = fallbackDateMinutes(day, interval: 15);
      expect(minutes, hasLength(end.difference(day).inMinutes ~/ 15));
      expect(
        minutes.every(
          (value) => DateUtils.isSameDay(value, day) && value.minute % 15 == 0,
        ),
        isTrue,
      );
      expect(
        minutes.map((value) => value.millisecondsSinceEpoch).toSet(),
        hasLength(minutes.length),
      );
      if (day.month == 3 && day.timeZoneOffset != end.timeZoneOffset) {
        expect(minutes.where((value) => value.hour == 2), isEmpty);
      }
      if (day.month == 11 && day.timeZoneOffset != end.timeZoneOffset) {
        expect(minutes.where((value) => value.hour == 1), hasLength(8));
      }
    }
  });
}
