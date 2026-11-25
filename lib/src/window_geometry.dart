import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A size class reported by UIKit for an axis of the current window.
enum LiquidGlassWindowSizeClass { compact, regular }

/// The edge UIKit recommends for vertical navigation in this window.
enum LiquidGlassVerticalBarEdge { leading, trailing }

/// How a region affects layout in the current Flutter view.
enum LiquidGlassReservedRegionKind {
  /// A fold or hinge that may divide the view into panes.
  division,

  /// An area reserved for system UI or a hardware obstruction.
  occlusion,
}

/// A system region in the same logical coordinates as [DisplayFeature.bounds].
@immutable
class LiquidGlassReservedRegion {
  const LiquidGlassReservedRegion({
    required this.bounds,
    required this.kind,
    required this.isActive,
    this.posture = DisplayFeatureState.unknown,
  });

  final Rect bounds;
  final LiquidGlassReservedRegionKind kind;

  /// Whether the region currently affects layout. A flat fold can be inactive.
  final bool isActive;

  /// The observed fold posture, when the system reports it.
  final DisplayFeatureState posture;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassReservedRegion &&
      bounds == other.bounds &&
      kind == other.kind &&
      isActive == other.isActive &&
      posture == other.posture;

  @override
  int get hashCode => Object.hash(bounds, kind, isActive, posture);
}

/// Geometry for arranging navigation and content in the current Flutter view.
@immutable
class LiquidGlassWindowGeometry {
  const LiquidGlassWindowGeometry._({
    required this.size,
    required this.safeArea,
    required this.horizontalSizeClass,
    required this.verticalSizeClass,
    required this.verticalBarEdge,
    required this.displayFeatures,
    required this.reservedRegions,
    required this.windowControlMargins,
  });

  /// The window size in logical pixels.
  final Size size;

  /// The persistent safe-area insets from [MediaQueryData.viewPadding].
  final EdgeInsets safeArea;

  /// UIKit's size class for the horizontal axis, when available.
  final LiquidGlassWindowSizeClass? horizontalSizeClass;

  /// UIKit's size class for the vertical axis, when available.
  final LiquidGlassWindowSizeClass? verticalSizeClass;

  /// UIKit's recommended vertical navigation edge, when available.
  final LiquidGlassVerticalBarEdge? verticalBarEdge;

  /// Flutter display features supplemented by active UIKit divisions.
  final List<DisplayFeature> displayFeatures;

  /// System obstructions and divisions, including inactive UIKit regions.
  final List<LiquidGlassReservedRegion> reservedRegions;

  /// UIKit's window-control-aware content margins, when available on iPad.
  ///
  /// These are measured from the view's edges and can include standard
  /// margins. Use them as content margins for controls near window corners.
  final EdgeInsets? windowControlMargins;

  /// Reads and subscribes to changes in the nearest geometry scope.
  ///
  /// Outside a scope this uses the current [MediaQuery].
  static LiquidGlassWindowGeometry of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_WindowGeometryData>()
          ?.geometry ??
      _resolve(MediaQuery.of(context));

  static LiquidGlassWindowGeometry _resolve(
    MediaQueryData media, [
    _NativeWindowGeometry? snapshot,
  ]) {
    // View size and UIKit events travel through different channels. Apply a
    // snapshot only to the Flutter view size it was measured for.
    final native = snapshot?.matches(media.size) == true ? snapshot : null;
    final features = [...media.displayFeatures];
    final regions = media.displayFeatures.map(_flutterRegion).nonNulls.toList();
    for (final region
        in native?.regions ?? const <LiquidGlassReservedRegion>[]) {
      if (!regions.any(
        (existing) =>
            existing.bounds == region.bounds && existing.kind == region.kind,
      )) {
        regions.add(region);
      }
      if (region.kind == LiquidGlassReservedRegionKind.division &&
          region.isActive &&
          !features.any(
            (feature) =>
                feature.bounds == region.bounds &&
                (feature.type == DisplayFeatureType.fold ||
                    feature.type == DisplayFeatureType.hinge),
          )) {
        features.add(
          DisplayFeature(
            bounds: region.bounds,
            type: DisplayFeatureType.fold,
            state: region.posture,
          ),
        );
      }
    }
    return LiquidGlassWindowGeometry._(
      size: media.size,
      safeArea: media.viewPadding,
      horizontalSizeClass: native?.horizontalSizeClass,
      verticalSizeClass: native?.verticalSizeClass,
      verticalBarEdge: native?.verticalBarEdge,
      displayFeatures: List.unmodifiable(features),
      reservedRegions: List.unmodifiable(regions),
      windowControlMargins: native?.windowControlMargins,
    );
  }

  static LiquidGlassReservedRegion? _flutterRegion(DisplayFeature feature) {
    final kind = switch (feature.type) {
      DisplayFeatureType.fold ||
      DisplayFeatureType.hinge => LiquidGlassReservedRegionKind.division,
      DisplayFeatureType.cutout => LiquidGlassReservedRegionKind.occlusion,
      _ => null,
    };
    if (kind == null) return null;
    return LiquidGlassReservedRegion(
      bounds: feature.bounds,
      kind: kind,
      isActive:
          feature.type != DisplayFeatureType.fold ||
          feature.state != DisplayFeatureState.postureFlat,
      posture: feature.state,
    );
  }

  bool _matches(LiquidGlassWindowGeometry other) =>
      size == other.size &&
      safeArea == other.safeArea &&
      horizontalSizeClass == other.horizontalSizeClass &&
      verticalSizeClass == other.verticalSizeClass &&
      verticalBarEdge == other.verticalBarEdge &&
      windowControlMargins == other.windowControlMargins &&
      listEquals(displayFeatures, other.displayFeatures) &&
      listEquals(reservedRegions, other.reservedRegions);
}

/// Exposes window geometry to descendants and adds active UIKit divisions
/// to their [MediaQuery.displayFeaturesOf].
///
/// Place this in `MaterialApp.builder` or [WidgetsApp.builder] so the
/// Navigator, dialogs, and the rest of the app share the same view geometry.
class LiquidGlassWindowGeometryScope extends StatefulWidget {
  const LiquidGlassWindowGeometryScope({super.key, required this.child});

  final Widget child;

  @override
  State<LiquidGlassWindowGeometryScope> createState() =>
      _WindowGeometryScopeState();
}

final _nativeGeometryEvents = const EventChannel(
  'flutter_adaptive_liquid_glass/window-geometry',
).receiveBroadcastStream();

class _WindowGeometryScopeState extends State<LiquidGlassWindowGeometryScope> {
  StreamSubscription<Object?>? _subscription;
  _NativeWindowGeometry? _native;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _subscription = _nativeGeometryEvents.listen(
        (event) {
          final snapshot = _NativeWindowGeometry.fromMessage(event);
          if (mounted) setState(() => _native = snapshot);
        },
        onError: (Object _) {
          if (mounted && _native != null) setState(() => _native = null);
        },
      );
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final geometry = LiquidGlassWindowGeometry._resolve(media, _native);
    return _WindowGeometryData(
      geometry: geometry,
      // Keep the Navigator and other descendants mounted as folds appear and disappear.
      child: MediaQuery(
        data: media.copyWith(displayFeatures: geometry.displayFeatures),
        child: widget.child,
      ),
    );
  }
}

class _WindowGeometryData extends InheritedWidget {
  const _WindowGeometryData({required this.geometry, required super.child});

  final LiquidGlassWindowGeometry geometry;

  @override
  bool updateShouldNotify(_WindowGeometryData oldWidget) =>
      !geometry._matches(oldWidget.geometry);
}

class _NativeWindowGeometry {
  const _NativeWindowGeometry({
    required this.size,
    required this.horizontalSizeClass,
    required this.verticalSizeClass,
    required this.verticalBarEdge,
    required this.regions,
    required this.windowControlMargins,
  });

  final Size size;
  final LiquidGlassWindowSizeClass? horizontalSizeClass;
  final LiquidGlassWindowSizeClass? verticalSizeClass;
  final LiquidGlassVerticalBarEdge? verticalBarEdge;
  final List<LiquidGlassReservedRegion> regions;
  final EdgeInsets? windowControlMargins;

  bool matches(Size other) =>
      (size.width - other.width).abs() <= 1 &&
      (size.height - other.height).abs() <= 1;

  static _NativeWindowGeometry? fromMessage(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    final width = _finite(value['width']);
    final height = _finite(value['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    final regions = value['reservedRegions'];
    return _NativeWindowGeometry(
      size: Size(width, height),
      horizontalSizeClass: _sizeClass(value['horizontalSizeClass']),
      verticalSizeClass: _sizeClass(value['verticalSizeClass']),
      verticalBarEdge: switch (value['verticalBarEdge']) {
        'leading' => LiquidGlassVerticalBarEdge.leading,
        'trailing' => LiquidGlassVerticalBarEdge.trailing,
        _ => null,
      },
      regions: regions is List<Object?>
          ? regions.map(_reservedRegion).nonNulls.toList()
          : const [],
      windowControlMargins: _insets(value['windowControlMargins']),
    );
  }

  static LiquidGlassWindowSizeClass? _sizeClass(Object? value) =>
      switch (value) {
        'compact' => LiquidGlassWindowSizeClass.compact,
        'regular' => LiquidGlassWindowSizeClass.regular,
        _ => null,
      };

  static LiquidGlassReservedRegion? _reservedRegion(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    final kind = switch (value['kind']) {
      'division' => LiquidGlassReservedRegionKind.division,
      'occlusion' => LiquidGlassReservedRegionKind.occlusion,
      _ => null,
    };
    final active = value['active'];
    final x = _finite(value['x']);
    final y = _finite(value['y']);
    final width = _finite(value['width']);
    final height = _finite(value['height']);
    if (kind == null ||
        active is! bool ||
        x == null ||
        y == null ||
        width == null ||
        height == null ||
        width < 0 ||
        height < 0 ||
        (width == 0 && height == 0)) {
      return null;
    }
    return LiquidGlassReservedRegion(
      bounds: Rect.fromLTWH(x, y, width, height),
      kind: kind,
      isActive: active,
      posture: switch (value['posture']) {
        'flat' => DisplayFeatureState.postureFlat,
        'halfOpened' => DisplayFeatureState.postureHalfOpened,
        _ => DisplayFeatureState.unknown,
      },
    );
  }

  static EdgeInsets? _insets(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    final left = _finite(value['left']);
    final top = _finite(value['top']);
    final right = _finite(value['right']);
    final bottom = _finite(value['bottom']);
    if (left == null ||
        top == null ||
        right == null ||
        bottom == null ||
        left < 0 ||
        top < 0 ||
        right < 0 ||
        bottom < 0) {
      return null;
    }
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  static double? _finite(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;
}
