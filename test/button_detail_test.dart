import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
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

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final created = <Map<Object?, Object?>>[];

  setUp(() {
    created.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          if (arguments['viewType'] ==
              'flutter_adaptive_liquid_glass/capsule') {
            created.add(
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(arguments['params'] as Uint8List),
                  )
                  as Map<Object?, Object?>,
            );
            final id = arguments['id'] as int;
            binding.defaultBinaryMessenger.setMockMethodCallHandler(
              MethodChannel('flutter_adaptive_liquid_glass/capsule/$id'),
              (call) async =>
                  call.method == 'intrinsicSize' ? {'width': 120.0} : null,
            );
          }
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
  });

  Widget host(Widget child, {LiquidGlassThemeData? glass}) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    home: LiquidGlassTheme(
      data: glass ?? const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  const dot = Color(0xff16a34a);

  group('fallback', () {
    testWidgets('detail, icon colour and size, and the menu indicator', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var pressed = 0;
      await tester.pumpWidget(
        host(
          LiquidGlassButton(
            label: 'Studio',
            detail: 'Online',
            icon: Icons.circle,
            iconColor: dot,
            iconSize: 8,
            menuIndicator: true,
            onPressed: () => pressed++,
          ),
        ),
      );
      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.circle));
      expect(icon.color, dot);
      expect(icon.size, 8);
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
      // The label and the detail are read as one button.
      final node = tester.getSemantics(find.byType(LiquidGlassButton));
      expect(node.label, 'Studio, Online');
      await tester.tap(find.byType(LiquidGlassButton));
      expect(pressed, 1);
      semantics.dispose();
    });

    testWidgets('a menu button passes the options to its trigger', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          LiquidGlassMenuButton<String>(
            label: 'Model',
            detail: 'High',
            icon: Icons.circle,
            iconColor: dot,
            iconSize: 8,
            menuIndicator: true,
            items: const [LiquidGlassMenuItem(value: 'a', label: 'A')],
          ),
        ),
      );
      final button = tester.widget<LiquidGlassButton>(
        find.byType(LiquidGlassButton),
      );
      expect(button.detail, 'High');
      expect(button.iconColor, dot);
      expect(button.iconSize, 8);
      expect(button.menuIndicator, isTrue);
      await tester.tap(find.byType(LiquidGlassButton));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('without the new options the button is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          LiquidGlassButton(label: 'Plain', icon: Icons.add, onPressed: () {}),
        ),
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).size, 22);
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, isNull);
      expect(find.byIcon(Icons.unfold_more), findsNothing);
    });

    testWidgets('a long detail stays inside a narrow button', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 160,
            child: LiquidGlassButton(
              label: 'A long computer name',
              detail: 'Waiting for approval',
              menuIndicator: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('native', () {
    testWidgets(
      'the capsule item carries the detail, icon styling and indicator',
      (tester) async {
        await tester.pumpWidget(
          host(
            glass: const _NativeTheme(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlassButton(
                  label: 'Studio',
                  detail: 'Online',
                  sfSymbol: 'circle.fill',
                  icon: Icons.circle,
                  iconColor: dot,
                  iconSize: 8,
                  menuIndicator: true,
                  onPressed: () {},
                ),
                LiquidGlassButton(label: 'Plain', onPressed: () {}),
              ],
            ),
          ),
        );
        await tester.pump();
        Map<Object?, Object?> item(int index) =>
            (created[index]['items'] as List).single as Map<Object?, Object?>;
        expect(item(0)['title'], 'Studio');
        expect(item(0)['detail'], 'Online');
        expect(item(0)['label'], 'Studio, Online');
        expect(item(0)['iconColor'], dot.toARGB32());
        expect(item(0)['iconSize'], 8.0);
        expect(item(0)['menuIndicator'], isTrue);
        expect(item(1)['detail'], isNull);
        expect(item(1)['iconColor'], isNull);
        expect(item(1)['menuIndicator'], isFalse);
        // The capsule reserves room for the detail and the indicator.
        expect(
          tester.getSize(find.byType(LiquidGlassButton).first).width,
          greaterThan(
            tester.getSize(find.byType(LiquidGlassButton).last).width,
          ),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });
}
