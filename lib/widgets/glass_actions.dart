part of 'glass_widgets.dart';

class GlowingActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final AppColors colors;
  final double height;
  final Color? customStartColor;
  final Color? customEndColor;

  const GlowingActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    required this.colors,
    this.height = 42,
    this.customStartColor,
    this.customEndColor,
  });

  @override
  Widget build(BuildContext context) {
    final start =
        customStartColor ??
        (isDestructive ? const Color(0xFFF43F5E) : colors.accentColor);
    final end =
        customEndColor ??
        (isDestructive ? const Color(0xFFE11D48) : colors.accentCyan);

    final gradient = LinearGradient(
      colors: [start, end],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final glowColor = isDestructive
        ? const Color(0x66F43F5E)
        : (customStartColor != null
              ? customStartColor!.withValues(alpha: 0.35)
              : colors.primaryGlow);

    final isDisabled = onPressed == null;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(elevation: WidgetStateProperty.all(0)),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDisabled
                ? LinearGradient(colors: [colors.subCardBg, colors.subCardBg])
                : gradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? colors.subCardBorder
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isDisabled ? colors.textMuted : Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isDisabled ? colors.textMuted : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
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

/// Small keyboard-shortcut badge (e.g. "Ctrl+K", "ESC").
class KbdTag extends StatelessWidget {
  const KbdTag({super.key, required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 10,
          fontFamily: 'JetBrains Mono',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Animated gradient border sweep — wrap any child (typically a [BentoCard])
/// to add a rotating, glowing accent border marking it "live"/"featured"/
/// "selected".
