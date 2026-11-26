import 'package:flutter/material.dart';

import 'controls.dart';
import 'actions.dart';
import 'button_group.dart';
import 'fallback_pressable.dart';
import 'fallback_selection_track.dart';
import 'feedback.dart';
import 'menu.dart';
import 'native_fallback_report.dart';
import 'native_navigation_bar.dart';
import 'native_tab_bar.dart';
import 'native_tab_item.dart';
import 'surface.dart';
import 'theme.dart';
import 'native_visibility.dart';

@immutable
class LiquidGlassTabItem {
  const LiquidGlassTabItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.sfSymbol,
    this.badge,
  });
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? sfSymbol;
  final String? badge;
}

class LiquidGlassTabBar extends StatelessWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.trailingAction,
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<LiquidGlassTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// A separate round button after the tabs, such as search. It never
  /// changes the selected tab. On iOS 26 it is the tab bar's own search-style
  /// item; its icon defaults to a magnifying glass.
  final LiquidGlassAction? trailingAction;

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    if (glassTheme.resolveTabBar(nativeAvailable: liquidGlassNativeAvailable) !=
        LiquidGlassMode.native) {
      return _buildFallback(context);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: nativeTabBarInVerticalBar,
      builder: (context, inVerticalBar, _) {
        if (!inVerticalBar) return _buildNative(context, glassTheme);
        reportNativeFallback(
          'LiquidGlassTabBar',
          'UIKit puts the system tab bar in the vertical bar at the screen '
              'edge, where only the selected tab shows',
          'To keep the native bar, return .disabled from '
              'preferredVerticalBarBehavior in the app\'s root view '
              'controller (iOS 27.1 SDK).',
        );
        return _buildFallback(context);
      },
    );
  }

  Widget _buildNative(BuildContext context, LiquidGlassThemeData glassTheme) {
    final tabBar = NativeCoverFallback(
      fallback: _buildFallback,
      alignment: Alignment.bottomCenter,
      child: NativeVisibility(
        child: NativeTabBar(
          items: [
            for (final item in items)
              nativeTabItem(
                label: item.label,
                icon: item.icon,
                selectedIcon: item.selectedIcon,
                sfSymbol: item.sfSymbol,
                badge: item.badge,
              ),
          ],
          // Debug builds assert the range; keep the native bar valid in release.
          currentIndex: selectedIndex.clamp(0, items.length - 1),
          action: trailingAction == null
              ? null
              : nativeTabItem(
                  label: trailingAction!.label,
                  icon: trailingAction!.icon ?? Icons.search,
                  sfSymbol: trailingAction!.sfSymbol ?? 'magnifyingglass',
                ),
          onActionPressed: trailingAction?.onPressed == null
              ? null
              : () {
                  if (!LiquidGlassFeedback.canInteract(context)) return;
                  LiquidGlassFeedback.tap(context);
                  trailingAction!.onPressed!();
                },
          selectedItemColor:
              glassTheme.colors.selectedForeground ??
              glassTheme.colors.accent ??
              Theme.of(context).colorScheme.primary,
          onTabSelected: (index) {
            if (index >= 0 && index < items.length) onSelected(index);
          },
        ),
      ),
    );
    // UIKit keeps its native Liquid Glass shape, selection, hit testing and
    // system accessibility behavior. An app-specific transparency preference
    // only removes the content behind it; no private accessibility API is used.
    return glassTheme.reduceTransparency ||
            glassTheme.mode == LiquidGlassMode.opaque
        ? ColoredBox(
            color:
                (glassTheme.colors.surfaceTint ??
                        Theme.of(context).colorScheme.surface)
                    .withValues(alpha: 1),
            child: tabBar,
          )
        : tabBar;
  }

  Widget _buildFallback(BuildContext context) {
    final tabs = LiquidGlassSurface(
      radius: 32,
      padding: const EdgeInsets.all(6),
      child: FallbackSelectionTrack(
        selectedIndex: selectedIndex,
        children: [
          for (var index = 0; index < items.length; index++)
            _TabItem(
              item: items[index],
              selected: index == selectedIndex,
              onTap: () {
                if (!LiquidGlassFeedback.canInteract(context)) return;
                if (index != selectedIndex) {
                  LiquidGlassFeedback.selection(context);
                }
                onSelected(index);
              },
            ),
        ],
      ),
    );
    final action = trailingAction;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: action == null
          ? tabs
          : Row(
              children: [
                Expanded(child: tabs),
                const SizedBox(width: 10),
                _TrailingTab(action: action),
              ],
            ),
    );
  }
}

/// The round button after the fallback tab capsule, as tall as the capsule.
class _TrailingTab extends StatelessWidget {
  const _TrailingTab({required this.action});
  final LiquidGlassAction action;

  @override
  Widget build(BuildContext context) {
    final onPressed = action.onPressed;
    final glassColors = LiquidGlassTheme.of(context).colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: action.label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? .48 : 1,
        child: LiquidGlassSurface(
          radius: 32,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: FallbackPressable(
              borderRadius: BorderRadius.circular(32),
              onTap: onPressed == null
                  ? null
                  : () {
                      if (!LiquidGlassFeedback.canInteract(context)) return;
                      onPressed();
                    },
              child: SizedBox.square(
                // The capsule's 52-point items plus its 6-point padding.
                dimension: 64,
                child: Icon(
                  action.icon ?? Icons.search,
                  size: 24,
                  color:
                      glassColors.foreground ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final LiquidGlassTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final glassColors = LiquidGlassTheme.of(context).colors;
    final color = selected
        ? glassColors.selectedForeground ??
              glassColors.foreground ??
              colors.onSurface
        : glassColors.foreground ?? colors.onSurface;
    final icon = Icon(
      selected ? item.selectedIcon ?? item.icon : item.icon,
      size: 20,
      color: color,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: item.badge == null ? item.label : '${item.label}, ${item.badge}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: FallbackPressable(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          scaleOnPress: false,
          feedbackOnTap: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  item.badge == null
                      ? icon
                      : Badge(label: Text(item.badge!), child: icon),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Use as Scaffold.appBar. Flutter owns navigation; actions are explicit.
class LiquidGlassNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading = const [],
    this.actions = const [],
  });
  final String title;

  /// A second line under the title, such as the context of the page. On
  /// iOS 26 it is the navigation item's own subtitle.
  final String? subtitle;
  final List<LiquidGlassAction> leading;
  final List<LiquidGlassAction> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final glassColors = LiquidGlassTheme.of(context).colors;
    final all = [...leading, ...actions];
    assert(
      all.map((action) => action.id).toSet().length == all.length,
      'Navigation bar action IDs must be unique across both sides.',
    );
    // Long-press actions and large text still use the Flutter title layout.
    final nativeMode =
        LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native;
    final reasons = <(String, String)>[
      if (all.any((action) => action.onLongPress != null))
        (
          'an action has onLongPress',
          'Remove onLongPress from the bar actions for the native bar.',
        ),
      if (MediaQuery.textScalerOf(context).scale(17) > 24)
        (
          'the text scale is above the native bar\'s fixed height',
          'The native bar returns at a smaller text size.',
        ),
    ];
    if (nativeMode) {
      for (final (reason, fix) in reasons) {
        reportNativeFallback('LiquidGlassNavigationBar', reason, fix);
      }
    }
    if (nativeMode && reasons.isEmpty) {
      return SafeArea(
        bottom: false,
        child: NativeCoverFallback(
          fallback: (_) => this,
          child: NativeVisibility(
            child: NativeNavigationBar(
              title: title,
              subtitle: subtitle,
              tintColor:
                  glassColors.foreground ??
                  glassColors.accent ??
                  Theme.of(context).colorScheme.primary,
              leading: leading,
              actions: actions,
            ),
          ),
        ),
      );
    }
    // Like the native bar's items, a grouped bar action shows its icon or
    // its label, never both.
    List<LiquidGlassAction> barGroup(List<LiquidGlassAction> actions) => [
      for (final action in actions)
        action.showLabel
            ? LiquidGlassAction(
                id: action.id,
                label: action.label,
                icon: action.icon,
                sfSymbol: action.sfSymbol,
                onPressed: action.onPressed,
                onLongPress: action.onLongPress,
                longPressSemanticLabel: action.longPressSemanticLabel,
              )
            : action,
    ];
    Widget actionButton(LiquidGlassAction action) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: LiquidGlassButton(
        label: action.icon == null ? action.label : null,
        semanticLabel: action.label,
        icon: action.icon,
        sfSymbol: action.sfSymbol,
        onPressed: action.onPressed,
        onLongPress: action.onLongPress,
        longPressSemanticLabel: action.longPressSemanticLabel,
      ),
    );
    Widget actionTray(List<LiquidGlassAction> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      if (items.any(
        (action) =>
            action.menu != null ||
            action.badge != null ||
            action.iconPng != null,
      )) {
        return LiquidGlassSurface(
          radius: 24,
          style: LiquidGlassSurfaceStyle.control,
          padding: EdgeInsets.symmetric(horizontal: items.length > 1 ? 4 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                _NavigationAction(key: ValueKey(item.id), action: item),
            ],
          ),
        );
      }
      return items.length > 1
          ? LiquidGlassButtonGroup(actions: barGroup(items))
          : actionButton(items.single);
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Leave room for the title. Inline groups keep their own width
            // when they fit and scroll independently on crowded bars.
            final available = (constraints.maxWidth - 48).clamp(
              0.0,
              double.infinity,
            );
            final sideWidth = leading.isNotEmpty && actions.isNotEmpty
                ? available / 2
                : available.toDouble();
            Widget tray(List<LiquidGlassAction> items) => items.isEmpty
                ? const SizedBox.shrink()
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: sideWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: actionTray(items),
                    ),
                  );
            return Row(
              children: [
                tray(leading),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _fallbackTitle(context, glassColors.foreground),
                  ),
                ),
                tray(actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fallbackTitle(BuildContext context, Color? foreground) {
    final theme = Theme.of(context);
    if (subtitle == null) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge?.copyWith(color: foreground),
      );
    }
    // Large text scales the two lines down to fit the bar's fixed height.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
          Text(
            subtitle!,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: (foreground ?? theme.colorScheme.onSurface).withValues(
                alpha: .6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain Flutter action inside the navigation tray's shared surface.
class _NavigationAction extends StatelessWidget {
  const _NavigationAction({super.key, required this.action});

  final LiquidGlassAction action;

  @override
  Widget build(BuildContext context) {
    final menu = action.menu;
    if (menu == null) return _button(context, action.onPressed);
    return LiquidGlassMenuButton<String>(
      id: action.id,
      semanticLabel: action.label,
      items: menu.items,
      enabled: menu.enabled,
      onSelected: menu.onSelected,
      builder: _button,
    );
  }

  Widget _button(BuildContext context, VoidCallback? onTap) {
    final foreground =
        LiquidGlassTheme.of(context).colors.foreground ??
        Theme.of(context).colorScheme.onSurface;
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(action.label, style: TextStyle(color: foreground)),
    );
    final icon = action.icon;
    final png = action.iconPng;
    final glyph = icon == null
        ? label
        : Icon(icon, size: 22, color: foreground);
    Widget content = png == null
        ? glyph
        : Image.memory(
            png,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => glyph,
          );
    final badge = action.badge;
    if (badge != null) {
      content = Badge(
        label: badge.isEmpty ? null : Text(badge),
        child: content,
      );
    }
    final onLongPress = action.onLongPress;
    final enabled = onTap != null || onLongPress != null;
    return Tooltip(
      message: action.label,
      triggerMode: onLongPress == null ? null : TooltipTriggerMode.manual,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: action.label,
        value: badge == null || badge.isEmpty ? null : badge,
        onTap: onTap == null
            ? null
            : () {
                if (!LiquidGlassFeedback.canInteract(context)) return;
                LiquidGlassFeedback.tap(context);
                onTap();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                if (!LiquidGlassFeedback.canInteract(context)) return;
                LiquidGlassFeedback.longPress(context);
                onLongPress();
              },
        onLongPressHint: action.longPressSemanticLabel,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: FallbackPressable(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            onLongPress: onLongPress,
            longPressSemanticLabel: action.longPressSemanticLabel,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Opacity(
                opacity: enabled ? 1 : .48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Center(widthFactor: 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
