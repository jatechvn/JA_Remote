import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/language_provider.dart';
import '../theme/theme_provider.dart';
import 'app_toast.dart';

/// Bento Glassmorphic Script Editor with Fedora 44 Ptyxis / Adwaita theme styling.
///
/// Features:
/// - macOS / Fedora window header chrome with traffic lights and protocol pill
/// - Adaptive high-contrast color palette (Dark Obsidian Velvet & Light Adwaita Porcelain)
/// - Integrated line numbers gutter synchronized with multiline text input
/// - Action toolbar (Copy script to clipboard, Clear script)
/// - Quick snippet chips for instant command insertion
class GlassScriptEditor extends StatefulWidget {
  final TextEditingController controller;
  final String protocol; // 'powershell' or 'ssh'
  final String? title;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final List<GlassScriptSnippet>? quickSnippets;
  final ValueChanged<String>? onSelectSnippet;
  final bool expands;
  final FocusNode? focusNode;

  const GlassScriptEditor({
    super.key,
    required this.controller,
    this.protocol = 'powershell',
    this.title,
    this.hintText,
    this.minLines = 5,
    this.maxLines = 8,
    this.onChanged,
    this.onClear,
    this.quickSnippets,
    this.onSelectSnippet,
    this.expands = false,
    this.focusNode,
  });

  @override
  State<GlassScriptEditor> createState() => _GlassScriptEditorState();
}

class GlassScriptSnippet {
  final String label;
  final String command;
  final IconData? icon;

  const GlassScriptSnippet({
    required this.label,
    required this.command,
    this.icon,
  });
}

class _GlassScriptEditorState extends State<GlassScriptEditor> {
  late final ScrollController _textScrollController;
  late final ScrollController _gutterScrollController;

  @override
  void initState() {
    super.initState();
    _textScrollController = ScrollController();
    _gutterScrollController = ScrollController();

    // Synchronize gutter scrolling with editor text scrolling
    _textScrollController.addListener(_syncGutterScroll);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textScrollController.removeListener(_syncGutterScroll);
    widget.controller.removeListener(_onTextChanged);
    _textScrollController.dispose();
    _gutterScrollController.dispose();
    super.dispose();
  }

  void _syncGutterScroll() {
    if (_gutterScrollController.hasClients &&
        _textScrollController.hasClients &&
        _gutterScrollController.offset != _textScrollController.offset) {
      _gutterScrollController.jumpTo(_textScrollController.offset);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  int get _lineCount {
    final text = widget.controller.text;
    if (text.isEmpty) return 1;
    return text.split('\n').length;
  }

  int get _charCount => widget.controller.text.length;

  void _copyScript(
    BuildContext context,
    AppColors colors,
    LanguageProvider lang,
  ) {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    showAppToast(
      context,
      colors: colors,
      message: lang.t('cmd_script_copied'),
      icon: Icons.content_copy_rounded,
    );
  }

  void _clearScript() {
    widget.controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final lang = context.watch<LanguageProvider>();
    final isDark = theme.isDark;

    // Resolve Theme-Adaptive Palette (Matching Fedora 44 Terminal Engine)
    final cardBg = isDark ? const Color(0xE60E131E) : const Color(0xF6F8FAFC);
    final editorBg = isDark ? const Color(0xF40A0E17) : const Color(0xFFFFFFFF);
    final headerBg = isDark ? const Color(0xF0121724) : const Color(0xF4F1F5F9);
    final borderColor = isDark
        ? const Color(0x3894A3B8)
        : const Color(0xFFCBD5E1);
    final innerBorderColor = isDark
        ? const Color(0x2294A3B8)
        : const Color(0xFFE2E8F0);
    final textCodeColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF047857);
    final gutterBg = isDark ? const Color(0x800F1420) : const Color(0xFFF1F5F9);
    final gutterTextColor = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);

    final isPowershell = widget.protocol.toLowerCase() == 'powershell';
    final fileName =
        widget.title ?? (isPowershell ? 'script.ps1' : 'script.sh');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.expands ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // 1. Window Header Chrome (Traffic Lights + Title Pill + Actions)
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(
                bottom: BorderSide(color: innerBorderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Traffic Lights
                const Row(
                  children: [
                    _MiniTrafficLight(color: Color(0xFFFF5F56)),
                    SizedBox(width: 5),
                    _MiniTrafficLight(color: Color(0xFFFFBD2E)),
                    SizedBox(width: 5),
                    _MiniTrafficLight(color: Color(0xFF27C93F)),
                  ],
                ),
                const SizedBox(width: 10),

                // File Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x401E293B)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: innerBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPowershell
                            ? Icons.terminal_rounded
                            : Icons.code_rounded,
                        size: 13,
                        color: isPowershell
                            ? colors.accentCyan
                            : colors.accentAmber,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['Consolas', 'monospace'],
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Protocol Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPowershell
                        ? colors.accentCyan.withValues(alpha: 0.15)
                        : colors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isPowershell
                          ? colors.accentCyan.withValues(alpha: 0.4)
                          : colors.accentAmber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isPowershell ? 'POWERSHELL' : 'SSH BASH',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isPowershell
                          ? colors.accentCyan
                          : colors.accentAmber,
                    ),
                  ),
                ),

                const Spacer(),

                // Line / Char Counter
                Text(
                  lang.t('cmd_script_lines', {'count': _lineCount.toString()}),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: gutterTextColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• $_charCount c',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: gutterTextColor,
                  ),
                ),
                const SizedBox(width: 8),

                // Copy Action
                _HeaderIconButton(
                  icon: Icons.content_copy_rounded,
                  tooltip: lang.t('cmd_script_copy'),
                  color: colors.textMuted,
                  onTap: () => _copyScript(context, colors, lang),
                ),
                const SizedBox(width: 4),

                // Clear Action
                _HeaderIconButton(
                  icon: Icons.clear_all_rounded,
                  tooltip: lang.t('cmd_script_clear'),
                  color: colors.textMuted,
                  onTap: _clearScript,
                ),
              ],
            ),
          ),

          // 2. Editor Canvas with Line Numbers Gutter
          widget.expands
              ? Expanded(
                  child: Container(
                    color: editorBg,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Line Numbers Gutter
                        Container(
                          width: 36,
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            right: 6,
                          ),
                          decoration: BoxDecoration(
                            color: gutterBg,
                            border: Border(
                              right: BorderSide(
                                color: innerBorderColor,
                                width: 1,
                              ),
                            ),
                          ),
                          child: ListView.builder(
                            controller: _gutterScrollController,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: math.max(_lineCount, widget.minLines),
                            itemBuilder: (ctx, index) {
                              final hasContent = index < _lineCount;
                              return Container(
                                height: 20,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.0,
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: const [
                                      'Consolas',
                                      'monospace',
                                    ],
                                    fontWeight: FontWeight.w600,
                                    color: hasContent
                                        ? gutterTextColor
                                        : gutterTextColor.withValues(
                                            alpha: 0.35,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Multiline TextField
                        Expanded(
                          child: TextField(
                            focusNode: widget.focusNode,
                            controller: widget.controller,
                            scrollController: _textScrollController,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontFamilyFallback: const [
                                'Consolas',
                                'Courier New',
                                'monospace',
                              ],
                              fontSize: 12.5,
                              height: 1.6,
                              color: textCodeColor,
                            ),
                            cursorColor: textCodeColor,
                            cursorWidth: 2,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                10,
                                8,
                                10,
                                8,
                              ),
                              hintText:
                                  widget.hintText ?? lang.t('cmd_script_hint'),
                              hintStyle: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: gutterTextColor.withValues(alpha: 0.8),
                              ),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                            ),
                            onChanged: widget.onChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  color: editorBg,
                  height: (widget.maxLines * 20.0).clamp(110.0, 300.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line Numbers Gutter
                      Container(
                        width: 36,
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 8,
                          right: 6,
                        ),
                        decoration: BoxDecoration(
                          color: gutterBg,
                          border: Border(
                            right: BorderSide(
                              color: innerBorderColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListView.builder(
                          controller: _gutterScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: math.max(_lineCount, widget.minLines),
                          itemBuilder: (ctx, index) {
                            final hasContent = index < _lineCount;
                            return Container(
                              height: 20,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.0,
                                  fontFamily: 'monospace',
                                  fontFamilyFallback: const [
                                    'Consolas',
                                    'monospace',
                                  ],
                                  fontWeight: FontWeight.w600,
                                  color: hasContent
                                      ? gutterTextColor
                                      : gutterTextColor.withValues(alpha: 0.35),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Multiline TextField
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          scrollController: _textScrollController,
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontFamilyFallback: const [
                              'Consolas',
                              'Courier New',
                              'monospace',
                            ],
                            fontSize: 12.5,
                            height: 1.6,
                            color: textCodeColor,
                          ),
                          cursorColor: textCodeColor,
                          cursorWidth: 2,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(
                              10,
                              8,
                              10,
                              8,
                            ),
                            hintText:
                                widget.hintText ?? lang.t('cmd_script_hint'),
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: gutterTextColor.withValues(alpha: 0.8),
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                          ),
                          onChanged: widget.onChanged,
                        ),
                      ),
                    ],
                  ),
                ),

          // 3. Quick Snippet Chips Bar
          if (widget.quickSnippets != null &&
              widget.quickSnippets!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(
                  top: BorderSide(color: innerBorderColor, width: 1),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Text(
                      lang.t('script_snippets'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (final snippet in widget.quickSnippets!) ...[
                      InkWell(
                        onTap: () {
                          widget.controller.text = snippet.command;
                          widget.onSelectSnippet?.call(snippet.command);
                          widget.onChanged?.call(snippet.command);
                          if (mounted) setState(() {});
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x301E293B)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x50475569)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (snippet.icon != null) ...[
                                Icon(
                                  snippet.icon,
                                  size: 11,
                                  color: isPowershell
                                      ? colors.accentCyan
                                      : colors.accentAmber,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                snippet.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: isDark
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniTrafficLight extends StatelessWidget {
  final Color color;

  const _MiniTrafficLight({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
