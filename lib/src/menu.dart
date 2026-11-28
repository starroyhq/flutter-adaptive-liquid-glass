import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controls.dart';
import 'fallback_pressable.dart';
import 'feedback.dart';
import 'native_capsule.dart';
import 'menu_data.dart';
import 'native_visibility.dart';
import 'presentation.dart';
import 'theme.dart';

export 'menu_data.dart' show LiquidGlassMenuItem;

const _menuChannel = MethodChannel('flutter_adaptive_liquid_glass/menu');
int _nextNativeRequest = 0;

/// Shows a menu at the bounds of [anchorContext] and returns the chosen value.
///
/// Native mode uses a UIKit menu on iOS with the caller's
/// current text focus intact. UIKit controls the menu layout and placement.
/// Other modes use an anchored Flutter menu without moving keyboard focus.
/// A dismissal or an anchor that is no longer visible returns null.
Future<T?> showLiquidGlassMenu<T extends Object>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<LiquidGlassMenuItem<T>> items,
  bool useRootNavigator = true,
  double width = 300,
  bool fitContent = false,
  String? semanticLabel,
}) async {
  bool anchorIsActive() =>
      LiquidGlassFeedback.canInteract(context) &&
      LiquidGlassFeedback.canInteract(anchorContext);
  if (items.isEmpty || !anchorIsActive()) return null;
  if (!width.isFinite || width <= 0) {
    throw ArgumentError.value(width, 'width', 'Menu width must be positive.');
  }

  final snapshot = snapshotMenuItems(items, <T>{});
  if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native) {
    final payload = await prepareNativeMenu(snapshot);
    if (!anchorContext.mounted || !anchorIsActive()) return null;
    final box = anchorContext.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final anchor = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    if (!anchor.isFinite || anchor.isEmpty) return null;
    final requestId = ++_nextNativeRequest;
    var pending = true;
    var cancelled = false;
    void checkAnchor(Duration _) {
      if (!pending) return;
      if (!anchorIsActive() || !box.attached) {
        cancelled = true;
        unawaited(_cancelNativeMenu(requestId));
        return;
      }
      // Observe frames the app already produces without requesting new ones.
      WidgetsBinding.instance.addPostFrameCallback(checkAnchor);
    }

    WidgetsBinding.instance.addPostFrameCallback(checkAnchor);
    try {
      final selected = await _menuChannel.invokeMethod<int>('showMenu', {
        'requestId': requestId,
        'anchor': [anchor.left, anchor.top, anchor.width, anchor.height],
        'items': payload.items,
      });
      return !cancelled && anchorIsActive() && box.attached
          ? payload.values[selected]
          : null;
    } on MissingPluginException {
      // The host without the iOS menu implementation can still show the menu.
    } on PlatformException catch (error) {
      if (error.code != 'menu_unavailable') rethrow;
    } finally {
      pending = false;
    }
    if (cancelled || !anchorIsActive()) return null;
  }
  if (!context.mounted || !anchorContext.mounted) return null;

  return showLiquidGlassPopover<T>(
    context: context,
    anchorContext: anchorContext,
    useRootNavigator: useRootNavigator,
    width: width,
    fitContent: fitContent,
    requestFocus: false,
    semanticLabel: semanticLabel,
    builder: (context) => _Menu<T>(items: snapshot, fitContent: fitContent),
  );
}

Future<void> _cancelNativeMenu(int requestId) async {
  try {
    await _menuChannel.invokeMethod<void>('cancelMenu', requestId);
  } on MissingPluginException {
    // The caller has already invalidated the selection for this request.
  }
}

/// Gestures supported by the default [LiquidGlassMenuButton] trigger.
enum LiquidGlassMenuTrigger { tap, longPress, tapAndLongPress }

/// A glass button with an anchored hierarchical menu.
///
/// In native mode, the default button and a custom [triggerChild] both show a
/// system menu. Flutter popovers handle custom [builder]s, explicit single
/// gestures, and fallback or opaque mode.
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
    this.triggerChild,
    this.detail,
    this.iconColor,
    this.iconSize,
    this.menuIndicator = false,
  }) : assert(label != null || semanticLabel != null || builder != null),
       assert(builder == null || triggerChild == null),
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

  /// Custom visual content for the menu's trigger. The menu owns the gestures
  /// and accessibility of this region. Pass a [label] or [semanticLabel] and
  /// provide noninteractive content with a bounded size.
  ///
  /// In native mode, UIKit receives touches beginning here, as on the default
  /// button. In a scrollable layout, scrolling starts outside the trigger.
  /// An explicit single-gesture [trigger] uses the Flutter popover.
  final Widget? triggerChild;

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
    final items = snapshotMenuItems(widget.items, <T>{});
    setState(() => _opening = true);
    try {
      final result = await showLiquidGlassPopover<T>(
        context: context,
        anchorContext: anchorContext,
        useRootNavigator: widget.useRootNavigator,
        width: widget.width,
        fitContent: widget.fitContent,
        requestFocus: widget.triggerChild == null ? null : false,
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
        final custom = widget.triggerChild != null;
        final native = _NativeMenuTrigger<T>(
          menu: widget,
          trigger: NativeCapsuleItem(
            id: widget.id ?? 'button',
            label: _accessibleLabel!,
            title: custom ? null : widget.label,
            detail: custom ? null : widget.detail,
            icon: custom ? null : widget.icon,
            iconColor: custom ? null : widget.iconColor,
            iconSize: custom ? null : widget.iconSize,
            sfSymbol: custom ? null : widget.sfSymbol,
            menuIndicator: !custom && widget.menuIndicator,
          ),
        );
        // Custom content is already Flutter painted, including while covered.
        if (custom) return native;
        return NativeCoverFallback(
          fallback: (_) => _flutterTrigger(anchorContext),
          child: native,
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
    final child = widget.triggerChild;
    if (child != null) {
      return Semantics(
        label: _accessibleLabel,
        button: true,
        enabled: open != null,
        child: Material(
          type: MaterialType.transparency,
          child: FallbackPressable(
            onTap: widget.trigger == LiquidGlassMenuTrigger.longPress
                ? null
                : open,
            onLongPress: widget.trigger == LiquidGlassMenuTrigger.tap
                ? null
                : open,
            longPressSemanticLabel:
                widget.longPressSemanticLabel ?? _accessibleLabel,
            borderRadius: BorderRadius.circular(12),
            child: ExcludeFocus(
              child: IgnorePointer(child: ExcludeSemantics(child: child)),
            ),
          ),
        ),
      );
    }
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
    if (sameMenuItems(_items, items)) return;
    _items = snapshotMenuItems(items, <T>{});
    _values = const {};
    _payload = const [];
    unawaited(_encode(_items, ++_revision));
  }

  Future<void> _encode(List<LiquidGlassMenuItem<T>> items, int revision) async {
    final payload = await prepareNativeMenu(items);
    if (!mounted || revision != _revision) return;
    setState(() {
      // Publish prepared icons under a new revision. The same button may
      // already be mounted with an empty, disabled menu.
      _revision++;
      _payload = payload.items;
      _values = payload.values;
    });
  }

  @override
  Widget build(BuildContext context) => NativeCapsule(
    standaloneIcon:
        widget.menu.triggerChild == null && widget.trigger.title == null,
    items: [widget.trigger],
    menuTriggerChild: widget.menu.triggerChild,
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

    Iterable<Widget> itemRows(
      LiquidGlassMenuItem<T> item, {
      required bool parentEnabled,
    }) sync* {
      final enabled = parentEnabled && item.enabled;
      if (item.displayInline && item.children.isNotEmpty) {
        yield const Divider(height: 1);
        if (item.label.isNotEmpty || item.subtitle != null) {
          yield _MenuHeading(label: item.label, subtitle: item.subtitle);
        }
        for (final child in item.children) {
          yield* itemRows(child, parentEnabled: enabled);
        }
        return;
      }
      yield _MenuRow(
        key: ValueKey(item.value),
        label: item.label,
        subtitle: item.subtitle,
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
        onTap: enabled ? () => _select(item, page) : null,
      );
    }

    final rows = [
      if (_path.isNotEmpty) ...[
        _MenuRow(
          label: MaterialLocalizations.of(context).backButtonTooltip,
          leading: const BackButtonIcon(),
          color: foreground,
          onTap: () => _back(page),
        ),
        _MenuHeading(label: _path.last.label, subtitle: _path.last.subtitle),
        const Divider(height: 1),
      ],
      for (final item in items) ...itemRows(item, parentEnabled: true),
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
    this.subtitle,
    required this.color,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String? subtitle;
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
                    Expanded(
                      child: _MenuText(label: label, subtitle: subtitle),
                    ),
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

class _MenuHeading extends StatelessWidget {
  const _MenuHeading({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.labelLarge,
      child: _MenuText(label: label, subtitle: subtitle),
    ),
  );
}

class _MenuText extends StatelessWidget {
  const _MenuText({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => subtitle == null
      ? Text(label)
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty) Text(label),
            Opacity(
              opacity: .72,
              child: Text(subtitle!, style: const TextStyle(fontSize: 12)),
            ),
          ],
        );
}
