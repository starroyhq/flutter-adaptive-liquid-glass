import 'package:flutter/material.dart';

import 'controls.dart';
import 'feedback.dart';
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
    this.enabled = true,
    this.destructive = false,
    this.selected = false,
    this.children = const [],
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool destructive;
  final bool selected;
  final List<LiquidGlassMenuItem<T>> children;
}

/// A glass button with an anchored, keyboard-accessible hierarchical menu.
///
/// Every instance owns its route and anchor; several menu buttons can coexist.
/// Selecting a branch opens that branch within the same popover. An explicit
/// Back row returns to its parent without completing the selection.
class LiquidGlassMenuButton<T extends Object> extends StatefulWidget {
  LiquidGlassMenuButton({
    super.key,
    required this.items,
    this.onSelected,
    this.onCanceled,
    this.label,
    this.icon = Icons.more_horiz,
    this.sfSymbol = 'ellipsis',
    this.semanticLabel,
    this.enabled = true,
    this.trigger = LiquidGlassMenuTrigger.tapAndLongPress,
    this.longPressSemanticLabel,
    this.useRootNavigator = true,
    this.width = 300,
    this.builder,
  }) : assert(label != null || semanticLabel != null || builder != null),
       assert(width > 0 && width.isFinite);

  final List<LiquidGlassMenuItem<T>> items;
  final ValueChanged<T>? onSelected;
  final VoidCallback? onCanceled;
  final String? label;
  final IconData? icon;
  final String? sfSymbol;
  final String? semanticLabel;
  final bool enabled;
  final LiquidGlassMenuTrigger trigger;
  final String? longPressSemanticLabel;
  final bool useRootNavigator;
  final double width;

  /// Builds a custom trigger. A null callback means the trigger is disabled.
  ///
  /// Custom builders keep ownership of their gestures and feedback. [trigger]
  /// controls only the default button; this callback may be used for either
  /// gesture without changing the existing builder signature.
  final Widget Function(BuildContext context, VoidCallback? open)? builder;

  @override
  State<LiquidGlassMenuButton<T>> createState() =>
      _LiquidGlassMenuButtonState<T>();
}

class _LiquidGlassMenuButtonState<T extends Object>
    extends State<LiquidGlassMenuButton<T>> {
  bool _opening = false;

  Future<void> _open(BuildContext anchorContext) async {
    if (!mounted ||
        _opening ||
        !widget.enabled ||
        widget.items.isEmpty ||
        !LiquidGlassFeedback.canInteract(context)) {
      return;
    }
    final values = <T>{};
    List<LiquidGlassMenuItem<T>> snapshot(List<LiquidGlassMenuItem<T>> items) =>
        List.unmodifiable(
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
              enabled: item.enabled,
              destructive: item.destructive,
              selected: item.selected,
              children: snapshot(item.children),
            );
          }),
        );
    final items = snapshot(widget.items);
    setState(() => _opening = true);
    try {
      final result = await showLiquidGlassPopover<T>(
        context: context,
        anchorContext: anchorContext,
        useRootNavigator: widget.useRootNavigator,
        width: widget.width,
        semanticLabel: widget.semanticLabel ?? widget.label,
        builder: (context) => _Menu<T>(items: items),
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
      // The route already guards repeated presentation. Keeping the default
      // trigger enabled preserves its keyboard focus history while covered;
      // temporarily disabling it would prevent restoration after menu close.
      final VoidCallback? defaultOpen =
          widget.enabled && widget.items.isNotEmpty
          ? () => _open(anchorContext)
          : null;
      return LiquidGlassButton(
        label: widget.label,
        icon: widget.icon,
        sfSymbol: widget.sfSymbol,
        semanticLabel: widget.semanticLabel ?? widget.label,
        onPressed: widget.trigger == LiquidGlassMenuTrigger.longPress
            ? null
            : defaultOpen,
        onLongPress: widget.trigger == LiquidGlassMenuTrigger.tap
            ? null
            : defaultOpen,
        longPressSemanticLabel:
            widget.longPressSemanticLabel ??
            widget.semanticLabel ??
            widget.label,
      );
    },
  );
}

class _Menu<T extends Object> extends StatefulWidget {
  const _Menu({required this.items});
  final List<LiquidGlassMenuItem<T>> items;

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
    return ListView(
      key: ValueKey(_path.isEmpty ? null : _path.last.value),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
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
            leading: item.icon == null ? null : Icon(item.icon, size: 22),
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
      ],
    );
  }
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
                opacity: onTap == null ? .4 : 1,
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
