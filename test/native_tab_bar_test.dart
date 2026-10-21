import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the native branch on a Dart host without pretending that its real
// operating system has native Liquid Glass support.
class _NativeTheme extends LiquidGlassThemeData {
  const _NativeTheme();

  @override
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) => LiquidGlassMode.native;
}

const _items = [
  LiquidGlassTabItem(label: 'Alpha', icon: Icons.home, sfSymbol: 'house'),
  LiquidGlassTabItem(
    label: 'Beta',
    icon: Icons.star_border,
    selectedIcon: Icons.star,
    sfSymbol: 'star',
    badge: '3',
  ),
  LiquidGlassTabItem(label: 'Gamma', icon: Icons.settings, sfSymbol: 'gear'),
];

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final views = <int, Map<Object?, Object?>>{};
  final calls = <int, List<MethodCall>>{};
  late int last;

  setUp(() {
    views.clear();
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        final arguments = call.arguments;
        if (call.method != 'create' ||
            arguments is! Map ||
            arguments['viewType'] != NativeTabBar.viewType) {
          return null;
        }
        final id = last = arguments['id'] as int;
        views[id] =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(arguments['params'] as Uint8List),
                )
                as Map<Object?, Object?>;
        calls[id] = [];
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel('${NativeTabBar.viewType}/$id'),
          (call) async {
            calls[id]!.add(call);
            return null;
          },
        );
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    for (final id in calls.keys) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('${NativeTabBar.viewType}/$id'),
        null,
      );
    }
  });

  Future<void> send(String method, [Object? arguments]) =>
      binding.defaultBinaryMessenger.handlePlatformMessage(
        '${NativeTabBar.viewType}/$last',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  List<Object?> sent(int id, String method) => [
    for (final call in calls[id]!)
      if (call.method == method) call.arguments,
  ];

  Widget host({
    int selected = 0,
    ValueChanged<int>? onSelected,
    List<LiquidGlassTabItem> items = _items,
    LiquidGlassAction? action,
  }) => MaterialApp(
    home: LiquidGlassTheme(
      data: const _NativeTheme(),
      child: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: LiquidGlassTabBar(
          items: items,
          selectedIndex: selected,
          onSelected: onSelected ?? (_) {},
          trailingAction: action,
        ),
      ),
    ),
  );

  testWidgets('creates the system tab bar with its tabs and action', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        selected: 1,
        action: LiquidGlassAction(id: 'find', label: 'Find', onPressed: () {}),
      ),
    );
    // Like the previous provider, the first frame waits for the tab payloads.
    expect(find.byType(UiKitView), findsNothing);
    await tester.pump();
    final params = views[last]!;
    final tabs = [for (final tab in params['tabs'] as List) tab as Map];
    expect([for (final tab in tabs) tab['label']], ['Alpha', 'Beta', 'Gamma']);
    // A symbol tab keeps its symbol when selected, ignoring selectedIcon.
    expect([tabs[1]['symbol'], tabs[1]['selectedSymbol']], ['star', 'star']);
    expect(tabs[1]['png'], isNull);
    expect([for (final tab in tabs) tab['badge']], [null, '3', null]);
    final action = params['action'] as Map;
    expect(action['label'], 'Find');
    expect(action['symbol'], 'magnifyingglass');
    expect(params['currentIndex'], 1);
    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(params['selectedItemColor'], theme.colorScheme.primary.toARGB32());
    expect(params['brightness'], 'light');
    expect(params['glassOverflow'], NativeTabBar.glassOverflow);
    expect(params['suppressed'], isFalse);
    expect(params['popupOwner'], isFalse);
    // A 72-point bar below a 20-point band for its glass.
    expect(tester.getSize(find.byType(UiKitView)).height, 92);
  }, variant: _ios);

  testWidgets('reports a user selection and ignores an index out of range', (
    tester,
  ) async {
    var selected = 0;
    final reported = <int>[];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          selected: selected,
          onSelected: (value) => setState(() {
            reported.add(value);
            selected = value;
          }),
        ),
      ),
    );
    await tester.pump();
    final id = last;
    await send('tabSelected', 2);
    await tester.pump();
    expect(reported, [2]);
    // An adopted selection is not sent back to the bar that made it.
    expect(sent(id, 'setSelectedIndex'), [0]);
    await send('tabSelected', 7);
    await tester.pump();
    expect(reported, [2]);
    // The bar is put back on the current tab.
    expect(sent(id, 'setSelectedIndex'), [0, 2]);
  }, variant: _ios);

  testWidgets('reverts a selection the parent does not adopt', (tester) async {
    final reported = <int>[];
    await tester.pumpWidget(host(onSelected: reported.add));
    await tester.pump();
    final id = last;
    calls[id]!.clear();
    await send('tabSelected', 1);
    expect(reported, [1]);
    expect(sent(id, 'setSelectedIndex'), isEmpty);
    await tester.pump();
    expect(sent(id, 'setSelectedIndex'), [0]);
  }, variant: _ios);

  testWidgets('updates badges in place and recreates the bar for new tabs', (
    tester,
  ) async {
    List<LiquidGlassTabItem> items({String? badge, String label = 'Beta'}) => [
      _items.first,
      LiquidGlassTabItem(
        label: label,
        icon: Icons.star_border,
        sfSymbol: 'star',
        badge: badge,
      ),
    ];
    await tester.pumpWidget(host(items: items()));
    await tester.pump();
    final first = last;
    await tester.pumpWidget(host(items: items(badge: '')));
    await tester.pump();
    expect(last, first);
    expect(sent(first, 'updateBadges'), [
      [null, ''],
    ]);
    await tester.pumpWidget(
      host(
        items: items(badge: '', label: 'Starred'),
      ),
    );
    await tester.pump();
    expect(last, isNot(first));
    final tab = (views[last]!['tabs'] as List)[1] as Map;
    expect([tab['label'], tab['badge']], ['Starred', '']);
  }, variant: _ios);

  testWidgets('the trailing action reports one press, never while covered', (
    tester,
  ) async {
    var finds = 0;
    await tester.pumpWidget(
      host(
        action: LiquidGlassAction(
          id: 'find',
          label: 'Find',
          onPressed: () => finds++,
        ),
      ),
    );
    await tester.pump();
    final id = last;
    await send('actionPressed');
    expect(finds, 1);
    Navigator.of(tester.element(find.byType(Scaffold))).push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();
    expect(sent(id, 'setSuppressed').last, {
      'suppressed': true,
      'popupOwner': false,
    });
    await send('actionPressed');
    expect(finds, 1);
    Navigator.of(tester.element(find.byType(Scaffold))).pop();
    await tester.pumpAndSettle();
    expect(sent(id, 'setSuppressed').last, {
      'suppressed': false,
      'popupOwner': false,
    });
    expect(last, id);
  }, variant: _ios);

  testWidgets('a tab without a symbol sends its glyphs as bitmaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        items: const [
          LiquidGlassTabItem(
            label: 'Alpha',
            icon: Icons.home,
            sfSymbol: 'house',
          ),
          LiquidGlassTabItem(
            label: 'Gamma',
            icon: Icons.settings,
            selectedIcon: Icons.settings_suggest,
          ),
        ],
      ),
    );
    for (var i = 0; i < 50 && find.byType(UiKitView).evaluate().isEmpty; ++i) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    final tab = (views[last]!['tabs'] as List)[1] as Map;
    expect(tab['symbol'], isNull);
    // Both states are a square of the bar's 30-point icon size at the test
    // view's pixel ratio of 3, which UIKit decodes at that scale. The test
    // fonts draw every glyph alike, so their pixels are not compared.
    expect(tab['scale'], 3.0);
    for (final png in [tab['png'], tab['selectedPng']]) {
      expect(ByteData.sublistView(png as Uint8List).getUint32(16), 90);
      expect(ByteData.sublistView(png).getUint32(20), 90);
    }
    // A symbol tab needs neither.
    final symbolTab = (views[last]!['tabs'] as List)[0] as Map;
    expect(symbolTab.containsKey('scale'), isFalse);
  }, variant: _ios);
}
