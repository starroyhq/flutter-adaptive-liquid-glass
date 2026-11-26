import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controls.dart';
import 'feedback.dart';
import 'native_capsule.dart';
import 'native_icon_raster.dart';
import 'native_visibility.dart';
import 'presentation.dart';
import 'theme.dart';

/// Gestures supported by the default [LiquidGlassMenuButton] trigger.
enum LiquidGlassMenuTrigger { tap, longPress, tapAndLongPress }

/// A leaf action or a branch in a [LiquidGlassMenuButton].
///
/// Values must be unique throughout one menu tree and remain stable across
/// rebuilds. Branch values identify the page; only leaf values are selected.
@immutable
class LiquidGlassMenuItem<T extends Object> {
  const LiquidGlassMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.sfSymbol,
    this.iconPng,
    this.enabled = true,
    this.destructive = false,
    this.selected = false,
    this.children = const [],
  });

  final T value;
  final String label;
  final IconData? icon;

  /// A preferred SF Symbol on iOS. Supply [icon] or [iconPng] for Flutter.
  final String? sfSymbol;

  /// PNG bytes for a menu icon. [icon] can be used as a fallback.
  final Uint8List? iconPng;
  final bool enabled;
  final bool destructive;
  final bool selected;
  final List<LiquidGlassMenuItem<T>> children;
}

/// A glass button with an anchored hierarchical menu.
///
/// On iOS 26 and later the default trigger shows a system menu. Flutter
/// popovers handle custom [builder]s, explicit single-gesture [trigger]s,
/// and fallback or opaque mode.
class LiquidGlassMenuButton<T extends Object> extends StatefulWidget {
  LiquidGlassMenuButton({
    super.key,
    required this.items,
    this.onSelected,
    this.onCanceled,
    this.label,
    this.id,
    this.icon = Icons.more_horiz,
    this.sfSymbol = 'ellipsis',
    this.semanticLabel,
    this.enabled = true,
    this.trigger = LiquidGlassMenuTrigger.tapAndLongPress,
    this.longPressSemanticLabel,
    this.useRootNavigator = true,
    this.width = 300,
    this.fitContent = false,
    this.builder,
    this.detail,
    this.iconColor,
    this.iconSize,
    this.menuIndicator = false,
  }) : assert(label != null || semanticLabel != null || builder != null),
       assert(detail == null || label != null, 'A detail follows a label.'),
       assert(width > 0 && width.isFinite);

  final List<LiquidGlassMenuItem<T>> items;
  final ValueChanged<T>? onSelected;
  final VoidCallback? onCanceled;
  final String? label;

  /// Native accessibility identifier for the default button.
  final String? id;
  final IconData? icon;
  final String? sfSymbol;
  final String? semanticLabel;
  final bool enabled;
  final LiquidGlassMenuTrigger trigger;
  final String? longPressSemanticLabel;

  /// Chooses the Navigator for the Flutter popover.
  final bool useRootNavigator;

  /// The Flutter popover's width. UIKit sizes the system menu automatically.
  final double width;

  /// Sizes the Flutter popover to its widest row, between 160 and [width].
  final bool fitContent;

  /// Builds a custom trigger. A null callback means the trigger is disabled.
  ///
  /// Custom builders keep ownership of their gestures and feedback. [trigger]
  /// controls only the default button; this callback may be used for either
  /// gesture without changing the existing builder signature.
  final Widget Function(BuildContext context, VoidCallback? open)? builder;

  /// Passed to the default trigger; see [LiquidGlassButton.detail],
  /// [LiquidGlassButton.iconColor], [LiquidGlassButton.iconSize] and
  /// [LiquidGlassButton.menuIndicator].
  final String? detail;
  final Color? iconColor;
  final double? iconSize;
  final bool menuIndicator;

  @override
  State<LiquidGlassMenuButton<T>> createState() =>
      _LiquidGlassMenuButtonState<T>();
}

class _LiquidGlassMenuButtonState<T extends Object>
    extends State<LiquidGlassMenuButton<T>> {
  bool _opening = false;

  String? get _accessibleLabel =>
      widget.semanticLabel ??
      (widget.detail == null
          ? widget.label
          : '${widget.label}, ${widget.detail}');

  Future<void> _open(BuildContext anchorContext) async {
    if (!mounted ||
        _opening ||
        !widget.enabled ||
        widget.items.isEmpty ||
        !LiquidGlassFeedback.canInteract(context)) {
      return;
    }
    final items = _snapshot(widget.items, <T>{});
    setState(() => _opening = true);
    try {
      final result = await showLiquidGlassPopover<T>(
        context: context,
        anchorContext: anchorContext,
        useRootNavigator: widget.useRootNavigator,
        width: widget.width,
        fitContent: widget.fitContent,
        semanticLabel: widget.semanticLabel ?? widget.label,
        builder: (context) =>
            _Menu<T>(items: items, fitContent: widget.fitContent),
      );
      if (!mounted) return;
      if (result == null) {
        widget.onCanceled?.call();
      } else {
        widget.onSelected?.call(result);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchorContext) {
      final canOpen = widget.enabled && !_opening && widget.items.isNotEmpty;
      final VoidCallback? open = canOpen ? () => _open(anchorContext) : null;
      if (widget.builder != null) return widget.builder!(anchorContext, open);
      if (widget.trigger == LiquidGlassMenuTrigger.tapAndLongPress &&
          LiquidGlassTheme.modeOf(anchorContext) == LiquidGlassMode.native) {
        return NativeCoverFallback(
          fallback: (_) => _flutterTrigger(anchorContext),
          child: _NativeMenuTrigger<T>(
            menu: widget,
            trigger: NativeCapsuleItem(
              id: widget.id ?? 'button',
              label: _accessibleLabel!,
              title: widget.label,
              detail: widget.detail,
              icon: widget.icon,
              iconColor: widget.iconColor,
              iconSize: widget.iconSize,
              sfSymbol: widget.sfSymbol,
              menuIndicator: widget.menuIndicator,
            ),
          ),
        );
      }
      return _flutterTrigger(anchorContext);
    },
  );

  Widget _flutterTrigger(BuildContext anchorContext) {
    // Preserve the trigger's keyboard focus across a Flutter popover.
    final VoidCallback? open = widget.enabled && widget.items.isNotEmpty
        ? () => _open(anchorContext)
        : null;
    return LiquidGlassButton(
      id: widget.id,
      label: widget.label,
      detail: widget.detail,
      icon: widget.icon,
      iconColor: widget.iconColor,
      iconSize: widget.iconSize,
      menuIndicator: widget.menuIndicator,
      sfSymbol: widget.sfSymbol,
      semanticLabel: widget.semanticLabel ?? widget.label,
      onPressed: widget.trigger == LiquidGlassMenuTrigger.longPress
          ? null
          : open,
      onLongPress: widget.trigger == LiquidGlassMenuTrigger.tap ? null : open,
      longPressSemanticLabel:
          widget.longPressSemanticLabel ?? widget.semanticLabel ?? widget.label,
    );
  }
}

List<LiquidGlassMenuItem<T>> _snapshot<T extends Object>(
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
      icon: item.icon,
      sfSymbol: item.sfSymbol,
      iconPng: item.iconPng == null ? null : Uint8List.fromList(item.iconPng!),
      enabled: item.enabled,
      destructive: item.destructive,
      selected: item.selected,
      children: _snapshot(item.children, values),
    );
  }),
);

bool _sameMenu<T extends Object>(
  List<LiquidGlassMenuItem<T>> a,
  List<LiquidGlassMenuItem<T>> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.value != y.value ||
        x.label != y.label ||
        x.icon != y.icon ||
        x.sfSymbol != y.sfSymbol ||
        !listEquals(x.iconPng, y.iconPng) ||
        x.enabled != y.enabled ||
        x.destructive != y.destructive ||
        x.selected != y.selected ||
        !_sameMenu(x.children, y.children)) {
      return false;
    }
  }
  return true;
}

class _NativeMenuTrigger<T extends Object> extends StatefulWidget {
  const _NativeMenuTrigger({required this.menu, required this.trigger});

  final LiquidGlassMenuButton<T> menu;
  final NativeCapsuleItem trigger;

  @override
  State<_NativeMenuTrigger<T>> createState() => _NativeMenuTriggerState<T>();
}

class _NativeMenuTriggerState<T extends Object>
    extends State<_NativeMenuTrigger<T>> {
  int _revision = 0;
  List<LiquidGlassMenuItem<T>> _items = const [];
  List<Map<String, Object?>> _payload = const [];
  Map<int, T> _values = const {};

  @override
  void initState() {
    super.initState();
    _prepareIfChanged();
  }

  @override
  void didUpdateWidget(covariant _NativeMenuTrigger<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareIfChanged();
  }

  void _prepareIfChanged() {
    final items = widget.menu.items;
    if (_sameMenu(_items, items)) return;
    _items = _snapshot(items, <T>{});
    _values = const {};
    _payload = const [];
    unawaited(_encode(_items, ++_revision));
  }

  Future<void> _encode(List<LiquidGlassMenuItem<T>> items, int revision) async {
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
            'enabled': item.enabled,
            'selected': item.selected,
            'destructive': item.destructive,
            'symbol': item.sfSymbol,
            'png': png,
            'template': item.iconPng == null && icon != null,
            'mirror':
                item.iconPng == null && (icon?.matchTextDirection ?? false),
            'children': children,
          };
        }),
      );
    }

    final payload = await encode(items, parentEnabled: true);
    if (!mounted || revision != _revision) return;
    setState(() {
      // Publish prepared icons under a new revision. The same button may
      // already be mounted with an empty, disabled menu.
      _revision++;
      _payload = payload;
      _values = values;
    });
  }

  @override
  Widget build(BuildContext context) => NativeCapsule(
    standaloneIcon: widget.trigger.title == null,
    items: [widget.trigger],
    menu: NativeCapsuleMenu(
      revision: _revision,
      items: _payload,
      enabled: widget.menu.enabled && _payload.isNotEmpty,
      onSelected: (id) {
        final value = _values[id];
        if (value != null) widget.menu.onSelected?.call(value);
      },
      onCanceled: () => widget.menu.onCanceled?.call(),
    ),
  );
}

class _Menu<T extends Object> extends StatefulWidget {
  const _Menu({required this.items, required this.fitContent});
  final List<LiquidGlassMenuItem<T>> items;
  final bool fitContent;

  @override
  State<_Menu<T>> createState() => _MenuState<T>();
}

class _MenuState<T extends Object> extends State<_Menu<T>> {
  final _path = <LiquidGlassMenuItem<T>>[];
  bool _selected = false;

  T? get _page => _path.isEmpty ? null : _path.last.value;

  void _select(LiquidGlassMenuItem<T> item, T? page) {
    if (_selected ||
        !item.enabled ||
        _page != page ||
        !ModalRoute.of(context)!.isCurrent) {
      return;
    }
    if (item.children.isNotEmpty) {
      LiquidGlassFeedback.tap(context);
      setState(() => _path.add(item));
    } else {
      _selected = true;
      LiquidGlassFeedback.tap(context);
      Navigator.of(context).pop<T>(item.value);
    }
  }

  void _back(T? page) {
    // A pointer/keyboard action can be delivered again before the next build.
    // Only the page which created a callback may mutate its navigation path.
    if (_selected ||
        page == null ||
        _page != page ||
        !ModalRoute.of(context)!.isCurrent) {
      return;
    }
    LiquidGlassFeedback.tap(context);
    setState(() => _path.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        LiquidGlassTheme.of(context).colors.foreground ??
        theme.colorScheme.onSurface;
    final items = _path.isEmpty ? widget.items : _path.last.children;
    final page = _page;
    final key = ValueKey(_path.isEmpty ? null : _path.last.value);
    final rows = [
      if (_path.isNotEmpty) ...[
        _MenuRow(
          label: MaterialLocalizations.of(context).backButtonTooltip,
          leading: const BackButtonIcon(),
          color: foreground,
          onTap: () => _back(page),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(_path.last.label, style: theme.textTheme.labelLarge),
        ),
        const Divider(height: 1),
      ],
      for (final item in items)
        _MenuRow(
          key: ValueKey(item.value),
          label: item.label,
          leading: _menuIcon(item),
          color: item.destructive ? theme.colorScheme.error : foreground,
          selected: item.selected,
          trailing: item.children.isNotEmpty
              ? Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                )
              : item.selected
              ? const Icon(Icons.check, size: 20)
              : null,
          onTap: item.enabled ? () => _select(item, page) : null,
        ),
    ];
    // A lazy list has no intrinsic width, so sizing to content needs a column.
    if (widget.fitContent) {
      return SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      );
    }
    return ListView(
      key: key,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: rows,
    );
  }
}

Widget? _menuIcon<T extends Object>(LiquidGlassMenuItem<T> item) {
  final fallback = item.icon == null ? null : Icon(item.icon, size: 22);
  final png = item.iconPng;
  if (png == null) return fallback;
  return Image.memory(
    png,
    width: 22,
    height: 22,
    fit: BoxFit.contain,
    errorBuilder: (_, error, stack) => fallback ?? const SizedBox.shrink(),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.label,
    required this.color,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    selected: selected,
    child: InkWell(
      enableFeedback: false,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: IconTheme.merge(
            data: IconThemeData(color: color),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: color),
              child: Opacity(
                opacity: onTap == null ? .48 : 1,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: Text(label)),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
