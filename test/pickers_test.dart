import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_picker.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_date_wheels.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_value_controls.dart';
import 'package:flutter_adaptive_liquid_glass/src/pickers.dart';
import 'package:flutter_adaptive_liquid_glass/src/theme.dart';

Widget _app(
  Widget child, {
  LiquidGlassColors colors = const LiquidGlassColors(),
}) => LiquidGlassTheme(
  data: LiquidGlassThemeData(mode: LiquidGlassMode.fallback, colors: colors),
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('date selections retain local time and UTC representation', (
    tester,
  ) async {
    final local = DateTime(2026, 10, 10, 15, 23, 12, 34, 56);
    var value = local.toUtc();
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassDatePicker(
            value: value,
            mode: LiquidGlassDatePickerMode.date,
            style: LiquidGlassDatePickerStyle.inline,
            onChanged: (date) => setState(() => value = date),
          ),
        ),
      ),
    );
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 10, 12));
    await tester.pumpAndSettle();
    expect(value.isUtc, isTrue);
    expect(value.toLocal(), DateTime(2026, 10, 12, 15, 23, 12, 34, 56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('time selections preserve local date and round to minute grid', (
    tester,
  ) async {
    var value = DateTime(2026, 10, 10, 10, 0);
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
      ),
    );
    tester
        .widget<FallbackDateWheels>(find.byType(FallbackDateWheels))
        .onChanged(DateTime(2030, 2, 3, 17, 47, 9));
    await tester.pumpAndSettle();
    expect(value, DateTime(2026, 10, 10, 17, 45));
    expect(value.isUtc, isFalse);
  });

  testWidgets('minute snapping preserves the instant through a DST fold', (
    tester,
  ) async {
    // In America/New_York this is the second 01:xx hour on the autumn fold.
    // Run this suite with TZ=America/New_York as well as the host time zone.
    for (final mode in [
      LiquidGlassDatePickerMode.date,
      LiquidGlassDatePickerMode.time,
      LiquidGlassDatePickerMode.dateAndTime,
    ]) {
      var value = DateTime.utc(2026, 11, 1, 6, 37);
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            key: ValueKey(mode),
            builder: (context, setState) => LiquidGlassDatePicker(
              value: value,
              mode: mode,
              style: LiquidGlassDatePickerStyle.wheels,
              minuteInterval: 15,
              onChanged: (date) => setState(() => value = date),
            ),
          ),
        ),
      );
      tester
          .widget<FallbackDateWheels>(find.byType(FallbackDateWheels))
          .onChanged(DateTime.utc(2026, 11, 1, 6, 49).toLocal());
      await tester.pumpAndSettle();
      expect(
        value,
        DateTime.utc(
          2026,
          11,
          1,
          6,
          mode == LiquidGlassDatePickerMode.date ? 37 : 45,
        ),
      );
      expect(value.isUtc, isTrue);
    }
  });

  testWidgets('minute grid survives a half-hour DST jump and bound snapping', (
    tester,
  ) async {
    // TZ=Australia/Lord_Howe skips 02:00–02:29 on this date. A 20-minute
    // interval cannot be rounded by subtracting minute % 20 across that gap.
    final before = DateTime(2026, 10, 4, 1, 59);
    final value = DateTime(2026, 10, 4, 2, 35, 12).toUtc();
    final hasGap = before.timeZoneOffset != value.toLocal().timeZoneOffset;
    final floor = hasGap
        ? DateTime(2026, 10, 4, 1, 40)
        : DateTime(2026, 10, 4, 2, 20);
    final ceiling = DateTime(2026, 10, 4, 2, hasGap ? 40 : 0);
    final received = <DateTime>[];
    for (final mode in [
      LiquidGlassDatePickerMode.time,
      LiquidGlassDatePickerMode.dateAndTime,
    ]) {
      Future<FallbackDateWheels> show({
        DateTime? lower,
        DateTime? upper,
      }) async {
        await tester.pumpWidget(
          _app(
            LiquidGlassDatePicker(
              value: value,
              mode: mode,
              style: LiquidGlassDatePickerStyle.wheels,
              minuteInterval: 20,
              minimumDate: lower,
              maximumDate: upper,
              onChanged: received.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final wheel = tester.widget<FallbackDateWheels>(
          find.byType(FallbackDateWheels),
        );
        expect(wheel.value.minute % 20, 0);
        return wheel;
      }

      expect((await show()).value, floor);
      final bounded = await show(
        lower: before,
        upper: DateTime(2026, 10, 4, 3, 5),
      );
      expect(bounded.minimumDate, ceiling);
      expect(bounded.maximumDate, DateTime(2026, 10, 4, 3));
      expect(bounded.value, hasGap ? ceiling : floor);
      final upperBounded = await show(upper: value.toLocal());
      expect(upperBounded.maximumDate, floor);
      expect(upperBounded.value, floor);
      expect(received, isEmpty);
      upperBounded.onChanged(value.toLocal());
      expect(received.removeLast(), floor.toUtc());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('bounds are snapped inward and display is safely clamped', (
    tester,
  ) async {
    final received = <DateTime>[];
    await tester.pumpWidget(
      _app(
        LiquidGlassDatePicker(
          value: DateTime(2026, 10, 10, 8),
          style: LiquidGlassDatePickerStyle.wheels,
          minuteInterval: 15,
          minimumDate: DateTime(2026, 10, 10, 10, 7),
          maximumDate: DateTime(2026, 10, 10, 11, 14, 59),
          onChanged: received.add,
        ),
      ),
    );
    final picker = tester.widget<FallbackDateWheels>(
      find.byType(FallbackDateWheels),
    );
    expect(picker.minimumDate, DateTime(2026, 10, 10, 10, 15));
    expect(picker.maximumDate, DateTime(2026, 10, 10, 11));
    expect(picker.value, picker.minimumDate);
    expect(received, isEmpty);
    picker.onChanged(DateTime(2026, 10, 10, 12));
    expect(received.single, DateTime(2026, 10, 10, 11));
    await tester.pumpAndSettle();
  });

  testWidgets('date range compares dates instead of bound times', (
    tester,
  ) async {
    DateTime? received;
    await tester.pumpWidget(
      _app(
        LiquidGlassDatePicker(
          value: DateTime(2026, 10, 10, 9),
          mode: LiquidGlassDatePickerMode.date,
          style: LiquidGlassDatePickerStyle.inline,
          minimumDate: DateTime(2026, 10, 10, 18),
          maximumDate: DateTime(2026, 10, 12, 3),
          onChanged: (date) => received = date,
        ),
      ),
    );
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.firstDate, DateTime(2026, 10, 10));
    expect(picker.lastDate, DateTime(2026, 10, 12));
    picker.onDateChanged(DateTime(2026, 10, 15));
    expect(received, DateTime(2026, 10, 12, 9));
    await tester.pumpAndSettle();
  });

  testWidgets('invalid interval and empty selectable range fail explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        LiquidGlassDatePicker(
          value: DateTime(2026, 10, 10),
          minuteInterval: 7,
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isArgumentError);
    await tester.pumpWidget(
      _app(
        LiquidGlassDatePicker(
          value: DateTime(2026, 10, 10, 10, 0),
          minuteInterval: 30,
          minimumDate: DateTime(2026, 10, 10, 10, 1),
          maximumDate: DateTime(2026, 10, 10, 10, 29),
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isArgumentError);
  });

  testWidgets('external date value, locale and cleared bounds synchronize', (
    tester,
  ) async {
    Future<void> show(
      DateTime value, {
      DateTime? minimum,
      Locale? locale,
    }) async {
      await tester.pumpWidget(
        _app(
          LiquidGlassDatePicker(
            value: value,
            style: LiquidGlassDatePickerStyle.wheels,
            minimumDate: minimum,
            locale: locale,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(DateTime(2026, 10, 10, 10), minimum: DateTime(2026, 10, 10));
    await show(DateTime(2026, 11, 11, 11), locale: const Locale('en', 'GB'));
    final picker = tester.widget<FallbackDateWheels>(
      find.byType(FallbackDateWheels),
    );
    expect(picker.value, DateTime(2026, 11, 11, 11));
    expect(picker.minimumDate, isNull);
    expect(
      Localizations.localeOf(tester.element(find.byType(FallbackDateWheels))),
      const Locale('en', 'GB'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected controlled date edit returns to caller value', (
    tester,
  ) async {
    final value = DateTime(2026, 10, 10, 10);
    await tester.pumpWidget(
      _app(
        LiquidGlassDatePicker(
          value: value,
          style: LiquidGlassDatePickerStyle.wheels,
          onChanged: (_) {},
        ),
      ),
    );
    tester
        .widget<FallbackDateWheels>(find.byType(FallbackDateWheels))
        .onChanged(DateTime(2026, 10, 11, 11));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FallbackDateWheels>(find.byType(FallbackDateWheels)).value,
      value,
    );
  });

  testWidgets('disabled date and color wells cannot present a panel', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            LiquidGlassDatePicker(
              value: DateTime(2026, 10, 10),
              semanticLabel: 'Due date',
              onChanged: null,
            ),
            const LiquidGlassColorPicker(
              selectedColor: Colors.red,
              onChanged: null,
              semanticLabel: 'Label color',
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(LiquidGlassDatePicker));
    await tester.tap(find.byType(LiquidGlassColorPicker));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.byType(FallbackGlassSlider), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Label color')),
      matchesSemantics(
        label: 'Label color',
        value: '#F44336FF',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('compact date opens real content and emits once per change', (
    tester,
  ) async {
    var count = 0;
    var value = DateTime(2026, 10, 10);
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassDatePicker(
            value: value,
            mode: LiquidGlassDatePickerMode.date,
            onChanged: (date) {
              count++;
              setState(() => value = date);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LiquidGlassDatePicker));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 10, 12));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(value, DateTime(2026, 10, 12));
    expect(count, 1);
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('color editor accepts arbitrary RGBA HEX and no second commit', (
    tester,
  ) async {
    var color = const Color(0xff112233);
    final received = <Color>[];
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassColorPicker(
            selectedColor: color,
            title: 'Theme color',
            onChanged: (value) {
              received.add(value);
              setState(() => color = value);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LiquidGlassColorPicker));
    await tester.pumpAndSettle();
    expect(find.byType(FallbackGlassSlider), findsNWidgets(4));
    await tester.enterText(find.byType(TextField), '#12345678');
    await tester.pumpAndSettle();
    expect(color.toARGB32(), 0x78123456);
    expect(received, hasLength(1));
    await tester.enterText(find.byType(TextField), '#12XX');
    await tester.pumpAndSettle();
    expect(received, hasLength(1));
    expect(find.text('Use RRGGBB or RRGGBBAA'), findsOneWidget);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(received, hasLength(1));
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RGB-only editor emits opaque colors and hides alpha', (
    tester,
  ) async {
    var color = const Color(0x30112233);
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => LiquidGlassColorPicker(
            selectedColor: color,
            supportsAlpha: false,
            onChanged: (value) => setState(() => color = value),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LiquidGlassColorPicker));
    await tester.pumpAndSettle();
    expect(find.byType(FallbackGlassSlider), findsNWidgets(3));
    await tester.enterText(find.byType(TextField), '#abcdef01');
    await tester.pumpAndSettle();
    expect(color.toARGB32(), 0xffabcdef);
    final slider = tester.widget<FallbackGlassSlider>(
      find.byKey(const ValueKey('liquid-glass-color-R')),
    );
    slider.onChanged!(22);
    await tester.pumpAndSettle();
    expect(color.toARGB32(), 0xff16cdef);
    expect(tester.takeException(), isNull);
  });

  testWidgets('color well label, title and current value remain independent', (
    tester,
  ) async {
    final changes = <Color>[];
    Future<void> show({
      String? label,
      String? title = 'Palette heading',
      Color color = const Color(0xff808080),
      bool enabled = true,
    }) async {
      await tester.pumpWidget(
        _app(
          LiquidGlassColorPicker(
            selectedColor: color,
            title: title,
            semanticLabel: label,
            onChanged: enabled ? changes.add : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Semantics semantics() => tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(LiquidGlassColorPicker),
            matching: find.byType(Semantics),
          )
          .first,
    );
    await show(label: 'Sample color');
    expect(semantics().properties.label, 'Sample color');
    expect(semantics().properties.value, '#808080FF');
    expect(find.text('Palette heading'), findsOneWidget);
    await show(
      label: 'Updated color',
      color: const Color(0xff0000ff),
      enabled: false,
    );
    expect(semantics().properties.label, 'Updated color');
    expect(semantics().properties.value, '#0000FFFF');
    expect(semantics().properties.enabled, isFalse);
    await show();
    expect(semantics().properties.label, 'Palette heading');
    await show(title: null);
    expect(semantics().properties.label, 'Color');
    expect(changes, isEmpty);
  });

  testWidgets(
    'color well semantics opens and dismisses without changing color',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <Color>[];
      await tester.pumpWidget(
        _app(
          LiquidGlassColorPicker(
            selectedColor: const Color(0xff808080),
            semanticLabel: 'Sample color',
            title: 'Palette heading',
            onChanged: changes.add,
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Sample color'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FallbackGlassSlider), findsNWidgets(4));
      expect(changes, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FallbackGlassSlider), findsNothing);
      expect(changes, isEmpty);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'stale color semantics cannot open while covered, backgrounded or disposed',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final changes = <Color>[];
      await tester.pumpWidget(
        LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: LiquidGlassColorPicker(
                selectedColor: const Color(0xff808080),
                semanticLabel: 'Sample color',
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      final activate = tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byType(LiquidGlassColorPicker),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .onTap!;
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      activate();
      await tester.pumpAndSettle();
      expect(find.byType(FallbackGlassSlider), findsNothing);
      expect(find.text('Covered'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      activate();
      await tester.pumpAndSettle();
      expect(find.byType(FallbackGlassSlider), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      activate();
      await tester.pumpAndSettle();
      expect(find.byType(FallbackGlassSlider), findsNothing);
      expect(changes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native color label updates keep title, value and callback contracts',
    (tester) async {
      final bridge = _PickerBridgeHarness(tester, 'color');
      var color = const Color(0xff808080).toARGB32();
      var label = 'Sample color';
      var dark = false;
      var enabled = true;
      String? semanticLabel = label;
      late StateSetter update;
      final changes = <Object?>[];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Theme(
                data: dark ? ThemeData.dark() : ThemeData.light(),
                child: LiquidGlassTheme(
                  data: const _NativePickerTestTheme(),
                  child: LiquidGlassColorPicker(
                    selectedColor: Color(color),
                    semanticLabel: semanticLabel,
                    title: 'Palette heading',
                    onChanged: enabled
                        ? (value) {
                            changes.add(value.toARGB32());
                            setState(() => color = value.toARGB32());
                          }
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final channel = bridge.channel;
      expect(bridge.config['semanticLabel'], label);
      expect(bridge.config['title'], 'Palette heading');
      update(() {
        label = 'Updated color';
        semanticLabel = label;
        dark = true;
        color = const Color(0xff0000ff).toARGB32();
      });
      await tester.pumpAndSettle();
      expect(bridge.channel, same(channel));
      expect(bridge.config['semanticLabel'], label);
      expect(bridge.config['title'], 'Palette heading');
      expect(bridge.config['dark'], isTrue);
      expect(bridge.config['value'], color);
      expect(changes, isEmpty);
      final revision = bridge.config['revision'];
      final green = const Color(0xff00ff00).toARGB32();
      await bridge.event(revision, green);
      await tester.pumpAndSettle();
      await bridge.event(revision, green);
      expect(changes, [green]);
      update(() {
        semanticLabel = null;
        enabled = false;
      });
      await tester.pumpAndSettle();
      expect(bridge.config.containsKey('semanticLabel'), isTrue);
      expect(bridge.config['semanticLabel'], isNull);
      expect(bridge.config['title'], 'Palette heading');
      expect(bridge.config['value'], green);
      await bridge.event(bridge.config['revision'], color + 1);
      expect(changes, [green]);
      expect(bridge.channel, same(channel));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('color palette forwards custom colors and controlled updates', (
    tester,
  ) async {
    var color = const Color(0xff112233);
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidGlassColorPicker(
              selectedColor: color,
              onChanged: (value) => setState(() => color = value),
            );
          },
        ),
        colors: const LiquidGlassColors(
          accent: Colors.purple,
          foreground: Colors.brown,
          selection: Colors.orange,
        ),
      ),
    );
    await tester.tap(find.byType(LiquidGlassColorPicker));
    await tester.pumpAndSettle();
    expect(
      LiquidGlassTheme.of(
        tester.element(find.byType(FallbackGlassSlider).first),
      ).colors.accent,
      Colors.purple,
    );
    expect(
      LiquidGlassTheme.of(
        tester.element(find.byType(FallbackGlassSlider).first),
      ).colors.selection,
      Colors.orange,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).style!.color,
      Colors.brown,
    );
    update(() => color = const Color(0x778899aa));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '#8899AA77',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'color channel dragging stays controlled without 255 feedback ticks',
    (tester) async {
      var color = const Color(0xff112233);
      final changes = <Color>[];
      final haptics = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => LiquidGlassColorPicker(
              selectedColor: color,
              onChanged: (value) {
                changes.add(value);
                setState(() => color = value);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidGlassColorPicker));
      await tester.pumpAndSettle();
      final red = find.byKey(const ValueKey('liquid-glass-color-R'));
      final rect = tester.getRect(red);
      final gesture = await tester.startGesture(
        Offset(rect.left + 24, rect.center.dy),
      );
      for (final fraction in [.25, .5, .75, 1.0]) {
        await gesture.moveTo(
          Offset(rect.left + rect.width * fraction, rect.center.dy),
        );
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(color.toARGB32(), 0xffff2233);
      expect(changes.length, greaterThan(2));
      expect(
        changes.map((color) => color.toARGB32()).toSet(),
        hasLength(changes.length),
      );
      expect(haptics, hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '#FF2233FF',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final kind in ['date', 'color']) {
    testWidgets(
      'native $kind continuous changes survive echoes and reject old resets',
      (tester) async {
        final bridge = _PickerBridgeHarness(tester, kind);
        var value = 1;
        late StateSetter update;
        final changes = <Object?>[];
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return NativePicker(
                  kind: kind,
                  height: 48,
                  configuration: {'value': value, 'enabled': true},
                  onChanged: (next) {
                    changes.add(next);
                    setState(() => value = next as int);
                  },
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final revision = bridge.config['revision'];
        await bridge.event(revision, 2);
        await tester.pumpAndSettle();
        expect(bridge.config['revision'], revision);
        expect(bridge.config['valueIsEcho'], isTrue);
        // This message was emitted before UIKit received the previous echo.
        await bridge.event(revision, 3);
        await tester.pumpAndSettle();
        expect(value, 3);
        expect(bridge.config['valueIsEcho'], isTrue);
        update(() => value = 10);
        await tester.pumpAndSettle();
        expect(bridge.config['revision'], isNot(revision));
        expect(bridge.config['valueIsEcho'], isFalse);
        await bridge.event(revision, 4);
        expect(value, 10);
        expect(changes, [2, 3]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'constant picker in a nested Navigator follows ancestor popup coverage',
    (tester) async {
      final bridge = _PickerBridgeHarness(tester, 'color');
      final root = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: root, home: const SizedBox()),
      );
      root.currentState!.push(
        _PickerTestPopup(
          SizedBox(
            width: 200,
            height: 200,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const NativePicker(
                  kind: 'color',
                  height: 48,
                  configuration: {'value': 0xff112233, 'enabled': true},
                  onChanged: _ignorePickerValue,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridge.config['suppressed'], isFalse);
      expect(bridge.config['popupOwner'], isTrue);
      root.currentState!.push(_PickerTestPopup(const Text('Cover')));
      await tester.pumpAndSettle();
      expect(bridge.config['suppressed'], isTrue);
      root.currentState!.pop();
      await tester.pumpAndSettle();
      expect(bridge.config['suppressed'], isFalse);
      root.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(bridge.config['suppressed'], isFalse);
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native instance config clears nulls without recreating view',
    (tester) async {
      final calls = <MethodCall>[];
      var creates = 0;
      MethodChannel? channel;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          if (call.method == 'create') {
            creates++;
            final id = (call.arguments as Map)['id'];
            channel = MethodChannel(
              'flutter_adaptive_liquid_glass/date_picker/$id',
            );
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel!,
              (call) async {
                calls.add(call);
                return null;
              },
            );
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        if (channel != null) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel!,
            null,
          );
        }
      });
      final changed = <Object?>[];
      Future<void> show(Map<String, Object?> configuration) async {
        await tester.pumpWidget(
          _app(
            NativePicker(
              kind: 'date',
              height: 48,
              configuration: configuration,
              onChanged: changed.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final config = <String, Object?>{
        'value': 1,
        'enabled': true,
        'minimumDate': 0,
        'maximumDate': 100,
        'locale': 'en-US',
        'tint': Colors.purple.toARGB32(),
      };
      await show(config);
      final oldRevision = (calls.last.arguments as Map)['revision'];
      await show({
        ...config,
        'value': 2,
        'minimumDate': null,
        'maximumDate': null,
        'locale': null,
        'tint': null,
      });
      expect(creates, 1);
      final finalConfig = calls.last.arguments as Map;
      expect(finalConfig['value'], 2);
      for (final key in ['minimumDate', 'maximumDate', 'locale', 'tint']) {
        expect(finalConfig.containsKey(key), isTrue);
        expect(finalConfig[key], isNull);
      }
      Future<void> nativeEvent(Object? revision, int value) async {
        final done = Completer<void>();
        tester.binding.channelBuffers.push(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('changed', {'revision': revision, 'value': value}),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }

      await nativeEvent(oldRevision, 3);
      expect(changed, isEmpty);
      await nativeEvent(finalConfig['revision'], 4);
      expect(changed, [4]);
      await tester.pumpAndSettle();
      expect((calls.last.arguments as Map)['value'], 2);
      await show({...config, 'enabled': false});
      await nativeEvent((calls.last.arguments as Map)['revision'], 5);
      expect(changed, [4]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

void _ignorePickerValue(Object? _) {}

// Exercise public widget configuration on a Dart host without pretending that
// its real operating system has native Liquid Glass support.
class _NativePickerTestTheme extends LiquidGlassThemeData {
  const _NativePickerTestTheme();

  @override
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) => LiquidGlassMode.native;
}

class _PickerTestPopup extends PopupRoute<void> {
  _PickerTestPopup(this.child);
  final Widget child;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => Colors.black26;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Center(child: child);
}

class _PickerBridgeHarness {
  _PickerBridgeHarness(this.tester, String kind) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          channel = MethodChannel(
            'flutter_adaptive_liquid_glass/${kind}_picker/$id',
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel!,
            (call) async {
              calls.add(call);
              return null;
            },
          );
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      );
      if (channel != null) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel!,
          null,
        );
      }
    });
  }
  final WidgetTester tester;
  final calls = <MethodCall>[];
  MethodChannel? channel;
  Map get config => calls.last.arguments as Map;
  Future<void> event(Object? revision, int value) async {
    final done = Completer<void>();
    tester.binding.channelBuffers.push(
      channel!.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('changed', {'revision': revision, 'value': value}),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }
}
