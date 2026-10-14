import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'actions.dart';
import 'button_group.dart';
import 'controls.dart';

/// The action row at the foot of a sheet or form.
///
/// The last action is the one the form exists for, so it becomes a prominent
/// [LiquidGlassButton] at the trailing edge. Any earlier actions share one glass
/// capsule ([LiquidGlassButtonGroup]) at the leading edge. When both do not fit
/// on one line, as with large text on a narrow screen, they stack at the
/// trailing edge, and the capsule scrolls sideways if it still cannot fit. A
/// disabled last action gives up its emphasis until it can be pressed.
///
/// Each action's [LiquidGlassAction.id] becomes the key of its widget, and the
/// accessibility identifier of its native button. Native buttons are platform
/// views, which Flutter finders cannot press; UI tests find them by identifier.
class LiquidGlassActionBar extends StatelessWidget {
  LiquidGlassActionBar({
    super.key,
    required this.actions,
    this.spacing = 12,
    this.padding = EdgeInsets.zero,
  }) : assert(actions.isNotEmpty),
       assert(
         actions.map((action) => action.id).toSet().length == actions.length,
       ),
       assert(spacing >= 0 && spacing < double.infinity);

  /// The last action is the prominent one; at least one is required.
  final List<LiquidGlassAction> actions;

  /// The gap between the capsule and the prominent button.
  final double spacing;

  /// The space between the bar's edges and its buttons. The capsule's soft
  /// shadow needs 8 points around it, so the bar keeps at least that much
  /// above, below and before the capsule, whatever the padding.
  final EdgeInsetsGeometry padding;

  /// The capsule's shadow falls just outside its bounds, which the sideways
  /// scroll view would clip without this room.
  static const double _bleed = 8;

  @override
  Widget build(BuildContext context) {
    final primary = actions.last;
    final others = actions.sublist(0, actions.length - 1);
    // The scroll view and the button already carry the shadow room inside the
    // bar, so take it out of what the caller asked for. Only a capsule needs
    // room before it.
    final direction = Directionality.of(context);
    final resolved = padding.resolve(direction);
    final start = direction == TextDirection.ltr
        ? resolved.left
        : resolved.right;
    final end = direction == TextDirection.ltr ? resolved.right : resolved.left;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        math.max(0, start - (others.isEmpty ? 0 : _bleed)),
        math.max(0, resolved.top - _bleed),
        end,
        math.max(0, resolved.bottom - _bleed),
      ),
      child: OverflowBar(
        // A lone action sits at the end; the bar cannot space out one child.
        alignment: others.isEmpty
            ? MainAxisAlignment.end
            : MainAxisAlignment.spaceBetween,
        spacing: spacing,
        overflowAlignment: OverflowBarAlignment.end,
        children: [
          if (others.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(_bleed),
              child: LiquidGlassButtonGroup(actions: others),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: _bleed),
            child: LiquidGlassButton(
              key: ValueKey(primary.id),
              id: primary.id,
              label: primary.label,
              icon: primary.icon,
              sfSymbol: primary.sfSymbol,
              onPressed: primary.onPressed,
              onLongPress: primary.onLongPress,
              longPressSemanticLabel: primary.longPressSemanticLabel,
              prominent: true,
            ),
          ),
        ],
      ),
    );
  }
}
