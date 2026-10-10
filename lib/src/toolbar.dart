import 'package:flutter/material.dart';

import 'actions.dart';
import 'button_group.dart';

/// Related actions share one capsule. Groups remain distinct and scroll when
/// their minimum touch targets cannot fit the available width.
class LiquidGlassToolbar extends StatelessWidget {
  LiquidGlassToolbar({
    super.key,
    required this.groups,
    this.alignment = AlignmentDirectional.centerStart,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(8),
  }) : assert(groups.isNotEmpty && groups.every((group) => group.isNotEmpty)),
       assert(spacing >= 0 && spacing < double.infinity);

  final List<List<LiquidGlassAction>> groups;
  final AlignmentGeometry alignment;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    heightFactor: 1,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i != 0) SizedBox(width: spacing),
            LiquidGlassButtonGroup(
              key: ValueKey((
                i,
                groups[i].map((action) => action.id).join('\u0000'),
              )),
              actions: groups[i],
            ),
          ],
        ],
      ),
    ),
  );
}
