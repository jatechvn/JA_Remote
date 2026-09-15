import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

/// Reusable Bento Glass Card surface with subtle border, backdrop blur and rounded corners.
class GlassCard extends StatelessWidget {
  final Widget child;
  final AppColors colors;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? blurSigma;
  final double? bgOpacity;
  final VoidCallback? onTap;
  final bool isFeatured;
  final Color? customBg;
  final Color? customBorder;

  const GlassCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding,
    this.borderRadius = 12,
    this.blurSigma,
    this.bgOpacity,
    this.onTap,
    this.isFeatured = false,
    this.customBg,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      borderRadius: borderRadius,
      padding: padding,
      blurSigma: blurSigma,
      bgOpacity: bgOpacity,
      onTap: onTap,
      isFeatured: isFeatured,
      customBg: customBg,
      customBorder: customBorder,
      child: child,
    );
  }
}

/// Interactive Glass Button with custom accent color, icon, and hover feedback.
class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppColors colors;
  final Color? accentColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.label,
    required this.colors,
    this.icon,
    this.accentColor,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = accentColor ?? colors.accentCyan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: effectiveColor.withValues(alpha: 0.1),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: effectiveColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Latency badge showing ping roundtrip time with color-coded status.
class LatencyBadge extends StatelessWidget {
  final int latencyMs;
  final AppColors colors;

  const LatencyBadge({
    super.key,
    required this.latencyMs,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = colors.accentEmerald;
    if (latencyMs > 80) {
      badgeColor = colors.accentRose;
    } else if (latencyMs > 25) {
      badgeColor = colors.accentAmber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${latencyMs}ms',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill indicating online / offline status.
class StatusPill extends StatelessWidget {
  final String label;
  final Color dotColor;
  final Color? backgroundColor;

  const StatusPill({
    super.key,
    required this.label,
    required this.dotColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? dotColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}
