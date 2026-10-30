import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_pressable.dart';
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

const _lifecycle = MethodChannel('flutter_adaptive_liquid_glass/lifecycle');
const _page = ValueKey('page');
const _popupButton = ValueKey('popup');
const _sheetButton = ValueKey('sheet');
const _fallbackScope = ValueKey('fallback');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final viewChannels = <MethodChannel>[];
  late List<String> lifecycle;

  setUp(() {
    lifecycle = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, (
      call,
    ) async {
      lifecycle.add(call.method);
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final type = arguments['viewType'] as String;
          final channel = MethodChannel('$type/${arguments['id']}');
          viewChannels.add(channel);
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'intrinsicSize' ? {'width': 120.0} : null,
          );
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_lifecycle, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    for (final channel in viewChannels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
    viewChannels.clear();
  });

  // The button's native view takes part in painting.
  bool nativeShown(WidgetTester tester, [Key key = _page]) => tester
      .widget<Visibility>(
        find
            .ancestor(
              of: find.descendant(
                of: find.byKey(key, skipOffstage: false),
                matching: find.byType(UiKitView, skipOffstage: false),
              ),
              matching: find.byType(Visibility, skipOffstage: false),
            )
            .first,
      )
      .visible;

  // The button's Flutter stand-in is built.
  bool standIn(WidgetTester tester, [Key key = _page]) => find
      .descendant(
        of: find.byKey(key, skipOffstage: false),
        matching: find.byType(FallbackPressable, skipOffstage: false),
      )
      .evaluate()
      .isNotEmpty;

  // Every frame draws the page button natively or as its stand-in.
  Future<void> frames(WidgetTester tester, int count) async {
    for (var frame = 0; frame < count; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        nativeShown(tester) || standIn(tester),
        isTrue,
        reason: 'frame $frame',
      );
    }
  }

  void expectKept(WidgetTester tester) {
    expect(nativeShown(tester), isTrue);
    expect(standIn(tester), isFalse);
  }

  void expectIsolated(WidgetTester tester) {
    expect(nativeShown(tester), isFalse);
    expect(standIn(tester), isTrue);
  }

  BuildContext pageContext(WidgetTester tester) =>
      tester.element(find.byKey(_page));

  Future<GlobalKey<NavigatorState>> pumpPage(
    WidgetTester tester, {
    bool observe = true,
  }) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = LiquidGlassNavigatorObserver.debug(nativeAvailable: true);
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [if (observe) observer],
        builder: (context, child) =>
            LiquidGlassTheme(data: const _NativeTheme(), child: child!),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlassButton(
                  key: _page,
                  label: 'Page action',
                  onPressed: () {},
                ),
                const LiquidGlassTheme(
                  data: LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
                  child: SizedBox(key: _fallbackScope),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expectKept(tester);
    return navigator;
  }

  testWidgets(
    'an isolating popup swaps native controls for stand-ins in one frame',
    (tester) async {
      final navigator = await pumpPage(tester);
      unawaited(navigator.currentState!.push(_Popup()));
      // Every frame of the entrance, the presentation and the exit draws the
      // control exactly once: natively or as its stand-in, never neither.
      await tester.pump();
      expectIsolated(tester);
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectIsolated(tester);
      }
      await tester.pumpAndSettle();
      expectIsolated(tester);
      // The stand-in takes neither input nor accessibility focus.
      final stand = find.byType(FallbackPressable);
      expect(
        find.ancestor(of: stand, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: stand, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );

      navigator.currentState!.pop();
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        expectIsolated(tester);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Once the exit completes, the native view returns, with the stand-in
      // under it until UIKit has faded the view back in.
      await frames(tester, 10);
      expect(nativeShown(tester), isTrue);
      expect(standIn(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expectKept(tester);
    },
  );

  testWidgets('a pushed page hides the controls below without stand-ins', (
    tester,
  ) async {
    final navigator = await pumpPage(tester);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isFalse);
    expect(standIn(tester), isFalse);
  });

  testWidgets('without an observer a popup hides native views as before', (
    tester,
  ) async {
    final navigator = await pumpPage(tester, observe: false);
    unawaited(navigator.currentState!.push(_Popup()));
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isFalse);
    expect(standIn(tester), isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isTrue);

    // The package's own popups too.
    showLiquidGlassPopover<void>(
      context: pageContext(tester),
      anchorContext: pageContext(tester),
      builder: (_) => const Text('Menu'),
    );
    await tester.pumpAndSettle();
    expect(nativeShown(tester), isFalse);
    expect(standIn(tester), isFalse);
    expect(lifecycle, isEmpty);
  });

  final presenters = <String, void Function(BuildContext, Widget)>{
    'alert': (context, content) => showLiquidGlassAlert<void>(
      context: context,
      content: content,
      actions: const [LiquidGlassAlertAction(label: 'OK', value: null)],
    ),
    'sheet': (context, content) => showLiquidGlassSheet<void>(
      context: context,
      fitContent: true,
      builder: (_) => content,
    ),
    'popover': (context, content) => showLiquidGlassPopover<void>(
      context: context,
      anchorContext: context,
      builder: (_) => content,
    ),
  };

  for (final MapEntry(key: name, value: present) in presenters.entries) {
    testWidgets('a package $name keeps the native views below it', (
      tester,
    ) async {
      final navigator = await pumpPage(tester);
      present(
        pageContext(tester),
        const Material(type: MaterialType.transparency, child: Text('Body')),
      );
      await tester.pump();
      expectKept(tester);
      await tester.pumpAndSettle();
      expectKept(tester);
      navigator.currentState!.pop();
      await frames(tester, 20);
      await tester.pumpAndSettle();
      expectKept(tester);
      expect(lifecycle, isEmpty);
    });
  }

  testWidgets('a package popup with local fallback glass isolates the page', (
    tester,
  ) async {
    await pumpPage(tester);
    showLiquidGlassSheet<void>(
      context: tester.element(find.byKey(_fallbackScope)),
      builder: (_) => const SizedBox(),
    );
    await tester.pump();
    expectIsolated(tester);
    await tester.pumpAndSettle();
    expectIsolated(tester);
  });

  final fields = <String, Widget Function(FocusNode)>{
    'text field': (node) => TextField(focusNode: node),
    'selectable text': (node) => SelectableText('Selectable', focusNode: node),
    'selection area': (node) =>
        SelectionArea(focusNode: node, child: const Text('Selectable')),
  };

  for (final MapEntry(key: name, value: field) in fields.entries) {
    testWidgets('a focused $name isolates the page until focus leaves', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpPage(tester);
      showLiquidGlassSheet<void>(
        context: pageContext(tester),
        fitContent: true,
        builder: (_) =>
            Material(type: MaterialType.transparency, child: field(node)),
      );
      await tester.pumpAndSettle();
      expectKept(tester);

      node.requestFocus();
      // Focus applies after the next frame; the frame after it isolates the
      // page, with the stand-in in the frame in which the native view leaves.
      await frames(tester, 2);
      expectIsolated(tester);
      await frames(tester, 10);
      expectIsolated(tester);
      expect(lifecycle, ['suppressGlassEffects']);

      node.unfocus();
      await tester.pump();
      // The frame that removes the selection toolbar is still isolated.
      expectIsolated(tester);
      await frames(tester, 2);
      expect(nativeShown(tester), isTrue);
      // The stand-in stays under the native view while UIKit fades it in.
      expect(standIn(tester), isTrue);
      await frames(tester, 12);
      expect(standIn(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expectKept(tester);
      expect(lifecycle, ['suppressGlassEffects', 'unsuppressGlassEffects']);
    });
  }

  testWidgets('other focus in a package popup keeps the native views', (
    tester,
  ) async {
    final button = FocusNode();
    final inArea = FocusNode();
    addTearDown(button.dispose);
    addTearDown(inArea.dispose);
    await pumpPage(tester);
    showLiquidGlassSheet<void>(
      context: pageContext(tester),
      fitContent: true,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              focusNode: button,
              onPressed: () {},
              child: const Text('A'),
            ),
            SelectionArea(
              child: TextButton(
                focusNode: inArea,
                onPressed: () {},
                child: const Text('B'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    button.requestFocus();
    await frames(tester, 3);
    expectKept(tester);
    inArea.requestFocus();
    await frames(tester, 3);
    expectKept(tester);
    expect(lifecycle, isEmpty);
  });

  testWidgets('an overlay guard isolates the page under package popups', (
    tester,
  ) async {
    final navigator = await pumpPage(tester);
    bool shown(String text) => tester
        .widget<Visibility>(
          find.ancestor(of: find.text(text), matching: find.byType(Visibility)),
        )
        .visible;

    // Without a package popup, a guard changes nothing.
    final early = OverlayEntry(
      builder: (_) => const LiquidGlassOverlayGuard(child: Text('Early')),
    );
    navigator.currentState!.overlay!.insert(early);
    await tester.pump();
    expect(shown('Early'), isTrue);
    await frames(tester, 2);
    expectKept(tester);
    early.remove();
    early.dispose();
    await frames(tester, 2);
    expectKept(tester);

    showLiquidGlassPopover<void>(
      context: pageContext(tester),
      anchorContext: pageContext(tester),
      builder: (_) => const Text('Menu'),
    );
    await tester.pumpAndSettle();
    expectKept(tester);
    final toast = OverlayEntry(
      builder: (_) => const LiquidGlassOverlayGuard(child: Text('Toast')),
    );
    navigator.currentState!.overlay!.insert(toast);
    await tester.pump();
    // The toast waits for the frame in which the page is isolated.
    expect(shown('Toast'), isFalse);
    expectKept(tester);
    await tester.pump();
    expect(shown('Toast'), isTrue);
    expectIsolated(tester);
    await frames(tester, 5);
    expectIsolated(tester);

    toast.remove();
    toast.dispose();
    await tester.pump();
    // The frame without the toast is still isolated.
    expectIsolated(tester);
    await frames(tester, 3);
    expect(nativeShown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expectKept(tester);
  });

  testWidgets('nested package and isolating popups', (tester) async {
    final navigator = await pumpPage(tester);
    // A package popup above an isolating one: the page stays isolated and
    // the isolating popup's own native views stay.
    unawaited(navigator.currentState!.push(_Popup(native: true)));
    await tester.pumpAndSettle();
    expectIsolated(tester);
    expect(nativeShown(tester, _popupButton), isTrue);
    showLiquidGlassSheet<void>(
      context: tester.element(find.byKey(_popupButton)),
      fitContent: true,
      builder: (_) => const Text('Above'),
    );
    await tester.pumpAndSettle();
    expectIsolated(tester);
    expect(nativeShown(tester, _popupButton), isTrue);
    expect(standIn(tester, _popupButton), isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(nativeShown(tester, _popupButton), isTrue);
    navigator.currentState!.pop();
    await frames(tester, 30);
    await tester.pumpAndSettle();
    expectKept(tester);

    // An isolating popup above a package popup: the page and the package
    // popup's native views are isolated.
    showLiquidGlassSheet<void>(
      context: pageContext(tester),
      fitContent: true,
      builder: (_) => LiquidGlassButton(
        key: _sheetButton,
        label: 'Sheet action',
        onPressed: () {},
      ),
    );
    await tester.pumpAndSettle();
    expectKept(tester);
    expect(nativeShown(tester, _sheetButton), isTrue);
    unawaited(navigator.currentState!.push(_Popup()));
    await tester.pump();
    expectIsolated(tester);
    expect(nativeShown(tester, _sheetButton), isFalse);
    expect(standIn(tester, _sheetButton), isTrue);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await frames(tester, 30);
    await tester.pumpAndSettle();
    expectKept(tester);
    expect(nativeShown(tester, _sheetButton), isTrue);
    expect(standIn(tester, _sheetButton), isFalse);
  });
}

class _Popup extends PopupRoute<void> {
  _Popup({this.native = false});

  final bool native;

  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => Colors.black26;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Center(
    child: Material(
      child: native
          ? LiquidGlassButton(
              key: _popupButton,
              label: 'Popup action',
              onPressed: () {},
            )
          : const Text('Popup'),
    ),
  );
}
