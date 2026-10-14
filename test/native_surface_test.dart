import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
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

class _Popup extends PopupRoute<void> {
  _Popup(this.child);
  final Widget child;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => Colors.black26;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 1);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Center(child: child);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final created = <({String type, Map<Object?, Object?> params})>[];
  final calls = <int, List<MethodCall>>{};

  setUp(() {
    created.clear();
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final id = arguments['id'] as int;
          created.add((
            type: arguments['viewType'] as String,
            params:
                const StandardMessageCodec().decodeMessage(
                      ByteData.sublistView(arguments['params'] as Uint8List),
                    )
                    as Map<Object?, Object?>,
          ));
          calls[id] = [];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel('flutter_adaptive_liquid_glass/surface/$id'),
            (call) async {
              calls[id]!.add(call);
              return null;
            },
          );
        }
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
        MethodChannel('flutter_adaptive_liquid_glass/surface/$id'),
        null,
      );
    }
  });

  Widget host({
    double radius = 28,
    Color? tint,
    ThemeMode mode = ThemeMode.light,
    Widget child = const SizedBox(width: 200, height: 100),
    Key? key,
  }) => MaterialApp(
    themeMode: mode,
    darkTheme: ThemeData.dark(),
    home: LiquidGlassTheme(
      data: const _NativeTheme(),
      child: Scaffold(
        body: Center(
          child: LiquidGlassSurface(
            key: key,
            radius: radius,
            tint: tint,
            child: child,
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'the native material is one package-owned view, not the provider container',
    (tester) async {
      await tester.pumpWidget(host());
      expect(created.map((view) => view.type), [
        'flutter_adaptive_liquid_glass/surface',
      ]);
      final params = created.single.params;
      expect(params['radius'], 28);
      expect(params['dark'], isFalse);
      expect(params['tint'], isNull);
      // A translucent fill sits behind the glass so text stays readable.
      expect(((params['backgroundColor'] as int) >> 24) & 255, 89);
      expect(params['popupOwner'], isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'changes reach the existing view over its channel without recreating it',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpWidget(
        host(radius: 12, tint: const Color(0xff336699), mode: ThemeMode.dark),
      );
      // The app theme animates; the native view follows its final brightness.
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      // The theme animation sends intermediate states; the last one wins.
      final configure = calls.values.single.last;
      expect(configure.method, 'configure');
      final arguments = configure.arguments as Map;
      expect(arguments['radius'], 12);
      expect(arguments['dark'], isTrue);
      expect(arguments['tint'], 0xff336699);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'an unchanged rebuild sends nothing',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpWidget(host(child: const Text('same surface')));
      expect(created, hasLength(1));
      expect(calls.values.single, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a surface in a popup is marked as the popup owner',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = LiquidGlassNavigatorObserver.debug(
        nativeAvailable: false,
      );
      addTearDown(observer.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: LiquidGlassTheme(
            data: const _NativeTheme(),
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      navigator.currentState!.push(
        _Popup(
          LiquidGlassTheme(
            data: const _NativeTheme(),
            child: const LiquidGlassSurface(
              child: SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created.single.params['popupOwner'], isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('the fallback material creates no platform view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const LiquidGlassTheme(
          data: LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: Scaffold(
            body: Center(
              child: LiquidGlassSurface(
                child: SizedBox(width: 200, height: 80),
              ),
            ),
          ),
        ),
      ),
    );
    expect(created, isEmpty);
  });
}
