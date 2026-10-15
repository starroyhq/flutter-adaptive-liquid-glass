import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

const _tabs = [
  LiquidGlassTabItem(label: 'Inbox', icon: Icons.inbox),
  LiquidGlassTabItem(label: 'Sessions', icon: Icons.chat_bubble_outline),
  LiquidGlassTabItem(label: 'Account', icon: Icons.person_outline),
];

Widget _host(Widget child) => MaterialApp(
  home: LiquidGlassTheme(
    data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
    child: child,
  ),
);

void main() {
  testWidgets('a trailing action sits after the tabs and keeps the tab', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selected = 0, searched = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: LiquidGlassTabBar(
              items: _tabs,
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
              trailingAction: LiquidGlassAction(
                id: 'search',
                label: 'Search',
                onPressed: () => searched++,
              ),
            ),
          ),
        ),
      ),
    );
    final search = find.bySemanticsLabel('Search');
    expect(search, findsOneWidget);
    expect(
      tester.getCenter(search).dx,
      greaterThan(tester.getCenter(find.text('Account')).dx),
    );
    expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
    await tester.tap(search);
    await tester.pump();
    expect(searched, 1);
    expect(selected, 0);
    semantics.dispose();
  });

  testWidgets('without a trailing action the tab bar is unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          bottomNavigationBar: LiquidGlassTabBar(
            items: _tabs,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.search), findsNothing);
  });

  group('tab bar search placement', () {
    Widget scaffold(
      TextEditingController controller,
      ValueNotifier<bool> active,
    ) => _host(
      ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (_, value, _) => LiquidGlassSearchScaffold(
          searchPlacement: LiquidGlassSearchPlacement.tabBar,
          tabs: _tabs,
          selectedIndex: 1,
          onTabChanged: (_) {},
          searchController: controller,
          searchActive: value,
          onSearchActiveChanged: (next) => active.value = next,
          searchHint: 'Search conversations',
          body: const Center(child: Text('Body')),
          searchResults: const Center(child: Text('Results')),
        ),
      ),
    );

    testWidgets('the button opens a docked field that closes again', (
      tester,
    ) async {
      final controller = TextEditingController();
      final active = ValueNotifier(false);
      addTearDown(controller.dispose);
      addTearDown(active.dispose);
      await tester.pumpWidget(scaffold(controller, active));
      // At rest: no field, tabs with the search button.
      expect(find.byType(LiquidGlassSearchField), findsNothing);
      expect(find.text('Body'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Search conversations'));
      await tester.pumpAndSettle();
      expect(active.value, isTrue);
      expect(find.byType(LiquidGlassTabBar), findsNothing);
      expect(find.text('Results'), findsOneWidget);
      final field = tester.getRect(find.byType(LiquidGlassSearchField));
      final screen = tester.getSize(find.byType(Scaffold));
      // Docked at the bottom.
      expect(field.center.dy, greaterThan(screen.height / 2));
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(active.value, isFalse);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('the docked field rides above the keyboard', (tester) async {
      final controller = TextEditingController();
      final active = ValueNotifier(true);
      addTearDown(controller.dispose);
      addTearDown(active.dispose);
      await tester.pumpWidget(scaffold(controller, active));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(LiquidGlassSearchField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(LiquidGlassSearchField));
      expect(after.bottom, lessThan(before.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}
