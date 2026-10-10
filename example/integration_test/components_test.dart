import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass_example/catalog_popups.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'mixed native/fallback sheet preserves editor through nested route',
    (tester) async {
      final observer = LiquidGlassNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              bottomNavigationBar: LiquidGlassTabBar(
                items: const [
                  LiquidGlassTabItem(
                    label: 'First',
                    icon: Icons.home,
                    sfSymbol: 'house',
                  ),
                  LiquidGlassTabItem(
                    label: 'Second',
                    icon: Icons.person,
                    sfSymbol: 'person',
                  ),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              body: Center(
                child: TextButton(
                  onPressed: () => showLiquidGlassSheet<void>(
                    context: context,
                    builder: (_) => const CatalogMixedPane(depth: 1),
                  ),
                  child: const Text('Open mixed sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open mixed sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Mixed layer 1'), findsOneWidget);
      final field = find.descendant(
        of: find.byKey(const ValueKey('popup-draft-1')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '中文 👩🏽‍💻 draft');
      await tester.pump();
      await dismissKeyboard(tester);
      await reveal(tester, find.byKey(const ValueKey('popup-nest-1')));
      await tester.tap(find.byKey(const ValueKey('popup-nest-1')));
      await tester.pumpAndSettle();
      expect(find.text('Mixed layer 2'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('popup-close-2')));
      await tester.tap(find.byKey(const ValueKey('popup-close-2')));
      await tester.pumpAndSettle();
      await reveal(tester, field, delta: -150);
      expect(
        tester.widget<TextField>(field).controller!.text,
        '中文 👩🏽‍💻 draft',
      );
      await reveal(tester, find.byKey(const ValueKey('popup-close-1')));
      await tester.tap(find.byKey(const ValueKey('popup-close-1')));
      await tester.pumpAndSettle();
      expect(find.text('Mixed layer 1'), findsNothing);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      observer.dispose();
    },
  );
  testWidgets(
    'fallback device controls edit values, search drafts and color panels',
    exerciseFallbackControls,
  );
}

/// Also run by the example widget suite. The device run uses compiled Flutter
/// controls and a registered synthetic text-input channel. It does not validate
/// native UIKit touch synthesis or physical keyboard/IME behavior.
Future<void> exerciseFallbackControls(WidgetTester tester) async {
  // IntegrationTestWidgetsFlutterBinding leaves the real IME connected by
  // default. Mixing that connection with enterText's fake messages leaves the
  // tester's cached focusedEditable stale after submit/clearClient in Flutter
  // 3.41, so a second enterText on the same editor can be silently dropped. Use
  // one synthetic channel for this synthetic editing scenario; it also receives
  // clearClient and lets the test driver reconnect normally. The native/mixed
  // sheet scenario above keeps its existing platform input behavior.
  if (!tester.testTextInput.isRegistered) {
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
  }
  final hostKey = GlobalKey<_FallbackInteractionHostState>();
  await tester.pumpWidget(_FallbackInteractionHost(key: hostKey));
  await tester.pumpAndSettle();
  final host = hostKey.currentState!;

  final slider = find.byType(CupertinoSlider);
  await tester.drag(slider, const Offset(90, 0));
  await tester.pumpAndSettle();
  expect(find.text('Slider increased: true'), findsOneWidget);
  expect(find.text('Slider gestures: 1 / 1'), findsOneWidget);

  await tester.tap(find.byType(CupertinoSwitch));
  await tester.pumpAndSettle();
  expect(find.text('Switch: true'), findsOneWidget);
  await tester.tap(find.byIcon(CupertinoIcons.plus));
  await tester.pumpAndSettle();
  expect(find.text('Stepper: 2'), findsOneWidget);
  await tester.tap(find.byIcon(CupertinoIcons.minus));
  await tester.pumpAndSettle();
  expect(find.text('Stepper: 1'), findsOneWidget);

  final search = find.descendant(
    of: find.byKey(const ValueKey('fallback-search')),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(search);
  await tester.enterText(search, '查找 中文 👩🏽‍💻');
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
  expect(host._submitted, '查找 中文 👩🏽‍💻');

  await tester.tap(find.byKey(const ValueKey('fallback-theme')));
  await tester.pumpAndSettle();
  expect(find.text('Fallback dark'), findsOneWidget);
  expect(host._search.text, '查找 中文 👩🏽‍💻');
  final clear = find.descendant(
    of: find.byKey(const ValueKey('fallback-search')),
    matching: find.byIcon(Icons.cancel_outlined),
  );
  await tester.ensureVisible(clear);
  await tester.tap(clear);
  await tester.pumpAndSettle();
  expect(host._search.text, isEmpty);
  expect(host._clears, 1);

  await tester.enterText(search, '保留草稿 🔎');
  expect(
    host._search.text,
    '保留草稿 🔎',
    reason: 'Second synthetic input must arrive before the theme gesture.',
  );
  await tester.pumpAndSettle();
  expect(
    host._search.text,
    '保留草稿 🔎',
    reason: 'Second input must survive frames before changing theme.',
  );
  await tester.tap(find.byKey(const ValueKey('fallback-theme')));
  await tester.pumpAndSettle();
  expect(find.text('Fallback light'), findsOneWidget);
  expect(host._search.text, '保留草稿 🔎');
  await dismissKeyboard(tester);

  final colorWell = find.byKey(const ValueKey('fallback-color'));
  await tester.ensureVisible(colorWell);
  await tester.tap(colorWell);
  await tester.pumpAndSettle();
  final hex = find.byKey(const ValueKey('liquid-glass-color-hex'));
  expect(hex, findsOneWidget);
  await tester.drag(
    find.byKey(const ValueKey('liquid-glass-color-R')),
    const Offset(70, 0),
  );
  await tester.pumpAndSettle();
  expect(host._color, isNot(const Color(0xff224466)));
  await reveal(tester, hex);
  await tester.enterText(hex, '#12AB34CC');
  await tester.pumpAndSettle();
  await dismissKeyboard(tester);
  await reveal(tester, find.text('Close'));
  await tester.tap(find.text('Close'));
  await tester.pumpAndSettle();
  expect(hex, findsNothing);
  expect(host._color.toARGB32(), 0xcc12ab34);
  expect(host._search.text, '保留草稿 🔎');

  // Reopen using the actual color-well trigger to check accepted value survives
  // disposal and recreation of the editor, then leave no route behind.
  await tester.ensureVisible(colorWell);
  await tester.tap(colorWell);
  await tester.pumpAndSettle();
  expect(find.text('#12AB34CC'), findsOneWidget);
  await reveal(tester, find.text('Close'));
  await tester.tap(find.text('Close'));
  await tester.pumpAndSettle();
  expect(hex, findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

/// Synthetic application state with visible callback results. No native tabs
/// are included, so forcing fallback makes every tested target a Flutter view.
class _FallbackInteractionHost extends StatefulWidget {
  const _FallbackInteractionHost({super.key});

  @override
  State<_FallbackInteractionHost> createState() =>
      _FallbackInteractionHostState();
}

class _FallbackInteractionHostState extends State<_FallbackInteractionHost> {
  final _observer = LiquidGlassNavigatorObserver();
  final _search = TextEditingController();
  bool _dark = false;
  double _slider = .5;
  int _starts = 0;
  int _ends = 0;
  bool _enabled = false;
  double _stepper = 1;
  String _submitted = '';
  int _clears = 0;
  Color _color = const Color(0xff224466);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    navigatorObservers: [_observer],
    builder: (context, child) => LiquidGlassTheme(
      data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(
        title: Text(_dark ? 'Fallback dark' : 'Fallback light'),
        actions: [
          IconButton(
            key: const ValueKey('fallback-theme'),
            tooltip: 'Toggle theme',
            onPressed: () => setState(() => _dark = !_dark),
            icon: const Icon(Icons.brightness_6),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LiquidGlassSlider(
            value: _slider,
            divisions: 4,
            semanticLabel: 'Synthetic level',
            onChangeStart: (_) => setState(() => _starts++),
            onChanged: (value) => setState(() => _slider = value),
            onChangeEnd: (_) => setState(() => _ends++),
          ),
          Text('Slider increased: ${_slider > .5}'),
          Text('Slider gestures: $_starts / $_ends'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LiquidGlassSwitch(
              value: _enabled,
              semanticLabel: 'Synthetic switch',
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),
          Text('Switch: $_enabled'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LiquidGlassStepper(
              value: _stepper,
              min: 0,
              max: 3,
              semanticLabel: 'Synthetic count',
              onChanged: (value) => setState(() => _stepper = value),
            ),
          ),
          Text('Stepper: ${_stepper.toInt()}'),
          const SizedBox(height: 12),
          LiquidGlassSearchField(
            key: const ValueKey('fallback-search'),
            controller: _search,
            hintText: 'Synthetic search',
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) => setState(() => _submitted = value),
            onClear: () => setState(() => _clears++),
          ),
          Text('Draft: ${_search.text}'),
          Text('Submitted: $_submitted'),
          Text('Clears: $_clears'),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LiquidGlassColorPicker(
              key: const ValueKey('fallback-color'),
              selectedColor: _color,
              title: 'Synthetic color',
              onChanged: (value) => setState(() => _color = value),
            ),
          ),
          Text('Color: ${_color.toARGB32().toRadixString(16)}'),
          Text('Color changed: ${_color != const Color(0xff224466)}'),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _search.dispose();
    _observer.dispose();
    super.dispose();
  }
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 150,
}) async {
  // Nested routes retain their scrollables. Select the front route explicitly;
  // a global `.last` may select a covered list or an editable's inner scrollable.
  final currentList = find.byElementPredicate(
    (element) =>
        element.widget is Scrollable &&
        ((element.widget as Scrollable).axisDirection == AxisDirection.down ||
            (element.widget as Scrollable).axisDirection == AxisDirection.up) &&
        ModalRoute.of(element)?.isCurrent == true,
  );
  expect(currentList, findsOneWidget);
  final list = tester.state<ScrollableState>(currentList);
  final route = ModalRoute.of(list.context)!;
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pumpAndSettle();
    expect(
      route.isCurrent,
      isTrue,
      reason: 'The front route disappeared while revealing $finder.',
    );
    final matches = finder.evaluate().toList();
    if (matches.length == 1 && ModalRoute.of(matches.single) == route) {
      if (finder.hitTestable().evaluate().isNotEmpty) {
        final rect = tester.getRect(finder);
        final insets = tester.view.viewInsets.bottom;
        await tester.pump(const Duration(milliseconds: 16));
        if (finder.hitTestable().evaluate().isNotEmpty &&
            tester.getRect(finder) == rect &&
            tester.view.viewInsets.bottom == insets &&
            !tester.binding.hasScheduledFrame) {
          return;
        }
        continue;
      }
      // Scroll content within the current detent. Synthetic drags here can
      // resize/snap a draggable sheet, then recycle a previously found child.
      await Scrollable.ensureVisible(matches.single, alignment: .5);
    } else {
      final position = list.position;
      position.jumpTo(
        (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    }
    await tester.pump();
  }
  fail('Could not make $finder hit-testable in the front route.');
}

Future<void> dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  // Native keyboard insets can arrive after Flutter's scheduled frames settle.
  // Wait for the actual metric rather than assuming an arbitrary sleep is enough.
  for (var frame = 0; frame < 180; frame++) {
    if (tester.view.viewInsets.bottom == 0) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('Keyboard insets did not clear after the editor lost focus.');
}
