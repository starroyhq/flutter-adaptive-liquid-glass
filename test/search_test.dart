import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

void main() {
  testWidgets('active scaffold transfers focus to replacement nodes', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft');
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget host(FocusNode? node) => MaterialApp(
      home: LiquidGlassSearchScaffold(
        body: const Text('Page'),
        tabs: const [
          LiquidGlassTabItem(label: 'One', icon: Icons.home),
          LiquidGlassTabItem(label: 'Two', icon: Icons.person),
        ],
        selectedIndex: 0,
        onTabChanged: (_) {},
        searchController: controller,
        searchActive: true,
        onSearchActiveChanged: (_) {},
        searchFocusNode: node,
      ),
    );
    await tester.pumpWidget(host(null));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.pumpWidget(host(first));
    await tester.pump();
    expect(first.hasFocus, isTrue);
    await tester.pumpWidget(host(second));
    await tester.pump();
    expect(second.hasFocus, isTrue);
    expect(first.hasFocus, isFalse);
    expect(controller.text, 'draft');
  });

  testWidgets(
    'large text keeps search and cancellation usable on narrow screens',
    (tester) async {
      final controller = TextEditingController(text: '中文 👩🏽‍💻');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: SizedBox(
              width: 280,
              child: LiquidGlassSearchField(
                controller: controller,
                showCancelButton: true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TextField)).width, greaterThan(100));
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      expect(controller.text, isEmpty);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing is immediate; clear, submit and cancel have distinct contracts',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final changes = <String>[];
      final submitted = <String>[];
      var cleared = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        _host(
          LiquidGlassSearchField(
            controller: controller,
            focusNode: focus,
            showCancelButton: true,
            onChanged: changes.add,
            onSubmitted: submitted.add,
            onClear: () => cleared++,
            onCancelled: () => cancelled++,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '查找 👩🏽‍💻');
      expect(changes, ['查找 👩🏽‍💻']);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, ['查找 👩🏽‍💻']);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      expect(controller.text, '');
      expect(changes, ['查找 👩🏽‍💻', '']);
      expect(cleared, 1);
      await tester.enterText(find.byType(TextField), 'keep draft');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, 1);
      expect(controller.text, 'keep draft');
      expect(focus.hasFocus, isFalse);
    },
  );

  testWidgets('theme changes retain selection, composing and focused editor', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    const value = TextEditingValue(
      text: '中文 👩🏽‍💻 ni',
      selection: TextSelection.collapsed(offset: 13),
      composing: TextRange(start: 12, end: 13),
    );
    Widget host(Brightness brightness) => _host(
      LiquidGlassSearchField(controller: controller, focusNode: focus),
      brightness: brightness,
    );
    await tester.pumpWidget(host(Brightness.light));
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(value);
    await tester.pump();
    final editor = tester.state(find.byType(EditableText));
    await tester.pumpWidget(host(Brightness.dark));
    expect(tester.state(find.byType(EditableText)), same(editor));
    expect(controller.value, value);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabled editor cannot clear and external controller remains owned by caller',
    (tester) async {
      final controller = TextEditingController(text: 'locked');
      addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        _host(
          LiquidGlassSearchField(
            controller: controller,
            enabled: false,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      expect(controller.text, 'locked');
      expect(changes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.text = 'still usable';
      expect(controller.text, 'still usable');
    },
  );

  testWidgets(
    'changing controllers detaches old listeners without emitting changes',
    (tester) async {
      final first = TextEditingController(text: 'first');
      final second = TextEditingController(text: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        _host(
          LiquidGlassSearchField(controller: first, onChanged: changes.add),
        ),
      );
      await tester.pumpWidget(
        _host(
          LiquidGlassSearchField(controller: second, onChanged: changes.add),
        ),
      );
      first.text = 'detached';
      await tester.pump();
      expect(find.text('second'), findsOneWidget);
      expect(changes, isEmpty);
      await tester.pumpWidget(
        _host(LiquidGlassSearchField(onChanged: changes.add)),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'second',
      );
    },
  );

  testWidgets(
    'search scaffold keeps application body state under results without nested routing',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final bodyKey = GlobalKey<_DraftState>();
      var active = false;
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => LiquidGlassSearchScaffold(
              body: _Draft(key: bodyKey),
              tabs: const [
                LiquidGlassTabItem(label: 'First', icon: Icons.home),
                LiquidGlassTabItem(label: 'Second', icon: Icons.person),
              ],
              selectedIndex: selected,
              onTabChanged: (index) => setState(() => selected = index),
              searchController: controller,
              searchActive: active,
              onSearchActiveChanged: (value) => setState(() => active = value),
              searchResults: const Text('Results'),
            ),
          ),
        ),
      );
      final state = bodyKey.currentState;
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      expect(active, isTrue);
      expect(find.text('Results'), findsOneWidget);
      expect(bodyKey.currentState, same(state));
      expect(find.byType(Navigator), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(active, isFalse);
      expect(bodyKey.currentState, same(state));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: LiquidGlassTheme(
        data: LiquidGlassThemeData(
          mode: LiquidGlassMode.fallback,
          colors: LiquidGlassColors.fromColorScheme(
            ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: brightness,
            ),
          ),
        ),
        child: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );

class _Draft extends StatefulWidget {
  const _Draft({super.key});
  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> {
  @override
  Widget build(BuildContext context) => const Text('Application page');
}
