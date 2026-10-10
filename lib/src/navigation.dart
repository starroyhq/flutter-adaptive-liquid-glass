import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'controls.dart';
import 'actions.dart';
import 'button_group.dart';
import 'fallback_pressable.dart';
import 'fallback_selection_track.dart';
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
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<LiquidGlassTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    if (glassTheme.resolveTabBar(nativeAvailable: liquidGlassNativeAvailable) ==
        LiquidGlassMode.native) {
      final tabBar = NativeVisibility(
        child: native.LiquidGlassTabBar(
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
          currentIndex: selectedIndex,
          selectedItemColor:
              glassTheme.colors.selectedForeground ??
              glassTheme.colors.accent ??
              Theme.of(context).colorScheme.primary,
          onTabSelected: (index) {
            if (index >= 0 && index < items.length) onSelected(index);
          },
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
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: LiquidGlassSurface(
        radius: 32,
        padding: const EdgeInsets.all(6),
        child: FallbackSelectionTrack(
          selectedIndex: selectedIndex,
          children: [
            for (var index = 0; index < items.length; index++)
              _TabItem(
                item: items[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
          ],
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
    this.leading = const [],
    this.actions = const [],
  });
  final String title;
  final List<LiquidGlassAction> leading;
  final List<LiquidGlassAction> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final glassColors = LiquidGlassTheme.of(context).colors;
    final all = [...leading, ...actions];
    // The provider's UINavigationBar only serializes SF Symbols, and has no
    // disabled-action property. Fall back instead of silently losing either.
    final nativeActions = all.every(
      (action) =>
          action.onPressed != null &&
          (action.icon == null || action.sfSymbol != null),
    );
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native &&
        nativeActions &&
        leading.length <= 1 &&
        actions.length <= 1 &&
        MediaQuery.textScalerOf(context).scale(17) <= 24) {
      native.LiquidGlassNavBarItem item(LiquidGlassAction action) =>
          native.LiquidGlassNavBarItem(
            id: action.id,
            label: action.label,
            icon: action.sfSymbol == null
                ? null
                : native.NativeLiquidGlassIcon.sfSymbol(action.sfSymbol!),
          );
      return SafeArea(
        bottom: false,
        child: NativeVisibility(
          child: native.LiquidGlassNavigationBar(
            title: title,
            height: 64,
            brightness: Theme.of(context).brightness,
            tintColor:
                glassColors.foreground ??
                glassColors.accent ??
                Theme.of(context).colorScheme.primary,
            leadingItems: leading.map(item).toList(),
            trailingItems: actions.map(item).toList(),
            onItemTapped: (id) {
              for (final action in all) {
                if (action.id == id) {
                  action.onPressed?.call();
                  return;
                }
              }
            },
          ),
        ),
      );
    }
    Widget actionButton(LiquidGlassAction action) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: LiquidGlassButton(
        label: action.icon == null ? action.label : null,
        semanticLabel: action.label,
        icon: action.icon,
        sfSymbol: action.sfSymbol,
        onPressed: action.onPressed,
      ),
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (leading.length > 1)
              LiquidGlassButtonGroup(actions: leading)
            else
              ...leading.map(actionButton),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: glassColors.foreground,
                  ),
                ),
              ),
            ),
            if (actions.length > 1)
              LiquidGlassButtonGroup(actions: actions)
            else
              ...actions.map(actionButton),
          ],
        ),
      ),
    );
  }
}
