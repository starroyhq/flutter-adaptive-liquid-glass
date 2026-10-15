import 'package:flutter/material.dart';
import 'feedback.dart';

import 'actions.dart';
import 'controls.dart';
import 'navigation.dart';
import 'surface.dart';
import 'theme.dart';

/// Keeps Flutter's full text editing value, including selection and IME
/// composing. Search scheduling and result state belong to the application.
class LiquidGlassSearchField extends StatefulWidget {
  const LiquidGlassSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onCancelled,
    this.showCancelButton = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onCancelled;
  final bool showCancelButton;
  final bool enabled;
  final bool autofocus;

  @override
  State<LiquidGlassSearchField> createState() => _LiquidGlassSearchFieldState();
}

class _LiquidGlassSearchFieldState extends State<LiquidGlassSearchField> {
  late TextEditingController _controller;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focus = widget.focusNode ?? FocusNode();
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void didUpdateWidget(covariant LiquidGlassSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final value = _controller.value;
      _controller.removeListener(_refresh);
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? TextEditingController.fromValue(value);
      _controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _clear() {
    if (!widget.enabled || !LiquidGlassFeedback.canInteract(context)) return;
    LiquidGlassFeedback.tap(context);
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final glass = LiquidGlassTheme.of(context);
    final colors = Theme.of(context).colorScheme;
    final foreground = glass.colors.foreground ?? colors.onSurface;
    final localizations = MaterialLocalizations.of(context);
    final field = LiquidGlassSurface(
      radius: 26,
      style: LiquidGlassSurfaceStyle.control,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.search, color: foreground)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: foreground),
              cursorColor: glass.colors.accent ?? colors.primary,
              decoration: InputDecoration(
                hintText: widget.hintText ?? localizations.searchFieldLabel,
                hintStyle: TextStyle(color: foreground.withValues(alpha: .55)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              enableFeedback: false,
              tooltip: localizations.deleteButtonTooltip,
              onPressed: widget.enabled ? _clear : null,
              color: foreground,
              icon: const Icon(Icons.cancel_outlined),
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
    final cancel = TextButton(
      onPressed: widget.enabled
          ? () {
              if (!LiquidGlassFeedback.canInteract(context)) return;
              LiquidGlassFeedback.tap(context);
              _focus.unfocus();
              widget.onCancelled?.call();
            }
          : null,
      style: TextButton.styleFrom(
        enableFeedback: false,
        foregroundColor: glass.colors.accent ?? colors.primary,
      ),
      child: Text(localizations.cancelButtonLabel),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = TextPainter(
          text: TextSpan(
            text: localizations.cancelButtonLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        // Keep a usable editor and full-size clear target at large text sizes.
        final stacked =
            widget.showCancelButton &&
            constraints.maxWidth < label.width + 32 + 184;
        label.dispose();
        if (stacked) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              Align(alignment: AlignmentDirectional.centerEnd, child: cancel),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            if (widget.showCancelButton) cancel,
          ],
        );
      },
    );
  }
}

/// Where [LiquidGlassSearchScaffold] puts search.
enum LiquidGlassSearchPlacement {
  /// A search field above the body on every tab.
  top,

  /// A round search button after the tabs, as on iOS 26. Activating it docks
  /// the search field at the bottom, above the keyboard, with a close button.
  tabBar,
}

/// A layout for application-owned pages and search. No nested Navigator is
/// created; pass a Router/ShellRoute child or your own state-preserving body.
class LiquidGlassSearchScaffold extends StatefulWidget {
  const LiquidGlassSearchScaffold({
    super.key,
    required this.body,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.searchController,
    required this.searchActive,
    required this.onSearchActiveChanged,
    this.searchFocusNode,
    this.searchHint,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.searchResults,
    this.appBar,
    this.searchPlacement = LiquidGlassSearchPlacement.top,
    this.searchLabel,
  }) : assert(tabs.length >= 2 && tabs.length <= 5),
       assert(selectedIndex >= 0 && selectedIndex < tabs.length);

  final Widget body;
  final List<LiquidGlassTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final bool searchActive;
  final ValueChanged<bool> onSearchActiveChanged;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final Widget? searchResults;
  final PreferredSizeWidget? appBar;
  final LiquidGlassSearchPlacement searchPlacement;

  /// Accessibility label of the search button with
  /// [LiquidGlassSearchPlacement.tabBar]; defaults to [searchHint], then to
  /// the platform's search label.
  final String? searchLabel;

  @override
  State<LiquidGlassSearchScaffold> createState() =>
      _LiquidGlassSearchScaffoldState();
}

class _LiquidGlassSearchScaffoldState extends State<LiquidGlassSearchScaffold> {
  late FocusNode _focus = widget.searchFocusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.searchActive) _focus.requestFocus();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassSearchScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFocusNode != widget.searchFocusNode) {
      if (oldWidget.searchFocusNode == null) _focus.dispose();
      _focus = widget.searchFocusNode ?? FocusNode();
    }
    if (widget.searchActive != oldWidget.searchActive ||
        widget.searchFocusNode != oldWidget.searchFocusNode) {
      if (widget.searchActive) {
        _focus.requestFocus();
      } else {
        _focus.unfocus();
      }
    }
  }

  @override
  void dispose() {
    if (widget.searchFocusNode == null) _focus.dispose();
    super.dispose();
  }

  Widget _field({required bool cancel}) => Focus(
    onFocusChange: (focused) {
      if (focused && !widget.searchActive) {
        widget.onSearchActiveChanged(true);
      }
    },
    child: LiquidGlassSearchField(
      controller: widget.searchController,
      focusNode: _focus,
      hintText: widget.searchHint,
      showCancelButton: cancel && widget.searchActive,
      onCancelled: () => widget.onSearchActiveChanged(false),
      onChanged: widget.onSearchChanged,
      onSubmitted: widget.onSearchSubmitted,
    ),
  );

  Widget _content() => Stack(
    fit: StackFit.expand,
    children: [
      Visibility(
        visible: !widget.searchActive || widget.searchResults == null,
        maintainState: true,
        child: widget.body,
      ),
      if (widget.searchActive && widget.searchResults != null)
        widget.searchResults!,
    ],
  );

  @override
  Widget build(BuildContext context) =>
      widget.searchPlacement == LiquidGlassSearchPlacement.tabBar
      ? _tabBarSearch(context)
      : _topSearch(context);

  Widget _tabBarSearch(BuildContext context) {
    final label =
        widget.searchLabel ??
        widget.searchHint ??
        MaterialLocalizations.of(context).searchFieldLabel;
    return Scaffold(
      appBar: widget.appBar,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _content()),
            // The body resizes for the keyboard, so the docked field rides
            // above it; the tab bar stays out of the way while searching.
            if (widget.searchActive)
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: _field(cancel: false)),
                    const SizedBox(width: 10),
                    LiquidGlassButton.icon(
                      id: 'search-close',
                      icon: Icons.close,
                      sfSymbol: 'xmark',
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).closeButtonLabel,
                      onPressed: () => widget.onSearchActiveChanged(false),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: widget.searchActive
          ? null
          : LiquidGlassTabBar(
              items: widget.tabs,
              selectedIndex: widget.selectedIndex,
              onSelected: widget.onTabChanged,
              trailingAction: LiquidGlassAction(
                id: 'search',
                label: label,
                icon: Icons.search,
                sfSymbol: 'magnifyingglass',
                onPressed: () => widget.onSearchActiveChanged(true),
              ),
            ),
    );
  }

  Widget _topSearch(BuildContext context) => Scaffold(
    appBar: widget.appBar,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _field(cancel: true),
          ),
          Expanded(child: _content()),
        ],
      ),
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : LiquidGlassTabBar(
            items: widget.tabs,
            selectedIndex: widget.selectedIndex,
            onSelected: widget.onTabChanged,
          ),
  );
}
