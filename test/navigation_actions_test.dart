import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a42sAAAAASUVORK5CYII=',
  );

  testWidgets('Flutter navigation shares each side and keeps menu data', (
    tester,
  ) async {
    final outcomes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.opaque),
          child: Scaffold(
            appBar: LiquidGlassNavigationBar(
              title: 'Inbox',
              leading: [
                LiquidGlassAction(
                  id: 'bitmap',
                  label: 'Bitmap button',
                  iconPng: png,
                  badge: '2',
                  onPressed: () => outcomes.add('bitmap'),
                ),
                LiquidGlassAction(
                  id: 'file-menu',
                  label: 'File options',
                  icon: Icons.folder,
                  menu: LiquidGlassNavigationMenu(
                    items: const [
                      LiquidGlassMenuItem(
                        value: 'organize',
                        label: 'Organize',
                        children: [
                          LiquidGlassMenuItem(
                            value: 'archive',
                            label: 'Archive',
                          ),
                        ],
                      ),
                    ],
                    onSelected: outcomes.add,
                  ),
                ),
              ],
              actions: [
                LiquidGlassAction(
                  id: 'disabled-menu',
                  label: 'Disabled menu',
                  icon: Icons.edit,
                  badge: '',
                  menu: LiquidGlassNavigationMenu(
                    enabled: false,
                    items: const [
                      LiquidGlassMenuItem(value: 'edit', label: 'Edit'),
                    ],
                    onSelected: outcomes.add,
                  ),
                ),
                LiquidGlassAction(
                  id: 'done',
                  label: 'Done',
                  onPressed: () => outcomes.add('done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LiquidGlassSurface), findsNWidgets(2));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(Badge), findsNWidgets(2));
    final bitmap = find.byKey(const ValueKey('bitmap'));
    final fileMenu = find.byKey(const ValueKey('file-menu'));
    final disabledMenu = find.byKey(const ValueKey('disabled-menu'));
    final done = find.byKey(const ValueKey('done'));
    expect(
      tester.getCenter(bitmap).dx,
      lessThan(tester.getCenter(fileMenu).dx),
    );
    expect(
      tester.getCenter(disabledMenu).dx,
      lessThan(tester.getCenter(done).dx),
    );

    await tester.tap(bitmap);
    await tester.tap(disabledMenu);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    await tester.tap(fileMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(done);
    expect(outcomes, ['bitmap', 'archive', 'done']);
  });

  testWidgets('crowded Flutter action trays scroll independently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final outcomes = <String>[];
    List<LiquidGlassAction> tray(String side, {bool badged = false}) => [
      for (var i = 0; i < 5; i++)
        LiquidGlassAction(
          id: '$side$i',
          label: '$side $i',
          icon: Icons.circle,
          badge: badged && i == 0 ? '1' : null,
          onPressed: () => outcomes.add('$side$i'),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.opaque),
          child: Scaffold(
            appBar: LiquidGlassNavigationBar(
              title: 'Inbox',
              leading: tray('leading', badged: true),
              actions: tray('trailing'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Inbox')).width, greaterThan(0));
    final lastLeading = find.byKey(const ValueKey('leading4'));
    final lastTrailing = find.byKey(const ValueKey('trailing4'));
    final originalTrailing = tester.getCenter(lastTrailing);
    await tester.ensureVisible(lastLeading);
    await tester.pumpAndSettle();
    expect(tester.getCenter(lastTrailing), originalTrailing);
    await tester.tap(lastLeading);
    await tester.ensureVisible(lastTrailing);
    await tester.pumpAndSettle();
    await tester.tap(lastTrailing);
    expect(outcomes, ['leading4', 'trailing4']);
  });
}
