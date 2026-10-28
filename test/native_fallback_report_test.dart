import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_fallback_report.dart';
import 'package:flutter_test/flutter_test.dart';

class _NativeTheme extends LiquidGlassThemeData {
  const _NativeTheme();
  @override
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) => LiquidGlassMode.native;
}

Widget _host(Widget child, {LiquidGlassThemeData data = const _NativeTheme()}) {
  return MaterialApp(
    home: LiquidGlassTheme(
      data: data,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final printed = <String>[];

  setUp(() {
    debugResetNativeFallbackReports();
    printed.clear();
    // Native capsules in the navigation bar create platform views.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
  });

  // debugPrint must be restored before the test's invariants are checked.
  void testReports(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) printed.add(message);
      };
      try {
        await body(tester);
      } finally {
        debugPrint = original;
      }
    });
  }

  testReports('a loading native button explains its Flutter rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(LiquidGlassButton(label: 'Save', loading: true, onPressed: () {})),
    );
    expect(printed, hasLength(1));
    expect(printed.single, contains('LiquidGlassButton'));
    expect(printed.single, contains('loading'));
  });

  testReports('each reason prints once per process', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            LiquidGlassButton(label: 'A', loading: true, onPressed: () {}),
            LiquidGlassButton(label: 'B', loading: true, onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _host(LiquidGlassButton(label: 'C', loading: true, onPressed: () {})),
    );
    expect(printed, hasLength(1));

    // A different reason is reported separately, also only once.
    for (var i = 0; i < 2; i++) {
      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: LiquidGlassSegmentedControl<int>(
              segments: const [
                LiquidGlassSegment(value: 0, label: 'Day'),
                LiquidGlassSegment(value: 1, label: 'Week'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
    }
    expect(printed, hasLength(2));
    expect(printed.last, contains('LiquidGlassSegmentedControl'));
    expect(printed.last, contains('text scale'));
  });

  testReports('the navigation bar names every unsupported condition', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LiquidGlassNavigationBar(
          title: 'Inbox',
          actions: [
            LiquidGlassAction(
              id: 'a',
              label: 'Add',
              icon: Icons.add,
              onPressed: () {},
            ),
            LiquidGlassAction(
              id: 'b',
              label: 'Edit',
              icon: Icons.edit,
              sfSymbol: 'pencil',
              onPressed: () {},
              onLongPress: () {},
            ),
          ],
        ),
      ),
    );
    expect(printed, hasLength(3));
    expect(printed.every((m) => m.contains('LiquidGlassNavigationBar')), true);
    expect(printed.any((m) => m.contains('more than one trailing')), true);
    expect(printed.any((m) => m.contains('onLongPress')), true);
    expect(printed.any((m) => m.contains('without an sfSymbol')), true);
  });

  testReports('fallback mode never prints', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            LiquidGlassButton(label: 'Save', loading: true, onPressed: () {}),
            LiquidGlassNavigationBar(
              title: 'Inbox',
              leading: [
                LiquidGlassAction(id: 'a', label: 'A', onPressed: () {}),
                LiquidGlassAction(id: 'b', label: 'B', onPressed: () {}),
              ],
            ),
          ],
        ),
        data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
      ),
    );
    expect(printed, isEmpty);
  });
}
