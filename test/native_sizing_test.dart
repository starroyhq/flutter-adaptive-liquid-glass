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

/// Records the creation parameters of every platform view, whose own channel
/// answers every call.
List<Map<Object?, Object?>> _recordPlatformViews(WidgetTester tester) {
  final binding = TestDefaultBinaryMessengerBinding.instance;
  final created = <Map<Object?, Object?>>[];
  final channels = <MethodChannel>[];
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform_views,
    (call) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        final params = arguments['params'];
        created.add({
          'viewType': arguments['viewType'],
          if (params is Uint8List)
            ...const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(params),
                )
                as Map<Object?, Object?>,
        });
        final channel = MethodChannel(
          '${arguments['viewType']}/${arguments['id']}',
        );
        channels.add(channel);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'intrinsicSize' ? {'width': 48.0} : null,
        );
      }
      return null;
    },
  );
  addTearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    for (final channel in channels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });
  return created;
}

Widget _native(Widget child) => MaterialApp(
  home: LiquidGlassTheme(
    data: const _NativeTheme(),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets(
    'a covered native surface keeps an opaque material under its content',
    (tester) async {
      _recordPlatformViews(tester);
      await tester.pumpWidget(
        _native(
          const SizedBox(
            width: 200,
            height: 120,
            child: LiquidGlassSurface(child: Text('content')),
          ),
        ),
      );
      final theme = Theme.of(tester.element(find.text('content')));
      final tone = Color.lerp(
        theme.colorScheme.surface,
        theme.colorScheme.onSurface,
        .06,
      );
      Finder material() => find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == tone,
        skipOffstage: false,
      );
      expect(material(), findsNothing);
      // A route above, such as an alert, covers the surface's route.
      Navigator.of(tester.element(find.text('content'))).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();
      expect(material(), findsOneWidget);
      expect(find.text('content', skipOffstage: false), findsOneWidget);
      Navigator.of(
        tester.element(find.text('content', skipOffstage: false)),
      ).pop();
      await tester.pumpAndSettle();
      expect(material(), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'an icon-only native button is a standalone 48-point capsule',
    (tester) async {
      final created = _recordPlatformViews(tester);
      await tester.pumpWidget(
        _native(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlassButton.icon(
                semanticLabel: 'Back',
                icon: Icons.arrow_back,
                sfSymbol: 'chevron.left',
                onPressed: () {},
              ),
              LiquidGlassButton.icon(
                semanticLabel: 'Close',
                icon: Icons.close,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      // The bitmap button reserves its circle until its glyph is drawn.
      expect(created, hasLength(1));
      final params = created.single;
      expect(params['viewType'], 'flutter_adaptive_liquid_glass/capsule');
      expect(params['standaloneIcon'], isTrue);
      final item = (params['items'] as List).single as Map;
      expect(item['symbol'], 'chevron.left');
      expect(item['title'], isNull);
      expect(item['id'], 'button');
      expect(item['label'], 'Back');
      for (final button in find.byType(LiquidGlassButton).evaluate()) {
        expect(button.size, const Size(48, 48));
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'the native segmented control spans the width it is given',
    (tester) async {
      _recordPlatformViews(tester);
      await tester.pumpWidget(
        _native(
          SizedBox(
            width: 320,
            child: LiquidGlassSegmentedControl<int>(
              segments: const [
                LiquidGlassSegment(value: 0, label: 'Changes'),
                LiquidGlassSegment(value: 1, label: 'Files'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final control = find.byType(LiquidGlassSegmentedControl<int>);
      expect(tester.getSize(control).width, 320);
      // UIKit draws the control as wide as its platform view.
      expect(tester.getSize(find.byType(UiKitView)), const Size(320, 48));
      expect(
        find.descendant(of: control, matching: find.byType(OverflowBox)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
