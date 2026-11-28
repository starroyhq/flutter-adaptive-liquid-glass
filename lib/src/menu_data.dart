import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'native_icon_raster.dart';

/// A leaf action or a branch in a Liquid Glass menu.
///
/// Values must be unique throughout one menu tree and remain stable across
/// rebuilds. Branch values identify the page; only leaf values are selected.
@immutable
class LiquidGlassMenuItem<T extends Object> {
  const LiquidGlassMenuItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.sfSymbol,
    this.iconPng,
    this.enabled = true,
    this.destructive = false,
    this.selected = false,
    this.displayInline = false,
    this.children = const [],
  });

  final T value;
  final String label;

  /// Secondary text for this action or submenu.
  final String? subtitle;
  final IconData? icon;

  /// A preferred SF Symbol on iOS. Supply [icon] or [iconPng] for Flutter.
  final String? sfSymbol;

  /// PNG bytes for a menu icon. [icon] can be used as a fallback.
  final Uint8List? iconPng;
  final bool enabled;
  final bool destructive;
  final bool selected;

  /// Shows a branch's children together in the parent instead of a submenu.
  /// The group's label may be empty. The platform chooses its presentation.
  final bool displayInline;
  final List<LiquidGlassMenuItem<T>> children;
}

List<LiquidGlassMenuItem<T>> snapshotMenuItems<T extends Object>(
  List<LiquidGlassMenuItem<T>> items,
  Set<T> values,
) => List.unmodifiable(
  items.map((item) {
    if (!values.add(item.value)) {
      throw ArgumentError.value(
        item.value,
        'items',
        'Menu values must be unique throughout the tree.',
      );
    }
    return LiquidGlassMenuItem<T>(
      value: item.value,
      label: item.label,
      subtitle: item.subtitle,
      icon: item.icon,
      sfSymbol: item.sfSymbol,
      iconPng: item.iconPng == null ? null : Uint8List.fromList(item.iconPng!),
      enabled: item.enabled,
      destructive: item.destructive,
      selected: item.selected,
      displayInline: item.displayInline,
      children: snapshotMenuItems(item.children, values),
    );
  }),
);

bool sameMenuItems<T extends Object>(
  List<LiquidGlassMenuItem<T>> a,
  List<LiquidGlassMenuItem<T>> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.value != y.value ||
        x.label != y.label ||
        x.subtitle != y.subtitle ||
        x.icon != y.icon ||
        x.sfSymbol != y.sfSymbol ||
        !listEquals(x.iconPng, y.iconPng) ||
        x.enabled != y.enabled ||
        x.destructive != y.destructive ||
        x.selected != y.selected ||
        x.displayInline != y.displayInline ||
        !sameMenuItems(x.children, y.children)) {
      return false;
    }
  }
  return true;
}

/// Wire data for UIKit and the corresponding typed leaf values.
class NativeMenuPayload<T extends Object> {
  const NativeMenuPayload(this.items, this.values);

  final List<Map<String, Object?>> items;
  final Map<int, T> values;
}

Future<NativeMenuPayload<T>> prepareNativeMenu<T extends Object>(
  List<LiquidGlassMenuItem<T>> items,
) async {
  final values = <int, T>{};
  var nextId = 0;

  Future<List<Map<String, Object?>>> encode(
    List<LiquidGlassMenuItem<T>> items, {
    required bool parentEnabled,
  }) async {
    return Future.wait(
      items.map((item) async {
        final id = nextId++;
        final enabled = parentEnabled && item.enabled;
        if (enabled && item.children.isEmpty) values[id] = item.value;
        final icon = item.icon;
        final children = await encode(item.children, parentEnabled: enabled);
        final png =
            item.iconPng ??
            (icon == null
                ? null
                : await nativeIconPng(icon, canvasSize: 22, glyphSize: 18));
        return {
          'id': id,
          'label': item.label,
          'subtitle': item.subtitle,
          'enabled': item.enabled,
          'selected': item.selected,
          'destructive': item.destructive,
          'displayInline': item.displayInline,
          'symbol': item.sfSymbol,
          'png': png,
          'template': item.iconPng == null && icon != null,
          'mirror': item.iconPng == null && (icon?.matchTextDirection ?? false),
          'children': children,
        };
      }),
    );
  }

  return NativeMenuPayload(await encode(items, parentEnabled: true), values);
}
