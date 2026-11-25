import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

const _channelName = 'flutter_adaptive_liquid_glass/window-geometry';
const _channel = MethodChannel(_channelName);
const _codec = StandardMethodCodec();

const _size = Size(951, 669);
const _foldBounds = Rect.fromLTWH(470, 0, 10, 669);
const _coverBounds = Rect.fromLTWH(870, 0, 81, 40);
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  testWidgets('reads Flutter fold and cutout data with no UIKit traits', (
    tester,
  ) async {
    const features = [
      DisplayFeature(
        bounds: Rect.fromLTWH(450, 0, 0, 669),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
      DisplayFeature(
        bounds: _coverBounds,
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ];
    const safeArea = EdgeInsets.only(top: 24, right: 20);
    late LiquidGlassWindowGeometry geometry;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: _size,
          devicePixelRatio: 3,
          viewPadding: safeArea,
          displayFeatures: features,
        ),
        child: Builder(
          builder: (context) {
            geometry = LiquidGlassWindowGeometry.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(geometry.size, _size);
    expect(geometry.safeArea, safeArea);
    expect(geometry.displayFeatures, features);
    expect(geometry.horizontalSizeClass, isNull);
    expect(geometry.verticalSizeClass, isNull);
    expect(geometry.verticalBarEdge, isNull);
    expect(geometry.windowControlMargins, isNull);
    expect(geometry.reservedRegions, [
      LiquidGlassReservedRegion(
        bounds: features.first.bounds,
        kind: LiquidGlassReservedRegionKind.division,
        isActive: true,
        posture: DisplayFeatureState.postureHalfOpened,
      ),
      const LiquidGlassReservedRegion(
        bounds: _coverBounds,
        kind: LiquidGlassReservedRegionKind.occlusion,
        isActive: true,
      ),
    ]);
  });

  testWidgets(
    'supplies native traits, margins, and active folds to MediaQuery',
    (tester) async {
      final calls = _mockIos(tester);
      late LiquidGlassWindowGeometry geometry;
      late List<DisplayFeature> contextFeatures;
      await tester.pumpWidget(
        _scope(_size, (context) {
          geometry = LiquidGlassWindowGeometry.of(context);
          contextFeatures = MediaQuery.displayFeaturesOf(context);
        }),
      );
      expect(geometry.verticalBarEdge, isNull);
      expect(calls, ['listen']);
      final descendant = tester.element(find.byType(Builder));
      await _emit(tester, {
        ..._snapshot(_size),
        'horizontalSizeClass': 'regular',
        'verticalSizeClass': 'compact',
        'verticalBarEdge': 'trailing',
        'windowControlMargins': {
          'left': 52,
          'top': 42,
          'right': 16,
          'bottom': 20,
        },
        'reservedRegions': [
          _region(_foldBounds, 'division', active: true, posture: 'halfOpened'),
          _region(_coverBounds, 'occlusion', active: true),
        ],
      });
      expect(geometry.horizontalSizeClass, LiquidGlassWindowSizeClass.regular);
      expect(geometry.verticalSizeClass, LiquidGlassWindowSizeClass.compact);
      expect(geometry.verticalBarEdge, LiquidGlassVerticalBarEdge.trailing);
      expect(
        geometry.windowControlMargins,
        const EdgeInsets.fromLTRB(52, 42, 16, 20),
      );
      expect(geometry.reservedRegions.map((region) => region.bounds), [
        _foldBounds,
        _coverBounds,
      ]);
      expect(contextFeatures, [
        const DisplayFeature(
          bounds: _foldBounds,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]);
      expect(geometry.displayFeatures, contextFeatures);
      expect(tester.element(find.byType(Builder)), same(descendant));

      await _emit(tester, {
        ..._snapshot(_size),
        'reservedRegions': [
          _region(_foldBounds, 'division', active: false, posture: 'flat'),
          {'kind': 'division', 'active': true, 'width': -1},
        ],
      });
      expect(contextFeatures, isEmpty);
      expect(tester.element(find.byType(Builder)), same(descendant));
      expect(geometry.reservedRegions, [
        const LiquidGlassReservedRegion(
          bounds: _foldBounds,
          kind: LiquidGlassReservedRegionKind.division,
          isActive: false,
          posture: DisplayFeatureState.postureFlat,
        ),
      ]);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, ['listen', 'cancel']);
    },
    variant: _ios,
  );

  testWidgets('ignores snapshots measured before a window resize', (
    tester,
  ) async {
    _mockIos(tester);
    const compact = Size(466, 678);
    late LiquidGlassWindowGeometry geometry;
    void capture(BuildContext context) {
      geometry = LiquidGlassWindowGeometry.of(context);
    }

    await tester.pumpWidget(_scope(_size, capture));
    await _emit(tester, {
      ..._snapshot(_size),
      'verticalBarEdge': 'trailing',
      'reservedRegions': [_region(_foldBounds, 'division', active: true)],
    });
    expect(geometry.displayFeatures, hasLength(1));

    await tester.pumpWidget(_scope(compact, capture));
    expect(geometry.size, compact);
    expect(geometry.displayFeatures, isEmpty);
    expect(geometry.verticalBarEdge, isNull);
    await _emit(tester, {
      ..._snapshot(compact),
      'horizontalSizeClass': 'compact',
      'verticalBarEdge': 'leading',
    });
    expect(geometry.displayFeatures, isEmpty);
    expect(geometry.horizontalSizeClass, LiquidGlassWindowSizeClass.compact);
    expect(geometry.verticalBarEdge, LiquidGlassVerticalBarEdge.leading);
  }, variant: _ios);

  testWidgets(
    'keeps a Flutter hinge when native geometry describes the same edge',
    (tester) async {
      _mockIos(tester);
      const hinge = DisplayFeature(
        bounds: _foldBounds,
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureHalfOpened,
      );
      late LiquidGlassWindowGeometry geometry;
      await tester.pumpWidget(
        _scope(
          _size,
          (context) => geometry = LiquidGlassWindowGeometry.of(context),
          features: [hinge],
        ),
      );
      await _emit(tester, {
        ..._snapshot(_size),
        'reservedRegions': [_region(_foldBounds, 'division', active: true)],
      });
      expect(geometry.displayFeatures, [hinge]);
      expect(geometry.reservedRegions, hasLength(1));
    },
    variant: _ios,
  );
}

List<String> _mockIos(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
  });
  return calls;
}

Widget _scope(
  Size size,
  void Function(BuildContext) capture, {
  List<DisplayFeature> features = const [],
}) => MediaQuery(
  data: MediaQueryData(size: size, displayFeatures: features),
  child: LiquidGlassWindowGeometryScope(
    child: Builder(
      builder: (context) {
        capture(context);
        return const SizedBox();
      },
    ),
  ),
);

Future<void> _emit(WidgetTester tester, Map<String, Object?> message) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channelName,
    _codec.encodeSuccessEnvelope(message),
    (_) {},
  );
  await tester.pump();
}

Map<String, Object?> _snapshot(Size size) => {
  'width': size.width,
  'height': size.height,
};

Map<String, Object?> _region(
  Rect bounds,
  String kind, {
  required bool active,
  String? posture,
}) => {
  'kind': kind,
  'x': bounds.left,
  'y': bounds.top,
  'width': bounds.width,
  'height': bounds.height,
  'active': active,
  'posture': ?posture,
};
