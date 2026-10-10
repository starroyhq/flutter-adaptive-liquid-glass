import 'package:flutter/material.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

class CatalogPopups extends StatefulWidget {
  const CatalogPopups({super.key});
  @override
  State<CatalogPopups> createState() => _CatalogPopupsState();
}

class _CatalogPopupsState extends State<CatalogPopups> {
  String result = 'No selection';
  void record(Object? value) {
    if (mounted) setState(() => result = value?.toString() ?? 'Cancelled');
  }

  static const items = [
    LiquidGlassMenuItem(value: 'copy', label: 'Copy', icon: Icons.copy),
    LiquidGlassMenuItem(value: 'selected', label: 'Selected', selected: true),
    LiquidGlassMenuItem(
      value: 'disabled',
      label: 'Unavailable',
      enabled: false,
    ),
    LiquidGlassMenuItem(
      value: 'more',
      label: 'More',
      children: [LiquidGlassMenuItem(value: 'nested', label: 'Nested choice')],
    ),
    LiquidGlassMenuItem(value: 'delete', label: 'Delete', destructive: true),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Multiple independent menu triggers'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final label in ['First menu', 'Second menu', 'Third menu'])
            LiquidGlassMenuButton<String>(
              key: ValueKey(label),
              label: label,
              items: items,
              onSelected: (value) => record('$label: $value'),
              onCanceled: () => record(null),
            ),
        ],
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          LiquidGlassButton(
            key: const ValueKey('catalog-alert'),
            label: 'Alert',
            onPressed: () async => record(
              await showLiquidGlassAlert<String>(
                context: context,
                title: const Text('Confirm action'),
                content: const Text('Only synthetic preview data is used.'),
                actions: const [
                  LiquidGlassAlertAction(
                    label: 'Cancel',
                    value: 'cancel',
                    cancel: true,
                  ),
                  LiquidGlassAlertAction(label: 'Continue', value: 'continue'),
                ],
              ),
            ),
          ),
          LiquidGlassButton(
            key: const ValueKey('catalog-action-sheet'),
            label: 'Action sheet',
            onPressed: () async => record(
              await showLiquidGlassAlert<String>(
                context: context,
                style: LiquidGlassAlertStyle.actionSheet,
                title: const Text('Preview actions'),
                actions: const [
                  LiquidGlassAlertAction(
                    label: 'Cancel',
                    value: 'cancel',
                    cancel: true,
                  ),
                  LiquidGlassAlertAction(
                    label: 'Delete preview',
                    value: 'delete',
                    destructive: true,
                  ),
                ],
              ),
            ),
          ),
          LiquidGlassButton(
            key: const ValueKey('catalog-sheet'),
            label: 'Mixed sheet',
            onPressed: () async => record(
              await showLiquidGlassSheet<String>(
                context: context,
                builder: (_) => const CatalogMixedPane(depth: 1),
              ),
            ),
          ),
          Builder(
            builder: (anchor) => LiquidGlassButton(
              key: const ValueKey('catalog-popover'),
              label: 'Popover',
              onPressed: () async => record(
                await showLiquidGlassPopover<String>(
                  context: context,
                  anchorContext: anchor,
                  builder: (_) => const CatalogMixedPane(depth: 1),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(result, key: const ValueKey('catalog-popup-result')),
    ],
  );
}

/// Shared by sheet/popover and device tests; native controls alternate with
/// Flutter labels and an editor so hybrid composition regressions are visible.
class CatalogMixedPane extends StatefulWidget {
  const CatalogMixedPane({super.key, required this.depth});
  final int depth;
  @override
  State<CatalogMixedPane> createState() => _CatalogMixedPaneState();
}

class _CatalogMixedPaneState extends State<CatalogMixedPane> {
  final draft = TextEditingController();
  bool enabled = false;
  double level = .5;
  int segment = 0;
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    primary: true,
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Mixed layer ${widget.depth}',
        key: ValueKey('popup-title-${widget.depth}'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      LiquidGlassSearchField(
        key: ValueKey('popup-draft-${widget.depth}'),
        controller: draft,
        hintText: '中文 👩🏽‍💻 draft',
      ),
      const SizedBox(height: 12),
      LiquidGlassSegmentedControl<int>(
        segments: const [
          LiquidGlassSegment(value: 0, label: 'Recent'),
          LiquidGlassSegment(value: 1, label: 'All'),
        ],
        selected: segment,
        onChanged: (value) => setState(() => segment = value),
      ),
      const Text('Flutter text between native controls'),
      LiquidGlassSlider(
        value: level,
        semanticLabel: 'Layer level',
        onChanged: (value) => setState(() => level = value),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: LiquidGlassSwitch(
          value: enabled,
          semanticLabel: 'Layer enabled',
          onChanged: (value) => setState(() => enabled = value),
        ),
      ),
      const SizedBox(height: 12),
      // Plain Flutter triggers make the route tests independent of whether the
      // platform-view driver can synthesize a UIKit button touch.
      TextButton(
        key: ValueKey('popup-nest-${widget.depth}'),
        onPressed: () => showLiquidGlassSheet<void>(
          context: context,
          builder: (_) => CatalogMixedPane(depth: widget.depth + 1),
        ),
        child: const Text('Nest sheet'),
      ),
      Builder(
        builder: (anchor) => TextButton(
          onPressed: () => showLiquidGlassPopover<void>(
            context: context,
            anchorContext: anchor,
            builder: (_) => CatalogMixedPane(depth: widget.depth + 1),
          ),
          child: const Text('Nest popover'),
        ),
      ),
      TextButton(
        key: ValueKey('popup-close-${widget.depth}'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close layer'),
      ),
    ],
  );
}
