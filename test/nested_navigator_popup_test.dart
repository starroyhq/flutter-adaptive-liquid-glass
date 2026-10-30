import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_visibility.dart';
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

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final viewCalls = <String, List<MethodCall>>{};
  late List<String> lifecycle;

  setUp(() {
    lifecycle = [];
    viewCalls.clear();
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
          final name = '${arguments['viewType']}/${arguments['id']}';
          viewCalls[name] = [];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(name),
            (call) async {
              viewCalls[name]!.add(call);
              return call.method == 'intrinsicSize' ? {'width': 120.0} : null;
            },
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
    for (final name in viewCalls.keys) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        null,
      );
    }
  });

  List<bool> visibilities(WidgetTester tester) => [
    for (final view in tester.widgetList<UiKitView>(
      find.byType(UiKitView, skipOffstage: false),
    ))
      tester
          .widget<Visibility>(
            find
                .ancestor(
                  of: find.byWidget(view, skipOffstage: false),
                  matching: find.byType(Visibility, skipOffstage: false),
                )
                .first,
          )
          .visible,
  ];

  // A tab shell like a router's shell route: the tab bar on the root page,
  // the tab's page in a nested Navigator, each Navigator with its own
  // observer, and the popover on the root Navigator. go_router also reports
  // the nested Navigator's routes to the root Navigator's observers.
  Future<void> popoverKeepsBothLevels(
    WidgetTester tester, {
    required bool forwardNested,
  }) async {
    final rootObserver = LiquidGlassNavigatorObserver.debug(
      nativeAvailable: true,
    );
    final shellObserver = LiquidGlassNavigatorObserver.debug(
      nativeAvailable: true,
    );
    addTearDown(rootObserver.dispose);
    addTearDown(shellObserver.dispose);
    final anchor = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        builder: (context, child) =>
            LiquidGlassTheme(data: const _NativeTheme(), child: child!),
        home: Scaffold(
          body: Navigator(
            observers: [
              shellObserver,
              if (forwardNested) _Forward(rootObserver),
            ],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiquidGlassButton(
                        key: anchor,
                        label: 'All agents',
                        onPressed: () {},
                      ),
                      LiquidGlassSegmentedControl<int>(
                        segments: const [
                          LiquidGlassSegment(value: 0, label: 'Active'),
                          LiquidGlassSegment(value: 1, label: 'Archived'),
                        ],
                        selected: 0,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: LiquidGlassTabBar(
            items: const [
              LiquidGlassTabItem(label: 'Inbox', icon: Icons.inbox),
              LiquidGlassTabItem(label: 'Sessions', icon: Icons.forum),
            ],
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final before = visibilities(tester);
    expect(before, isNotEmpty);
    expect(before, everyElement(isTrue));

    final context = anchor.currentContext!;
    showLiquidGlassPopover<void>(
      context: context,
      anchorContext: context,
      builder: (_) => const Text('Menu'),
    );
    await tester.pump();
    for (final element
        in find.byType(UiKitView, skipOffstage: false).evaluate()) {
      expect(
        nativeRouteChain(element).any(nativeRouteHidden),
        isFalse,
        reason: '$element',
      );
    }
    expect(visibilities(tester), everyElement(isTrue));
    await tester.pumpAndSettle();
    expect(visibilities(tester), everyElement(isTrue));
    expect(lifecycle, isEmpty);
    for (final calls in viewCalls.values) {
      for (final call in calls) {
        if (call.arguments case {'suppressed': true}) {
          fail('${call.method} suppressed a native view: ${call.arguments}');
        }
      }
    }
  }

  testWidgets(
    'a package popover from a nested page keeps both levels',
    (tester) => popoverKeepsBothLevels(tester, forwardNested: false),
  );

  testWidgets(
    'a package popover keeps both levels when nested routes reach the root '
    'observer',
    (tester) => popoverKeepsBothLevels(tester, forwardNested: true),
  );
}

/// Reports a nested Navigator's route changes to another observer, as
/// go_router does for the observers of its root Navigator.
class _Forward extends NavigatorObserver {
  _Forward(this.target);
  final NavigatorObserver target;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      target.didPush(route, previousRoute);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      target.didPop(route, previousRoute);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      target.didRemove(route, previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      target.didReplace(newRoute: newRoute, oldRoute: oldRoute);
}
