import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/fallback_selection_track.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_segmented_control.dart';
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
            arguments['viewType'] != NativeSegmentedControl.viewType) {
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
          MethodChannel('${NativeSegmentedControl.viewType}/$id'),
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
        MethodChannel('${NativeSegmentedControl.viewType}/$id'),
        null,
      );
    }
  });

  Future<void> send(String method, Object? arguments) =>
      binding.defaultBinaryMessenger.handlePlatformMessage(
        '${NativeSegmentedControl.viewType}/$last',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  List<Object?> sent(int id, String method) => [
    for (final call in calls[id]!)
      if (call.method == method) call.arguments,
  ];

  Widget control({
    int selected = 0,
    ValueChanged<int>? onChanged,
    List<String> labels = const ['One', 'Two', 'Three'],
  }) => LiquidGlassTheme(
    data: const _NativeTheme(),
    child: SizedBox(
      width: 300,
      child: LiquidGlassSegmentedControl<int>(
        segments: [
          for (var i = 0; i < labels.length; ++i)
            LiquidGlassSegment(value: i, label: labels[i]),
        ],
        selected: selected,
        onChanged: onChanged,
      ),
    ),
  );

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('creates the system control as wide as its space', (
    tester,
  ) async {
    await tester.pumpWidget(host(control(selected: 1, onChanged: (_) {})));
    final params = views[last]!;
    expect(params['labels'], ['One', 'Two', 'Three']);
    expect(params['selectedIndex'], 1);
    expect(params['enabled'], isTrue);
    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(params['color'], theme.colorScheme.primary.toARGB32());
    expect(params['suppressed'], isFalse);
    expect(params['popupOwner'], isFalse);
    expect(tester.getSize(find.byType(UiKitView)), const Size(300, 48));
  }, variant: _ios);

  testWidgets('reports typed values and ignores an index out of range', (
    tester,
  ) async {
    final values = <int>[];
    await tester.pumpWidget(host(control(onChanged: values.add)));
    await send('valueChanged', 2);
    await send('valueChanged', 5);
    expect(values, [2]);
  }, variant: _ios);

  testWidgets('updates labels, selection and enabled state in place', (
    tester,
  ) async {
    await tester.pumpWidget(host(control(onChanged: (_) {})));
    final id = last;
    calls[id]!.clear();
    await tester.pumpWidget(
      host(
        control(
          selected: 2,
          onChanged: (_) {},
          labels: const ['Uno', 'Dos', 'Tres'],
        ),
      ),
    );
    expect(last, id);
    expect(
      [for (final call in calls[id]!) call.method],
      ['updateSegments', 'setSelectedIndex'],
    );
    expect(calls[id]![0].arguments, {
      'labels': ['Uno', 'Dos', 'Tres'],
    });
    expect(calls[id]![1].arguments, {'index': 2, 'animated': true});
    await tester.pumpWidget(
      host(control(selected: 2, labels: const ['Uno', 'Dos', 'Tres'])),
    );
    expect(calls[id]!.last.method, 'setEnabled');
    expect(calls[id]!.last.arguments, {'enabled': false});
    expect(last, id);
  }, variant: _ios);

  testWidgets('reverts a choice the parent does not adopt', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(host(control(onChanged: values.add)));
    final id = last;
    calls[id]!.clear();
    await send('valueChanged', 2);
    expect(values, [2]);
    expect(sent(id, 'setSelectedIndex'), isEmpty);
    await tester.pump();
    expect(sent(id, 'setSelectedIndex'), [
      {'index': 0, 'animated': true},
    ]);
    await tester.pump();
    expect(sent(id, 'setSelectedIndex'), hasLength(1));
    expect(last, id);
  }, variant: _ios);

  testWidgets('does not send back an adopted choice', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          control(
            selected: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    final id = last;
    calls[id]!.clear();
    await send('valueChanged', 2);
    await tester.pump();
    await tester.pump();
    expect(selected, 2);
    expect(sent(id, 'setSelectedIndex'), isEmpty);
    expect(last, id);
  }, variant: _ios);

  testWidgets('reverts a late choice on a disabled control', (tester) async {
    await tester.pumpWidget(host(control()));
    final id = last;
    calls[id]!.clear();
    await send('valueChanged', 1);
    await tester.pump();
    expect(sent(id, 'setSelectedIndex'), [
      {'index': 0, 'animated': true},
    ]);
  }, variant: _ios);

  testWidgets('a parent that rebuilds without adopting reverts once', (
    tester,
  ) async {
    var refusals = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) =>
            host(control(onChanged: (_) => setState(() => refusals++))),
      ),
    );
    final id = last;
    calls[id]!.clear();
    await send('valueChanged', 1);
    await tester.pump();
    await tester.pump();
    expect(refusals, 1);
    expect(sent(id, 'setSelectedIndex'), [
      {'index': 0, 'animated': true},
    ]);
  }, variant: _ios);

  testWidgets('the fallback keeps its selection when a choice is not adopted', (
    tester,
  ) async {
    final values = <int>[];
    await tester.pumpWidget(
      host(
        LiquidGlassTheme(
          data: const LiquidGlassThemeData(mode: LiquidGlassMode.fallback),
          child: SizedBox(
            width: 300,
            child: LiquidGlassSegmentedControl<int>(
              segments: const [
                LiquidGlassSegment(value: 0, label: 'One'),
                LiquidGlassSegment(value: 1, label: 'Two'),
                LiquidGlassSegment(value: 2, label: 'Three'),
              ],
              selected: 0,
              onChanged: values.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Three'));
    await tester.pumpAndSettle();
    expect(values, [2]);
    expect(find.byType(UiKitView), findsNothing);
    expect(
      tester
          .widget<FallbackSelectionTrack>(find.byType(FallbackSelectionTrack))
          .selectedIndex,
      0,
    );
  });

  testWidgets('a control in a popup belongs to that popup', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(child: control(onChanged: (_) {})),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(views[last]!['popupOwner'], isTrue);
    expect(views[last]!['suppressed'], isFalse);
  }, variant: _ios);
}
