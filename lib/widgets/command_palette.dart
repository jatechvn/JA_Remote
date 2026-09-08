import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import 'glass_widgets.dart';

/// One entry in the command palette's result list.
class CommandPaletteItem {
  const CommandPaletteItem({
    required this.label,
    required this.icon,
    required this.onSelect,
    this.subtitle,
    this.keywords = const [],
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onSelect;
  final List<String> keywords;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return label.toLowerCase().contains(q) ||
        (subtitle?.toLowerCase().contains(q) ?? false) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

/// Ctrl+K spotlight-style command palette. Open it with [showCommandPalette]
/// rather than constructing this directly.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.items, required this.colors});

  final List<CommandPaletteItem> items;
  final AppColors colors;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  late List<CommandPaletteItem> _filtered = widget.items;
  int _selected = 0;
  final _scrollController = ScrollController();

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (_filtered.isEmpty) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.enter) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      final item = _filtered[_selected];
      Navigator.of(context).pop();
      item.onSelect();
    } else {
      setState(
        () => _selected =
            (_selected + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            _filtered.length,
      );
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          (_selected * 64.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _filtered = widget.items
          .where((item) => item.matches(value.trim()))
          .toList();
      _selected = 0;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final theme = context.watch<ThemeProvider>();

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: theme.dialogBlur,
            sigmaY: theme.dialogBlur,
          ),
          child: Container(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.45 : 0.20),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 120),
            child: GestureDetector(
              onTap: () {}, // absorb taps so they don't bubble to the backdrop
              child: Focus(
                onKeyEvent: _handleKey,
                child: _CommandPaletteCard(
                  colors: c,
                  theme: theme,
                  controller: _controller,
                  onQueryChanged: _onQueryChanged,
                  filtered: _filtered,
                  selected: _selected,
                  scrollController: _scrollController,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandPaletteCard extends StatelessWidget {
  const _CommandPaletteCard({
    required this.colors,
    required this.theme,
    required this.controller,
    required this.onQueryChanged,
    required this.filtered,
    required this.selected,
    required this.scrollController,
  });

  final AppColors colors;
  final ThemeProvider theme;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final List<CommandPaletteItem> filtered;
  final int selected;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final bg = theme.isDark
        ? const Color(0xFF0F172A).withValues(alpha: theme.dialogOpacity)
        : const Color(0xFFFFFFFF).withValues(alpha: theme.dialogOpacity);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent(),
      },
      child: Actions(
        actions: {
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) => Navigator.of(context).pop(),
          ),
        },
        child: Container(
          width: 560,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderDefault),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border(
              top: BorderSide(color: colors.glassHighlight, width: 1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: onQueryChanged,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type a command or search…',
                            hintStyle: TextStyle(color: colors.textMuted),
                          ),
                        ),
                      ),
                      KbdTag(label: 'ESC', colors: colors),
                    ],
                  ),
                ),
                Divider(color: colors.borderDefault, height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No results',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemExtent: 64,
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(6),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                selected: index == selected,
                                selectedTileColor: colors.accentColor
                                    .withValues(alpha: 0.14),
                                dense: true,
                                leading: Icon(
                                  item.icon,
                                  size: 18,
                                  color: colors.accentColor,
                                ),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: item.subtitle != null
                                    ? Text(
                                        item.subtitle!,
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 11,
                                        ),
                                      )
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  item.onSelect();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the command palette as a transparent-barrier dialog (the barrier
/// is painted by [CommandPalette] itself so it can fade/scale in together
/// with the content).
Future<void> showCommandPalette(
  BuildContext context, {
  required List<CommandPaletteItem> items,
}) {
  final colors = context.read<ThemeProvider>().colors;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command Palette',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) {
      return CommandPalette(items: items, colors: colors);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
}

/// Wraps [child] with a global Ctrl+K (and Cmd+K) shortcut that opens the
/// command palette. Wrap this around the app's root content (e.g. inside
/// `MaterialApp.builder` or directly around `DashboardShell`).
///
/// [items] is a callback (not a fixed list) so the palette always reflects
/// current app state — e.g. the current view's available actions.
class CommandPaletteShortcut extends StatelessWidget {
  const CommandPaletteShortcut({
    super.key,
    required this.child,
    required this.items,
  });

  final Widget child;
  final List<CommandPaletteItem> Function() items;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _OpenPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const _OpenPaletteIntent(),
      },
      child: Actions(
        actions: {
          _OpenPaletteIntent: CallbackAction<_OpenPaletteIntent>(
            onInvoke: (_) {
              showCommandPalette(context, items: items());
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
