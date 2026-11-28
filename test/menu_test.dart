import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/menu.dart';
import 'package:flutter_adaptive_liquid_glass/src/controls.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_capsule.dart';
import 'package:flutter_adaptive_liquid_glass/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a42sAAAAASUVORK5CYII=',
  );

  testWidgets(
    'default native menu shares typed tree data and reuses equivalent snapshots',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final methods = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final channel = MethodChannel(
            'flutter_adaptive_liquid_glass/capsule/${arguments['id']}',
          );
          methods.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async => null);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in methods) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      final selections = <_Action>[];
      Widget menu({
        bool enabled = true,
        String subtitle = 'Actions',
        bool custom = false,
      }) => LiquidGlassMenuButton<_Action>(
        label: 'Options',
        triggerChild: custom
            ? const SizedBox(
                width: 92,
                height: 38,
                child: Text('Custom trigger'),
              )
            : null,
        onSelected: selections.add,
        items: [
          LiquidGlassMenuItem(
            value: _Action.group,
            label: 'Group',
            subtitle: subtitle,
            displayInline: true,
            sfSymbol: 'folder',
            children: [
              LiquidGlassMenuItem(
                value: _Action.rename,
                label: 'Rename',
                iconPng: png,
                selected: true,
                destructive: true,
                enabled: enabled,
              ),
            ],
          ),
        ],
      );
      NativeCapsuleMenu data() =>
          tester.widget<NativeCapsule>(find.byType(NativeCapsule)).menu!;

      await _host(tester, menu(), glass: const _NativeMenuTheme());
      final initial = data();
      final branch = initial.items.single;
      final child = (branch['children'] as List<Map<String, Object?>>).single;
      expect(initial.enabled, isTrue);
      expect(branch['symbol'], 'folder');
      expect(branch['subtitle'], 'Actions');
      expect(branch['displayInline'], isTrue);
      expect(child['png'], png);
      expect(child['selected'], isTrue);
      expect(child['destructive'], isTrue);
      initial.onSelected(child['id'] as int);
      initial.onSelected(branch['id'] as int);
      expect(selections, [_Action.rename]);

      await _host(tester, menu(), glass: const _NativeMenuTheme());
      expect(data().revision, initial.revision);
      await _host(
        tester,
        menu(subtitle: 'Updated actions'),
        glass: const _NativeMenuTheme(),
      );
      expect(data().revision, greaterThan(initial.revision));
      expect(data().items.single['subtitle'], 'Updated actions');
      await _host(
        tester,
        menu(enabled: false),
        glass: const _NativeMenuTheme(),
      );
      expect(data().revision, greaterThan(initial.revision));
      data().onSelected(child['id'] as int);
      expect(selections, [_Action.rename]);

      await _host(tester, menu(custom: true), glass: const _NativeMenuTheme());
      final native = tester.widget<UiKitView>(find.byType(UiKitView));
      expect((native.creationParams as Map)['customMenuTrigger'], isTrue);
      expect(tester.getSize(find.byType(UiKitView)), const Size(92, 38));
      expect(find.text('Custom trigger'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('imperative native menu passes the anchor and typed leaf value', (
    tester,
  ) async {
    const channel = MethodChannel('flutter_adaptive_liquid_glass/menu');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const anchorKey = Key('menu-anchor');
    await _host(
      tester,
      const SizedBox(key: anchorKey, width: 116, height: 48),
      glass: const _NativeMenuTheme(),
    );
    final anchor = find.byKey(anchorKey);
    final bounds = tester.getRect(anchor);
    final context = tester.element(anchor);
    final calls = <MethodCall>[];
    var chooseEnabled = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final model = call.arguments as Map;
      final items = model['items'] as List;
      final item = items[chooseEnabled ? 0 : 1] as Map;
      return item['id'];
    });
    Future<_Action?> show() => showLiquidGlassMenu(
      context: context,
      anchorContext: context,
      items: const [
        LiquidGlassMenuItem(value: _Action.rename, label: 'Rename'),
        LiquidGlassMenuItem(
          value: _Action.group,
          label: 'Unavailable',
          enabled: false,
        ),
      ],
    );
    final enabled = show();
    await tester.pumpAndSettle();
    expect(await enabled, _Action.rename);
    expect(calls.single.method, 'showMenu');
    expect((calls.single.arguments as Map)['anchor'], [
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    ]);
    chooseEnabled = false;
    final disabled = show();
    await tester.pumpAndSettle();
    expect(await disabled, isNull);
  });

  for (final coverRoute in [true, false]) {
    testWidgets(
      'native menu retires its request when ${coverRoute ? 'the route is covered' : 'the anchor is removed'}',
      (tester) async {
        const channel = MethodChannel('flutter_adaptive_liquid_glass/menu');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final reply = Completer<int>();
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'showMenu' ? reply.future : null;
        });

        final anchorVisible = ValueNotifier(true);
        addTearDown(anchorVisible.dispose);
        const anchorKey = Key('menu-anchor');
        await _host(
          tester,
          ValueListenableBuilder(
            valueListenable: anchorVisible,
            builder: (_, visible, _) => visible
                ? const SizedBox(key: anchorKey, width: 116, height: 48)
                : const SizedBox.shrink(),
          ),
          glass: const _NativeMenuTheme(),
        );
        final anchor = tester.element(find.byKey(anchorKey));
        final selected = showLiquidGlassMenu<int>(
          context: anchor,
          anchorContext: anchor,
          items: const [LiquidGlassMenuItem(value: 1, label: 'One')],
        );
        await tester.pump();
        final model = calls.single.arguments as Map;
        expect(calls.single.method, 'showMenu');
        final navigator = Navigator.of(anchor);
        if (coverRoute) {
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Other route')),
              ),
            ),
          );
        } else {
          anchorVisible.value = false;
        }
        await tester.pumpAndSettle();
        expect(calls.map((call) => call.method), ['showMenu', 'cancelMenu']);
        expect(calls.last.arguments, model['requestId']);

        if (coverRoute) {
          navigator.pop();
          await tester.pumpAndSettle();
          expect(find.byKey(anchorKey), findsOneWidget);
        }
        final item = (model['items'] as List).single as Map;
        reply.complete(item['id'] as int);
        await tester.pump();
        expect(await selected, isNull);
      },
    );
  }

  testWidgets('imperative Flutter menu preserves editor focus and groups', (
    tester,
  ) async {
    final inputFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    const anchorKey = Key('menu-anchor');
    await _host(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(focusNode: inputFocus),
          const SizedBox(key: anchorKey, width: 116, height: 48),
        ],
      ),
    );
    inputFocus.requestFocus();
    await tester.pump();
    expect(inputFocus.hasPrimaryFocus, isTrue);

    final context = tester.element(find.byKey(anchorKey));
    final selected = showLiquidGlassMenu<int>(
      context: context,
      anchorContext: context,
      items: const [
        LiquidGlassMenuItem(
          value: 0,
          label: 'Options',
          displayInline: true,
          children: [
            LiquidGlassMenuItem(
              value: 1,
              label: 'Selected option',
              subtitle: 'Current setting',
              selected: true,
            ),
            LiquidGlassMenuItem(value: 2, label: 'Unavailable', enabled: false),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(inputFocus.hasPrimaryFocus, isTrue);
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Current setting'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Selected option'), findsOneWidget);
    await tester.tap(find.text('Selected option'));
    await tester.pumpAndSettle();
    expect(await selected, 1);
    expect(inputFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('Flutter custom trigger owns the tap without a Material host', (
    tester,
  ) async {
    int? selected;
    await _host(
      tester,
      LiquidGlassMenuButton<int>(
        semanticLabel: 'Choose a value',
        triggerChild: const SizedBox(
          width: 80,
          height: 44,
          child: Text('Custom appearance'),
        ),
        items: const [LiquidGlassMenuItem(value: 1, label: 'One')],
        onSelected: (value) => selected = value,
      ),
      scaffold: false,
    );
    await tester.tapAt(tester.getCenter(find.text('Custom appearance')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('Flutter menu shows the bitmap and returns the same typed item', (
    tester,
  ) async {
    _Action? selected;
    await _host(
      tester,
      LiquidGlassMenuButton<_Action>(
        label: 'Open bitmap menu',
        items: [
          LiquidGlassMenuItem(
            value: _Action.rename,
            label: 'Rename',
            sfSymbol: 'pencil',
            iconPng: png,
          ),
        ],
        onSelected: (value) => selected = value,
      ),
    );
    await tester.tap(find.text('Open bitmap menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(selected, _Action.rename);
  });

  testWidgets('menu selection restores trigger keyboard focus for reopening', (
    tester,
  ) async {
    await _host(
      tester,
      LiquidGlassMenuButton<int>(
        label: 'Keyboard options',
        items: const [LiquidGlassMenuItem(value: 1, label: 'Choose')],
      ),
    );
    final focus = Focus.of(tester.element(find.text('Keyboard options')));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
  });

  testWidgets('dialog and theme changes preserve trigger keyboard focus', (
    tester,
  ) async {
    final settings = ValueNotifier(false);
    addTearDown(settings.dispose);
    await _host(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: settings,
        builder: (_, reduced, _) => LiquidGlassTheme(
          data: LiquidGlassThemeData(
            mode: LiquidGlassMode.fallback,
            reduceMotion: reduced,
            colors: LiquidGlassColors(
              accent: reduced ? Colors.red : Colors.blue,
            ),
          ),
          child: LiquidGlassButton(label: 'Target', onPressed: () {}),
        ),
      ),
    );
    final context = tester.element(find.text('Target'));
    final focus = Focus.of(context);
    focus.requestFocus();
    await tester.pump();
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('Overlay')),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Overlay'))).pop();
    await tester.pumpAndSettle();
    await dialog;
    expect(focus.hasFocus, isTrue);
    settings.value = true;
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Target'))), same(focus));
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('default trigger opens once on long press and reopens on tap', (
    tester,
  ) async {
    var cancels = 0;
    await _host(
      tester,
      LiquidGlassMenuButton<int>(
        label: 'Options',
        items: const [LiquidGlassMenuItem(value: 1, label: 'Choose')],
        onCanceled: () => cancels++,
      ),
    );
    await tester.longPress(find.text('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(cancels, 1);
    expect(find.text('Choose'), findsNothing);
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
  });

  testWidgets('explicit trigger modes expose only the chosen gesture', (
    tester,
  ) async {
    for (final trigger in [
      LiquidGlassMenuTrigger.tap,
      LiquidGlassMenuTrigger.longPress,
    ]) {
      await _host(
        tester,
        LiquidGlassMenuButton<int>(
          key: ValueKey(trigger),
          label: 'Open',
          trigger: trigger,
          items: const [LiquidGlassMenuItem(value: 1, label: 'Choose')],
        ),
      );
      final button = tester.widget<LiquidGlassButton>(
        find.byType(LiquidGlassButton),
      );
      expect(button.onPressed != null, trigger == LiquidGlassMenuTrigger.tap);
      expect(
        button.onLongPress != null,
        trigger == LiquidGlassMenuTrigger.longPress,
      );
      if (trigger == LiquidGlassMenuTrigger.longPress) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Choose'), findsNothing);
        await tester.longPress(find.text('Open'));
      } else {
        await tester.tap(find.text('Open'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Choose'), findsOneWidget);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'rapid branch and back taps cannot duplicate or underflow the path',
    (tester) async {
      await _host(
        tester,
        LiquidGlassMenuButton<int>(
          label: 'Open hierarchy',
          items: const [
            LiquidGlassMenuItem(
              value: 1,
              label: 'Branch',
              children: [LiquidGlassMenuItem(value: 2, label: 'Leaf')],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Open hierarchy'));
      await tester.pumpAndSettle();
      final branch = tester.getCenter(find.text('Branch'));
      await tester.tapAt(branch);
      await tester.tapAt(branch);
      await tester.pumpAndSettle();
      expect(find.text('Leaf'), findsOneWidget);
      final back = tester.getCenter(find.text('Back'));
      await tester.tapAt(back);
      await tester.tapAt(back);
      await tester.pumpAndSettle();
      expect(find.text('Leaf'), findsNothing);
      expect(find.text('Branch'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('menu can be selected with keyboard focus and enter', (
    tester,
  ) async {
    int? selected;
    await _host(
      tester,
      LiquidGlassMenuButton<int>(
        label: 'Keyboard menu',
        onSelected: (value) => selected = value,
        items: const [
          LiquidGlassMenuItem(value: 0, label: 'Disabled', enabled: false),
          LiquidGlassMenuItem(value: 1, label: 'Enabled'),
        ],
      ),
    );
    await tester.tap(find.text('Keyboard menu'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.text('Enabled'), findsNothing);
  });

  testWidgets('independent menu triggers select their own values once', (
    tester,
  ) async {
    final selections = <String>[];
    await _host(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 3; i++)
            LiquidGlassMenuButton<String>(
              label: 'Menu $i',
              items: [LiquidGlassMenuItem(value: '$i', label: 'Action $i')],
              onSelected: selections.add,
            ),
        ],
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Menu $i'));
      await tester.pumpAndSettle();
      final position = tester.getCenter(find.text('Action $i'));
      await tester.tapAt(position);
      await tester.tapAt(position);
      await tester.pumpAndSettle();
    }
    expect(selections, ['0', '1', '2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hierarchy preserves selected and disabled actions with back row',
    (tester) async {
      final selections = <String>[];
      await _host(
        tester,
        LiquidGlassMenuButton<String>(
          label: 'Options',
          onSelected: selections.add,
          items: const [
            LiquidGlassMenuItem(
              value: 'disabled',
              label: 'Unavailable',
              enabled: false,
            ),
            LiquidGlassMenuItem(
              value: 'branch',
              label: 'More options',
              children: [
                LiquidGlassMenuItem(
                  value: 'selected',
                  label: 'Selected option',
                  selected: true,
                ),
                LiquidGlassMenuItem(
                  value: 'delete',
                  label: 'Remove',
                  destructive: true,
                  icon: Icons.delete,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsOneWidget);
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(selections, ['delete']);
    },
  );

  testWidgets('barrier reports cancellation and trigger can reopen', (
    tester,
  ) async {
    var cancels = 0;
    final selections = <int>[];
    await _host(
      tester,
      LiquidGlassMenuButton<int>(
        label: 'Open',
        items: const [LiquidGlassMenuItem(value: 1, label: 'Choose')],
        onSelected: selections.add,
        onCanceled: () => cancels++,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(cancels, 1);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(selections, [1]);
    expect(cancels, 1);
  });

  testWidgets(
    'removing trigger dismisses its menu without callback after dispose',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      var calls = 0;
      await _host(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, show, _) => show
              ? LiquidGlassMenuButton<int>(
                  label: 'Open',
                  items: const [LiquidGlassMenuItem(value: 1, label: 'Choose')],
                  onCanceled: () => calls++,
                  onSelected: (_) => calls++,
                )
              : const Text('Gone'),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Choose'), findsNothing);
      expect(find.text('Gone'), findsOneWidget);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom trigger receives disabled state and local theme is kept',
    (tester) async {
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await _host(
        tester,
        LiquidGlassTheme(
          data: const LiquidGlassThemeData(
            mode: LiquidGlassMode.opaque,
            colors: LiquidGlassColors(foreground: Colors.purple),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (_, canOpen, _) => LiquidGlassMenuButton<int>(
              enabled: canOpen,
              items: const [LiquidGlassMenuItem(value: 1, label: 'Themed')],
              builder: (_, open) => TextButton(
                onPressed: open,
                child: Text(
                  open == null ? 'Disabled trigger' : 'Enabled trigger',
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      enabled.value = true;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enabled trigger'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Themed'));
      expect(LiquidGlassTheme.of(context).mode, LiquidGlassMode.opaque);
      expect(DefaultTextStyle.of(context).style.color, Colors.purple);
      await tester.tap(find.text('Themed'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('menu fits its widest row only when requested', (tester) async {
    for (final fit in [false, true]) {
      await _host(
        tester,
        LiquidGlassMenuButton<int>(
          label: 'Options',
          fitContent: fit,
          items: const [
            LiquidGlassMenuItem(value: 1, label: 'Short'),
            LiquidGlassMenuItem(value: 2, label: 'Longer row'),
          ],
        ),
      );
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      final width = tester
          .getSize(find.byKey(const ValueKey('liquid-glass-popover-surface')))
          .width;
      if (fit) {
        expect(width, lessThan(300));
        expect(width, greaterThanOrEqualTo(160));
      } else {
        expect(width, 300);
      }
      await tester.tap(find.text('Short'));
      await tester.pumpAndSettle();
    }
  });
}

enum _Action { group, rename }

class _NativeMenuTheme extends LiquidGlassThemeData {
  const _NativeMenuTheme();

  @override
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) => LiquidGlassMode.native;
}

Future<void> _host(
  WidgetTester tester,
  Widget child, {
  bool scaffold = true,
  LiquidGlassThemeData glass = const LiquidGlassThemeData(
    mode: LiquidGlassMode.fallback,
  ),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => LiquidGlassTheme(data: glass, child: child!),
      home: scaffold
          ? Scaffold(body: Center(child: child))
          : Center(child: child),
    ),
  );
  await tester.pumpAndSettle();
}
