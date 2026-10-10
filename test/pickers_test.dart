import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_picker.dart';
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
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2030, 2, 3, 17, 47, 9));
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
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime.utc(2026, 11, 1, 6, 49).toLocal());
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
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.minimumDate, DateTime(2026, 10, 10, 10, 15));
    expect(picker.maximumDate, DateTime(2026, 10, 10, 11));
    expect(picker.initialDateTime, picker.minimumDate);
    expect(received, isEmpty);
    picker.onDateTimeChanged(DateTime(2026, 10, 10, 12));
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
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.initialDateTime, DateTime(2026, 11, 11, 11));
    expect(picker.minimumDate, isNull);
    expect(
      Localizations.localeOf(tester.element(find.byType(CupertinoDatePicker))),
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
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 10, 11, 11));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .initialDateTime,
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
    expect(find.byType(Slider), findsNothing);
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
    expect(find.byType(Slider), findsNWidgets(4));
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
    expect(find.byType(Slider), findsNWidgets(3));
    await tester.enterText(find.byType(TextField), '#abcdef01');
    await tester.pumpAndSettle();
    expect(color.toARGB32(), 0xffabcdef);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('liquid-glass-color-R')),
    );
    slider.onChanged!(22);
    await tester.pumpAndSettle();
    expect(color.toARGB32(), 0xff16cdef);
    expect(tester.takeException(), isNull);
  });

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
      tester.widget<Slider>(find.byType(Slider).first).activeColor,
      Colors.purple,
    );
    expect(
      tester.widget<Slider>(find.byType(Slider).first).inactiveColor,
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
