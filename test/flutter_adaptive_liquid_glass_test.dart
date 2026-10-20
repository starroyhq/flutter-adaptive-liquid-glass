import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_tab_item.dart';

void main() {
  test(
    'iOS 26 tab bar keeps native UIKit under every rendering and accessibility preference',
    () {
      for (final mode in LiquidGlassMode.values) {
        expect(
          LiquidGlassThemeData(
            mode: mode,
            reduceTransparency: true,
            reduceMotion: true,
          ).resolveTabBar(nativeAvailable: true),
          LiquidGlassMode.native,
        );
        expect(
          LiquidGlassThemeData(
            mode: mode,
          ).resolveTabBar(nativeAvailable: false),
          isNot(LiquidGlassMode.native),
        );
      }
    },
  );
  test(
    'native selected tab keeps SF Symbol sizing even with a Flutter selected icon',
    () {
      final item = nativeTabItem(
        label: 'Computer',
        icon: Icons.computer_outlined,
        selectedIcon: Icons.computer,
        sfSymbol: 'desktopcomputer',
      );
      // The symbol draws both states; no bitmap is sent beside it.
      expect(item.symbol, 'desktopcomputer');
      expect(item.icon, isNull);
      expect(item.selectedIcon, isNull);
      final fallback = nativeTabItem(
        label: 'Computer',
        icon: Icons.computer_outlined,
        selectedIcon: Icons.computer,
      );
      expect(fallback.symbol, isNull);
      expect(fallback.icon, Icons.computer_outlined);
      expect(fallback.selectedIcon, Icons.computer);
    },
  );
  group('rendering policy', () {
    test('auto and native never select unavailable native views', () {
      for (final mode in [LiquidGlassMode.auto, LiquidGlassMode.native]) {
        final theme = LiquidGlassThemeData(mode: mode);
        expect(theme.resolve(nativeAvailable: false), LiquidGlassMode.fallback);
        expect(theme.resolve(nativeAvailable: true), LiquidGlassMode.native);
      }
    });

    test('fallback can be forced on native devices', () {
      expect(
        const LiquidGlassThemeData(
          mode: LiquidGlassMode.fallback,
        ).resolve(nativeAvailable: true),
        LiquidGlassMode.fallback,
      );
    });

    test(
      'transparency and contrast take precedence over every render mode',
      () {
        for (final mode in LiquidGlassMode.values) {
          expect(
            LiquidGlassThemeData(
              mode: mode,
              reduceTransparency: true,
            ).resolve(nativeAvailable: true),
            LiquidGlassMode.opaque,
          );
          expect(
            LiquidGlassThemeData(
              mode: mode,
            ).resolve(nativeAvailable: true, highContrast: true),
            LiquidGlassMode.opaque,
          );
        }
      },
    );

    test(
      'reduced motion preserves the chosen material and native renderer',
      () {
        for (final mode in LiquidGlassMode.values) {
          for (final available in [false, true]) {
            final expected = LiquidGlassThemeData(
              mode: mode,
            ).resolve(nativeAvailable: available);
            expect(
              LiquidGlassThemeData(
                mode: mode,
                reduceMotion: true,
              ).resolve(nativeAvailable: available),
              expected,
            );
            expect(
              LiquidGlassThemeData(
                mode: mode,
              ).resolve(nativeAvailable: available, disableAnimations: true),
              expected,
            );
          }
        }
      },
    );
  });

  testWidgets(
    'surface keeps editable child and native mode degrades on test host',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const LiquidGlassSurface(child: TextField()),
          mode: LiquidGlassMode.native,
        ),
      );
      await tester.enterText(find.byType(TextField), '你好 Flutter');
      expect(find.text('你好 Flutter'), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
    },
  );

  testWidgets('opaque and accessibility modes never allocate a blur layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LiquidGlassSurface(child: Text('Visible')),
        mode: LiquidGlassMode.opaque,
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(
      _host(
        const LiquidGlassSurface(child: Text('Visible')),
        highContrast: true,
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
    'button only invokes enabled actions and loading prevents duplicate input',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(LiquidGlassButton(label: 'Send', onPressed: () => calls++)),
      );
      await tester.tap(find.text('Send'));
      expect(calls, 1);
      await tester.pumpWidget(
        _host(
          LiquidGlassButton(
            label: 'Send',
            loading: true,
            onPressed: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byType(LiquidGlassButton));
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'tab selection is controlled and programmatic updates do not echo',
    (tester) async {
      final selections = <int>[];
      const items = [
        LiquidGlassTabItem(label: 'Computers', icon: Icons.computer),
        LiquidGlassTabItem(label: 'Sessions', icon: Icons.chat),
        LiquidGlassTabItem(label: 'Account', icon: Icons.person),
      ];
      await tester.pumpWidget(
        _host(
          LiquidGlassTabBar(
            items: items,
            selectedIndex: 0,
            onSelected: selections.add,
          ),
        ),
      );
      expect(selections, isEmpty);
      await tester.tap(find.text('Sessions'));
      expect(selections, [1]);
      await tester.pumpWidget(
        _host(
          LiquidGlassTabBar(
            items: items,
            selectedIndex: 2,
            onSelected: selections.add,
          ),
        ),
      );
      expect(selections, [1]);
    },
  );

  testWidgets(
    'segment maps labels to domain values and respects disabled state',
    (tester) async {
      final changes = <int>[];
      final segments = [
        const LiquidGlassSegment(value: 10, label: 'All'),
        const LiquidGlassSegment(value: 20, label: 'Running'),
      ];
      await tester.pumpWidget(
        _host(
          LiquidGlassSegmentedControl(
            segments: segments,
            selected: 10,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.text('Running'));
      expect(changes, [20]);
      await tester.pumpWidget(
        _host(
          LiquidGlassSegmentedControl(
            segments: segments,
            selected: 20,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('All'));
      expect(changes, [20]);
    },
  );

  testWidgets('navigation action remains reachable with disabled sibling', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: LiquidGlassNavigationBar(
            title: 'Sessions',
            actions: [
              LiquidGlassAction(
                id: 'search',
                label: 'Search',
                icon: Icons.search,
                onPressed: () => called = true,
              ),
              const LiquidGlassAction(id: 'add', label: 'Add', icon: Icons.add),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    expect(called, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text fits narrow tabs without losing labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 320,
          child: LiquidGlassTabBar(
            items: const [
              LiquidGlassTabItem(label: 'Computers', icon: Icons.computer),
              LiquidGlassTabItem(label: 'Sessions', icon: Icons.chat),
              LiquidGlassTabItem(label: 'Account', icon: Icons.person),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
        textScale: 2,
      ),
    );
    expect(find.text('Computers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('observer safely handles dialogs on fallback platforms', (
    tester,
  ) async {
    final observer = LiquidGlassNavigatorObserver();
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Popup'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Popup'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _host(
  Widget child, {
  LiquidGlassMode mode = LiquidGlassMode.fallback,
  bool highContrast = false,
  double textScale = 1,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      highContrast: highContrast,
      textScaler: TextScaler.linear(textScale),
    ),
    child: LiquidGlassTheme(
      data: LiquidGlassThemeData(mode: mode),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);
