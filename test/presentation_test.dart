import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
import 'package:flutter_adaptive_liquid_glass/src/navigator_observer.dart';
import 'package:flutter_adaptive_liquid_glass/src/presentation.dart';
import 'package:flutter_adaptive_liquid_glass/src/surface.dart';
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

  group('fitContent sheet', () {
    const surface = ValueKey('liquid-glass-sheet-surface');
    const handleKey = ValueKey('liquid-glass-sheet-handle');
    const contentKey = ValueKey('fit-content');

    testWidgets('is as tall as its content and rests on the safe area', (
      tester,
    ) async {
      final fixture = await _host(tester);
      final future = showLiquidGlassSheet<String>(
        context: fixture.context,
        fitContent: true,
        builder: (context) => Column(
          key: contentKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 120, child: Center(child: Text('Compact'))),
            TextButton(
              onPressed: () => Navigator.pop(context, 'done'),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byKey(surface));
      final content = tester.getSize(find.byKey(contentKey));
      // The grab handle is 32 high; nothing else adds to the content.
      expect(panel.height, content.height + 32);
      expect(
        panel.height,
        lessThan(600 * LiquidGlassSheetDetent.medium.fraction),
      );
      // The default 800x600 test view has no insets: the route keeps its 8
      // point bottom margin and caps the width at 640.
      expect(panel.bottom, 592);
      expect(panel.width, 640);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(surface), findsNothing);
      expect(await future, 'done');
    });

    testWidgets('keeps its full width without a handle', (tester) async {
      final fixture = await _host(tester);
      showLiquidGlassSheet<void>(
        context: fixture.context,
        fitContent: true,
        showDragHandle: false,
        builder: (_) => const Text('Narrow'),
      );
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byKey(surface));
      expect(find.byKey(handleKey), findsNothing);
      expect(panel.width, 640);
      expect(panel.height, tester.getSize(find.text('Narrow')).height);
    });

    testWidgets('stops at the large detent and lets its content scroll', (
      tester,
    ) async {
      final fixture = await _host(tester);
      ScrollController? controller;
      showLiquidGlassSheet<void>(
        context: fixture.context,
        fitContent: true,
        builder: (context) {
          controller = PrimaryScrollController.of(context);
          return ListView(
            shrinkWrap: true,
            primary: true,
            children: [
              for (var i = 0; i < 50; i++) ListTile(title: Text('Row $i')),
            ],
          );
        },
      );
      await tester.pumpAndSettle();
      // 600 high, less the 12 top and 8 bottom margins.
      expect(
        tester.getSize(find.byKey(surface)).height,
        closeTo((600 - 12 - 8) * LiquidGlassSheetDetent.large.fraction, .01),
      );
      await tester.drag(find.text('Row 2'), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(controller!.offset, greaterThan(0));
    });

    testWidgets('the handle pulls the sheet down to dismiss or springs back', (
      tester,
    ) async {
      final fixture = await _host(tester);
      final future = showLiquidGlassSheet<String>(
        context: fixture.context,
        fitContent: true,
        builder: (_) => const SizedBox(height: 200, child: Text('Body')),
      );
      await tester.pumpAndSettle();
      final handle = find.byKey(handleKey);
      final top = tester.getTopLeft(handle).dy;

      // The sheet is 232 high, so 40 is less than a quarter of it.
      final short = await tester.startGesture(tester.getCenter(handle));
      await short.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getTopLeft(handle).dy, greaterThan(top));
      await short.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(handle).dy, top);
      expect(find.text('Body'), findsOneWidget);

      await tester.drag(handle, const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
      expect(await future, isNull);
    });

    testWidgets('a quick downward flick dismisses a barely moved sheet', (
      tester,
    ) async {
      final fixture = await _host(tester);
      final future = showLiquidGlassSheet<String>(
        context: fixture.context,
        fitContent: true,
        builder: (_) => const SizedBox(height: 200, child: Text('Body')),
      );
      await tester.pumpAndSettle();
      // 30 points is far less than a quarter of the sheet, but 2000 points per
      // second is a flick. `WidgetTester.fling` cannot express this: its
      // timestamps collapse to the same millisecond over so short a distance.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(handleKey)),
      );
      for (var step = 1; step <= 3; step++) {
        await gesture.moveBy(
          const Offset(0, 10),
          timeStamp: Duration(milliseconds: 5 * step),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
      expect(await future, isNull);
    });

    testWidgets('a slow short pull is not mistaken for a flick', (
      tester,
    ) async {
      final fixture = await _host(tester);
      showLiquidGlassSheet<String>(
        context: fixture.context,
        fitContent: true,
        builder: (_) => const SizedBox(height: 200, child: Text('Body')),
      );
      await tester.pumpAndSettle();
      final handle = find.byKey(handleKey);
      final top = tester.getTopLeft(handle).dy;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      for (var step = 1; step <= 3; step++) {
        await gesture.moveBy(
          const Offset(0, 10),
          timeStamp: Duration(milliseconds: 100 * step),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
      expect(tester.getTopLeft(handle).dy, top);
    });

    testWidgets('does not move without drag, and honours the barrier', (
      tester,
    ) async {
      final fixture = await _host(tester);
      final future = showLiquidGlassSheet<String>(
        context: fixture.context,
        fitContent: true,
        enableDrag: false,
        builder: (_) => const SizedBox(height: 200, child: Text('Body')),
      );
      await tester.pumpAndSettle();
      final handle = find.byKey(handleKey);
      final top = tester.getTopLeft(handle).dy;
      await tester.drag(handle, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(handle).dy, top);
      expect(find.text('Body'), findsOneWidget);
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
      expect(await future, isNull);
    });

    testWidgets('shrinks above the keyboard and keeps its content state', (
      tester,
    ) async {
      final media = ValueNotifier(const MediaQueryData(size: Size(800, 600)));
      addTearDown(media.dispose);
      final fixture = await _host(tester, media: media);
      showLiquidGlassSheet<void>(
        context: fixture.context,
        fitContent: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          primary: true,
          children: [
            Text('Inset ${MediaQuery.viewInsetsOf(context).bottom}'),
            const TextField(key: ValueKey('draft')),
            for (var i = 0; i < 40; i++) ListTile(title: Text('Row $i')),
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
      final panel = tester.getRect(find.byKey(surface));
      expect(panel.bottom, 392);
      expect(
        panel.height,
        closeTo(
          (600 - 200 - 12 - 8) * LiquidGlassSheetDetent.large.fraction,
          .01,
        ),
      );
    });

    testWidgets('content sees none of the insets the sheet already applied', (
      tester,
    ) async {
      final media = ValueNotifier(
        const MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.fromLTRB(40, 20, 40, 34),
        ),
      );
      addTearDown(media.dispose);
      final fixture = await _host(tester, media: media);
      EdgeInsets? padding;
      showLiquidGlassSheet<void>(
        context: fixture.context,
        fitContent: true,
        builder: (context) {
          padding = MediaQuery.paddingOf(context);
          return const SizedBox(height: 80);
        },
      );
      await tester.pumpAndSettle();
      expect(padding, EdgeInsets.zero);
      final panel = tester.getRect(find.byKey(surface));
      expect(panel.bottom, 600 - 34);
      expect(panel.left, greaterThanOrEqualTo(40));
    });

    testWidgets('detents are ignored, and still checked without it', (
      tester,
    ) async {
      final fixture = await _host(tester);
      expect(
        () => showLiquidGlassSheet<void>(
          context: fixture.context,
          detents: const [],
          builder: (_) => const SizedBox(),
        ),
        throwsArgumentError,
      );
      showLiquidGlassSheet<void>(
        context: fixture.context,
        fitContent: true,
        detents: const [],
        builder: (_) => const SizedBox(height: 40),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(surface), findsOneWidget);
    });
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
    const channel = MethodChannel('flutter_adaptive_liquid_glass/lifecycle');
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

  testWidgets('two alert actions sit side by side, cancel first', (
    tester,
  ) async {
    final fixture = await _host(tester);
    final future = showLiquidGlassAlert<int>(
      context: fixture.context,
      title: const Text('Confirm'),
      actions: const [
        LiquidGlassAlertAction(label: 'Delete', value: 1, destructive: true),
        LiquidGlassAlertAction(label: 'Keep', value: 0, cancel: true),
      ],
    );
    await tester.pumpAndSettle();
    final keep = tester.getRect(find.widgetWithText(TextButton, 'Keep'));
    final delete = tester.getRect(find.widgetWithText(TextButton, 'Delete'));
    expect(keep.top, delete.top);
    expect(keep.right, lessThanOrEqualTo(delete.left));
    expect(keep.width, closeTo(delete.width, .5));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await future, 1);
  });

  testWidgets('alert actions stack for large text and for three actions', (
    tester,
  ) async {
    final media = ValueNotifier(
      const MediaQueryData(
        size: Size(800, 600),
        textScaler: TextScaler.linear(2),
      ),
    );
    addTearDown(media.dispose);
    final fixture = await _host(tester, media: media);
    var future = showLiquidGlassAlert<int>(
      context: fixture.context,
      actions: const [
        LiquidGlassAlertAction(label: 'First', value: 1),
        LiquidGlassAlertAction(label: 'Second', value: 2),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.widgetWithText(TextButton, 'Second')).dy,
      greaterThan(
        tester.getBottomLeft(find.widgetWithText(TextButton, 'First')).dy - 1,
      ),
    );
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(await future, 1);

    media.value = const MediaQueryData(size: Size(800, 600));
    await tester.pumpAndSettle();
    future = showLiquidGlassAlert<int>(
      context: fixture.context,
      actions: const [
        LiquidGlassAlertAction(label: 'One', value: 1),
        LiquidGlassAlertAction(label: 'Two', value: 2),
        LiquidGlassAlertAction(label: 'Three', value: 3),
      ],
    );
    await tester.pumpAndSettle();
    final one = tester.getRect(find.widgetWithText(TextButton, 'One'));
    final two = tester.getRect(find.widgetWithText(TextButton, 'Two'));
    expect(two.top, greaterThanOrEqualTo(one.bottom));
    await tester.tap(find.text('Three'));
    await tester.pumpAndSettle();
    expect(await future, 3);
  });

  testWidgets('action sheet keeps cancel in its own group below the rest', (
    tester,
  ) async {
    final fixture = await _host(tester);
    final future = showLiquidGlassAlert<String>(
      context: fixture.context,
      style: LiquidGlassAlertStyle.actionSheet,
      actions: const [
        LiquidGlassAlertAction(label: 'Edit', value: 'edit'),
        LiquidGlassAlertAction(label: 'Delete', value: 'delete'),
        LiquidGlassAlertAction(label: 'Dismiss', value: 'x', cancel: true),
      ],
    );
    await tester.pumpAndSettle();
    final surfaces = find.byType(LiquidGlassSurface);
    expect(surfaces, findsNWidgets(2));
    expect(
      find.descendant(of: surfaces.first, matching: find.text('Delete')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: surfaces.last, matching: find.text('Dismiss')),
      findsOneWidget,
    );
    final gap =
        tester.getTopLeft(surfaces.last).dy -
        tester.getBottomLeft(surfaces.first).dy;
    expect(gap, closeTo(8, .5));
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('popover scales from the edge facing its anchor', (tester) async {
    final top = GlobalKey(), bottom = GlobalKey();
    final fixture = await _host(
      tester,
      child: Stack(
        children: [
          Positioned(
            left: 100,
            top: 40,
            child: SizedBox(key: top, width: 48, height: 48),
          ),
          Positioned(
            left: 100,
            top: 520,
            child: SizedBox(key: bottom, width: 48, height: 48),
          ),
        ],
      ),
    );
    const panelKey = ValueKey('liquid-glass-popover-surface');
    Alignment origin() {
      final transforms = tester.widgetList<Transform>(
        find.ancestor(
          of: find.byKey(panelKey),
          matching: find.byType(Transform),
        ),
      );
      return transforms
          .map((transform) => transform.alignment)
          .whereType<Alignment>()
          .single;
    }

    for (final (anchor, edge) in [(top, -1.0), (bottom, 1.0)]) {
      final future = showLiquidGlassPopover<void>(
        context: fixture.context,
        anchorContext: anchor.currentContext!,
        width: 240,
        builder: (_) => const SizedBox(height: 100, child: Text('Panel')),
      );
      // The anchor is measured after the first frame, then the layout records
      // the origin that the next animation frame reads.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      expect(origin().y, edge);
      // Anchor centre x is 124; the panel starts at x = 100 and is 240 wide.
      expect(origin().x, closeTo(24 / 240 * 2 - 1, .001));
      fixture.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await future;
    }
  });

  testWidgets('popover width is fixed unless it fits its content', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final fixture = await _host(
      tester,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: anchor, width: 48, height: 48),
      ),
    );
    const panelKey = ValueKey('liquid-glass-popover-surface');
    Future<double> widthOf({required bool fit, required double content}) async {
      final future = showLiquidGlassPopover<void>(
        context: fixture.context,
        anchorContext: anchor.currentContext!,
        width: 320,
        fitContent: fit,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [SizedBox(width: content, height: 40)],
        ),
      );
      await tester.pumpAndSettle();
      final width = tester.getSize(find.byKey(panelKey)).width;
      fixture.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await future;
      return width;
    }

    expect(await widthOf(fit: false, content: 200), 320);
    expect(await widthOf(fit: true, content: 200), 200);
    expect(await widthOf(fit: true, content: 50), 160);
    expect(await widthOf(fit: true, content: 900), 320);
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
