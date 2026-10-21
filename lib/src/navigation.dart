import 'package:flutter/material.dart';

import 'controls.dart';
import 'actions.dart';
import 'button_group.dart';
import 'fallback_pressable.dart';
import 'fallback_selection_track.dart';
import 'feedback.dart';
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
    if (glassTheme.resolveTabBar(nativeAvailable: liquidGlassNativeAvailable) ==
        LiquidGlassMode.native) {
      final tabBar = NativeVisibility(
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
    // Keep the existing native layout limits; grouped/long-press actions use
    // the Flutter title layout with our native capsule buttons below. A
    // disabled action stays in the native bar, which updates it in place.
    final nativeActions = all.every(
      (action) =>
          action.onLongPress == null &&
          (action.icon == null || action.sfSymbol != null),
    );
    if (LiquidGlassTheme.modeOf(context) == LiquidGlassMode.native &&
        nativeActions &&
        leading.length <= 1 &&
        actions.length <= 1 &&
        MediaQuery.textScalerOf(context).scale(17) <= 24) {
      return SafeArea(
        bottom: false,
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (leading.length > 1)
              LiquidGlassButtonGroup(actions: barGroup(leading))
            else
              ...leading.map(actionButton),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: subtitle == null
                    ? Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: glassColors.foreground,
                        ),
                      )
                    // Large text scales the two lines down rather than
                    // overflowing the bar's fixed height.
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: glassColors.foreground,
                                  ),
                            ),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color:
                                        (glassColors.foreground ??
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface)
                                            .withValues(alpha: .6),
                                  ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            if (actions.length > 1)
              LiquidGlassButtonGroup(actions: barGroup(actions))
            else
              ...actions.map(actionButton),
          ],
        ),
      ),
    );
  }
}
