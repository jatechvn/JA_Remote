import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'glass_widgets.dart';

class GlassDialog extends StatelessWidget {
  final Widget child;
  final String title;
  final double width;
  final double? height;
  final bool isDark;
  final double blurSigma;
  final double bgOpacity;
  final IconData? icon;
  final Widget? headerTrailing;
  final List<Widget>? actions;
  final EdgeInsetsGeometry contentPadding;

  const GlassDialog({
    super.key,
    required this.child,
    required this.title,
    this.width = 620,
    this.height,
    required this.isDark,
    this.blurSigma = 24.0,
    this.bgOpacity = 0.88,
    this.icon,
    this.headerTrailing,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 20, 24, 20),
  });

  @override
  Widget build(BuildContext context) {
    final enableTransparency = Platform.isWindows;
    final c = context.appColors;

    final bg = enableTransparency
        ? (isDark
              ? const Color(0xFF0F172A).withValues(alpha: bgOpacity)
              : const Color(0xFFFFFFFF).withValues(alpha: bgOpacity))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF));

    final border = c.borderDefault;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border(
                top: BorderSide(color: c.glassHighlight, width: 1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                mainAxisSize: height == null
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  // Modal Title Header with Close Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: c.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 18, color: c.accentColor),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (headerTrailing != null) ...[
                          headerTrailing!,
                          const SizedBox(width: 10),
                        ],
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c.subCardBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.subCardBorder),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: c.borderDefault, height: 1),
                  if (height != null)
                    Expanded(
                      child: Padding(padding: contentPadding, child: child),
                    )
                  else
                    Padding(padding: contentPadding, child: child),
                  if (actions != null && actions!.isNotEmpty) ...[
                    Divider(color: c.borderDefault, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper around [GlassDialog] for the common "item details"
/// layout — a badge row, a subtitle (e.g. version/build), a description
/// paragraph, an optional tag/stat block, and action buttons. Mirrors the
/// "exhibit detail" pattern (project details, release notes, device info).
class DetailDialog extends StatelessWidget {
  const DetailDialog({
    super.key,
    required this.title,
    required this.isDark,
    this.badges = const [],
    this.subtitle,
    this.description,
    this.tags = const [],
    this.actions,
    this.width = 460,
  });

  final String title;
  final bool isDark;
  final List<Widget> badges;
  final String? subtitle;
  final String? description;
  final List<String> tags;
  final List<Widget>? actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return GlassDialog(
      title: title,
      isDark: isDark,
      width: width,
      actions: actions,
      contentPadding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badges.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6, children: badges),
              const SizedBox(height: 10),
            ],
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (description != null)
              Text(
                description!,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.subCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.subCardBorder),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map(
                        (t) => PillBadge(
                          label: t,
                          color: c.textSecondary,
                          bg: c.subCardBg,
                          border: c.subCardBorder,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Displays a modal GlassDialog with fluent animation and backdrop blur.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  dynamic colors,
  IconData? icon,
  List<Widget>? actions,
  double width = 560,
  double? height,
}) {
  final theme = context.read<ThemeProvider>();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) {
      return GlassDialog(
        title: title,
        isDark: theme.isDark,
        width: width,
        height: height,
        icon: icon,
        actions: actions,
        child: content,
      );
    },
  );
}
