import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/src/menu.dart';
import 'package:flutter_adaptive_liquid_glass/src/controls.dart';
import 'package:flutter_adaptive_liquid_glass/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

Future<void> _host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => LiquidGlassTheme(
        data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
        child: child!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}
