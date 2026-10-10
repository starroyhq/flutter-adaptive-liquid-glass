import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
import 'package:flutter_adaptive_liquid_glass/src/navigator_observer.dart';
import 'package:flutter_adaptive_liquid_glass/src/presentation.dart';
import 'package:flutter_adaptive_liquid_glass/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'alert actions return typed results exactly once and disable hits',
    (tester) async {
      final fixture = await _host(tester);
      var completions = 0;
      final future = showLiquidGlassAlert<int>(
        context: fixture.context,
        title: const Text('Confirm'),
        content: const Text('Choose an action.'),
        actions: const [
          LiquidGlassAlertAction(
            label: 'Unavailable',
            value: 1,
            enabled: false,
          ),
          LiquidGlassAlertAction(label: 'Delete', value: 2, destructive: true),
        ],
      )..then((_) => completions++);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unavailable'));
      await tester.pump();
      expect(completions, 0);
      final delete = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(
        delete.style!.foregroundColor!.resolve({}),
        Theme.of(fixture.context).colorScheme.error,
      );
      final deletePosition = tester.getCenter(find.text('Delete'));
      await tester.tapAt(deletePosition);
      await tester.tapAt(deletePosition);
      await tester.pumpAndSettle();
      expect(await future, 2);
      expect(completions, 1);
      expect(fixture.navigator.currentState!.canPop(), isFalse);
    },
  );

  testWidgets('action sheet cancel, barrier and system back return null', (
    tester,
  ) async {
    final fixture = await _host(tester);
    for (final method in ['cancel', 'barrier', 'back']) {
      final future = showLiquidGlassAlert<String>(
        context: fixture.context,
        style: LiquidGlassAlertStyle.actionSheet,
        actions: const [
          LiquidGlassAlertAction(
            label: 'Cancel',
            value: 'ignored',
            cancel: true,
          ),
          LiquidGlassAlertAction(label: 'Continue', value: 'continue'),
        ],
      );
      await tester.pumpAndSettle();
      if (method == 'cancel') {
        await tester.tap(find.text('Cancel'));
      } else if (method == 'barrier') {
        await tester.tapAt(const Offset(10, 10));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(await future, isNull, reason: method);
    }
  });

  testWidgets('non-dismissible alert supports programmatic pop and escape', (
    tester,
  ) async {
    final fixture = await _host(tester);
    var finished = false;
    final future = showLiquidGlassAlert<String>(
      context: fixture.context,
      barrierDismissible: false,
      actions: const [LiquidGlassAlertAction(label: 'Accept', value: 'yes')],
    )..then((_) => finished = true);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(finished, isFalse);
    fixture.navigator.currentState!.pop('programmatic');
    await tester.pumpAndSettle();
    expect(await future, 'programmatic');
  });

  testWidgets(
    'sheet coordinates primary scrolling with detents and drag close',
    (tester) async {
      final fixture = await _host(tester);
      ScrollController? controller;
      final future = showLiquidGlassSheet<String>(
        context: fixture.context,
        builder: (context) {
          controller = PrimaryScrollController.of(context);
          return ListView(
            primary: true,
            children: [
              for (var i = 0; i < 50; i++) ListTile(title: Text('Row $i')),
            ],
          );
        },
      );
      await tester.pumpAndSettle();
      final handle = find.byKey(const ValueKey('liquid-glass-sheet-handle'));
      final mediumTop = tester.getTopLeft(handle).dy;
      await tester.drag(handle, const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(handle).dy, lessThan(mediumTop - 100));
      await tester.drag(find.text('Row 2'), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(controller!.offset, greaterThan(0));
      await tester.drag(handle, const Offset(0, 650));
      await tester.pumpAndSettle();
      expect(await future, isNull);
      expect(handle, findsNothing);
    },
  );

  testWidgets('sheet handle resizes arbitrary non-scrollable content', (
    tester,
  ) async {
    final fixture = await _host(tester);
    final future = showLiquidGlassSheet<String>(
      context: fixture.context,
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => Navigator.pop(context, 'saved'),
          child: const Text('Save content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final handle = find.byKey(const ValueKey('liquid-glass-sheet-handle'));
    final top = tester.getTopLeft(handle).dy;
    await tester.drag(handle, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(handle).dy, lessThan(top - 100));
    await tester.tap(find.text('Save content'));
    await tester.pumpAndSettle();
    expect(await future, 'saved');
  });

  testWidgets('sheet respects keyboard, single detent and disabled drag', (
    tester,
  ) async {
    final media = ValueNotifier(const MediaQueryData(size: Size(800, 600)));
    addTearDown(media.dispose);
    final fixture = await _host(tester, media: media);
    final future = showLiquidGlassSheet<void>(
      context: fixture.context,
      enableDrag: false,
      detents: const [LiquidGlassSheetDetent.large],
      initialDetent: LiquidGlassSheetDetent.large,
      builder: (context) => Column(
        children: [
          Text('Inset ${MediaQuery.viewInsetsOf(context).bottom}'),
          const TextField(key: ValueKey('draft')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft')), '中文 👩🏽‍💻');
    media.value = media.value.copyWith(
      viewInsets: const EdgeInsets.only(bottom: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inset 0.0'), findsOneWidget);
    expect(find.text('中文 👩🏽‍💻'), findsOneWidget);
    final sheet = find.byType(DraggableScrollableSheet);
    expect(tester.getBottomLeft(sheet).dy, lessThanOrEqualTo(400));
    final handle = find.byKey(const ValueKey('liquid-glass-sheet-handle'));
    final top = tester.getTopLeft(handle).dy;
    await tester.drag(handle, const Offset(0, 250));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(handle).dy, top);
    fixture.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await future;
  });

  testWidgets(
    'popover follows anchor and clamps above keyboard without ticking',
    (tester) async {
      final position = ValueNotifier(const Offset(720, 460));
      final media = ValueNotifier(const MediaQueryData(size: Size(800, 600)));
      addTearDown(position.dispose);
      addTearDown(media.dispose);
      final anchor = GlobalKey();
      final fixture = await _host(
        tester,
        media: media,
        child: ValueListenableBuilder<Offset>(
          valueListenable: position,
          builder: (_, offset, _) => Stack(
            children: [
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: SizedBox(key: anchor, width: 48, height: 48),
              ),
            ],
          ),
        ),
      );
      final future = showLiquidGlassPopover<String>(
        context: fixture.context,
        anchorContext: anchor.currentContext!,
        width: 240,
        builder: (_) => const SizedBox(height: 150, child: Text('Popover')),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('liquid-glass-popover-surface'));
      final rect = tester.getRect(panel);
      expect(rect.bottom, lessThanOrEqualTo(452));
      expect(rect.right, lessThanOrEqualTo(788));
      expect(tester.binding.hasScheduledFrame, isFalse);

      position.value = const Offset(32, 90);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel), const Offset(32, 146));
      media.value = media.value.copyWith(
        viewInsets: const EdgeInsets.only(bottom: 360),
      );
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(panel).dy, lessThanOrEqualTo(228));
      fixture.navigator.currentState!.pop('done');
      await tester.pumpAndSettle();
      expect(await future, 'done');
    },
  );

  testWidgets('removing a covered anchor dismisses only its own popover', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final anchor = GlobalKey();
    final fixture = await _host(
      tester,
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, show, _) => show
            ? Center(child: SizedBox(key: anchor, width: 50, height: 50))
            : const SizedBox(),
      ),
    );
    final first = showLiquidGlassPopover<int>(
      context: fixture.context,
      anchorContext: anchor.currentContext!,
      builder: (_) => const SizedBox(height: 100, child: Text('First popup')),
    );
    await tester.pumpAndSettle();
    final second = showLiquidGlassAlert<int>(
      context: fixture.context,
      title: const Text('Second popup'),
      actions: const [LiquidGlassAlertAction(label: 'Keep', value: 7)],
    );
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pumpAndSettle();
    expect(await first, isNull);
    expect(find.text('Second popup'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(await second, 7);
    expect(fixture.navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('popup route removal completes its future once', (tester) async {
    final routes = _Routes();
    final fixture = await _host(tester, observers: [routes]);
    var count = 0;
    final result = showLiquidGlassSheet<String>(
      context: fixture.context,
      routeSettings: const RouteSettings(name: 'removable'),
      builder: (_) => const Text('Remove me'),
    )..then((_) => count++);
    await tester.pumpAndSettle();
    final route = routes.last! as Route<String>;
    expect(route, isA<PopupRoute<String>>());
    fixture.navigator.currentState!.removeRoute(route, 'removed');
    await tester.pumpAndSettle();
    expect(await result, 'removed');
    expect(count, 1);
  });

  testWidgets(
    'replacement completes the replaced popup without dismissing new route',
    (tester) async {
      final routes = _Routes();
      final fixture = await _host(tester, observers: [routes]);
      var completions = 0;
      final result = showLiquidGlassAlert<String>(
        context: fixture.context,
        actions: const [
          LiquidGlassAlertAction(label: 'Old action', value: 'old'),
        ],
      )..then((_) => completions++);
      await tester.pumpAndSettle();
      final replacement = _ReplacementPopup();
      fixture.navigator.currentState!.replace(
        oldRoute: routes.last!,
        newRoute: replacement,
      );
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(completions, 1);
      expect(find.text('Replacement'), findsOneWidget);
      fixture.navigator.currentState!.pop('replacement');
      await tester.pumpAndSettle();
      expect(await replacement.popped, 'replacement');
      expect(completions, 1);
    },
  );

  testWidgets('root navigator option selects the intended navigator', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    final nested = GlobalKey<NavigatorState>();
    late BuildContext childContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        home: Navigator(
          key: nested,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              childContext = context;
              return const Scaffold(body: Text('Nested page'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final useRoot in [false, true]) {
      final result = showLiquidGlassAlert<int>(
        context: childContext,
        useRootNavigator: useRoot,
        actions: const [LiquidGlassAlertAction(label: 'Finish', value: 1)],
      );
      await tester.pumpAndSettle();
      expect(root.currentState!.canPop(), useRoot);
      expect(nested.currentState!.canPop(), !useRoot);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(await result, 1);
      expect(root.currentState!.canPop(), isFalse);
      expect(nested.currentState!.canPop(), isFalse);
    }
  });

  testWidgets('popover updates bounds on resize and preserves its draft', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final fixture = await _host(
      tester,
      child: Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(key: anchor, width: 48, height: 48),
      ),
    );
    final result = showLiquidGlassPopover<void>(
      context: fixture.context,
      anchorContext: anchor.currentContext!,
      builder: (_) => const SizedBox(
        height: 180,
        child: TextField(key: ValueKey('popover-draft')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('popover-draft')),
      'Draft 👋',
    );
    await tester.binding.setSurfaceSize(const Size(360, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find.byKey(const ValueKey('liquid-glass-popover-surface')),
    );
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(348));
    expect(rect.bottom, lessThanOrEqualTo(488));
    expect(find.text('Draft 👋'), findsOneWidget);
    fixture.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await result;
  });

  testWidgets('dismissible popup handles escape and restores previous focus', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final fixture = await _host(tester, child: TextField(focusNode: focus));
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    final result = showLiquidGlassAlert<bool>(
      context: fixture.context,
      actions: const [LiquidGlassAlertAction(label: 'Accept', value: true)],
    );
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('native route coverage remains until actual popup exit', (
    tester,
  ) async {
    const channel = MethodChannel('liquid-glass-lifecycle');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final observer = LiquidGlassNavigatorObserver.debug(nativeAvailable: true);
    addTearDown(observer.dispose);
    final fixture = await _host(tester, observers: [observer]);
    final page = ModalRoute.of(fixture.context)!;
    final first = showLiquidGlassSheet<void>(
      context: fixture.context,
      builder: (_) => const Text('Outer sheet'),
    );
    await tester.pumpAndSettle();
    expect(nativeRouteCoverage.covers(page), isTrue);
    final second = showLiquidGlassAlert<void>(
      context: fixture.context,
      actions: const [LiquidGlassAlertAction(label: 'Close', value: null)],
    );
    await tester.pumpAndSettle();
    fixture.navigator.currentState!.pop();
    await tester.pump();
    expect(nativeRouteCoverage.covers(page), isTrue);
    await tester.pumpAndSettle();
    await second;
    expect(nativeRouteCoverage.covers(page), isTrue);
    fixture.navigator.currentState!.pop();
    await tester.pump();
    expect(nativeRouteCoverage.covers(page), isTrue);
    await tester.pumpAndSettle();
    await first;
    expect(nativeRouteCoverage.covers(page), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text alerts remain scrollable in a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final media = ValueNotifier(
      const MediaQueryData(
        size: Size(320, 360),
        textScaler: TextScaler.linear(2.5),
      ),
    );
    addTearDown(media.dispose);
    final fixture = await _host(tester, media: media);
    final future = showLiquidGlassAlert<int>(
      context: fixture.context,
      title: const Text('Long accessible dialog title'),
      content: const Text(
        'The complete content can be read at a large text size.',
      ),
      actions: const [
        LiquidGlassAlertAction(label: 'Finish reading', value: 1),
      ],
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finish reading'));
    await tester.tap(find.text('Finish reading'));
    await tester.pumpAndSettle();
    expect(await future, 1);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  final navigator = GlobalKey<NavigatorState>();
  late BuildContext context;
}

Future<_Fixture> _host(
  WidgetTester tester, {
  Widget child = const SizedBox(),
  ValueNotifier<MediaQueryData>? media,
  List<NavigatorObserver> observers = const [],
}) async {
  final fixture = _Fixture();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: fixture.navigator,
      navigatorObservers: observers,
      builder: (context, child) {
        final glass = LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: child!,
        );
        return media == null
            ? glass
            : ValueListenableBuilder<MediaQueryData>(
                valueListenable: media,
                builder: (_, data, _) => MediaQuery(data: data, child: glass),
              );
      },
      home: Builder(
        builder: (context) {
          fixture.context = context;
          return Scaffold(body: child);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

class _Routes extends NavigatorObserver {
  Route<dynamic>? last;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      last = route;
}

class _ReplacementPopup extends PopupRoute<String> {
  @override
  Color? get barrierColor => Colors.black12;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Dismiss';
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const Center(child: Text('Replacement'));
}
