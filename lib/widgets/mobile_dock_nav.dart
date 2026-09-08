import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

/// Floating bottom navigation dock for narrow/mobile-width windows — the
/// Flutter port of the "iOS 26 Floating Dock" `.mobile-bottom-nav` block
/// added to UI_DESIGN_Sample.html. [DashboardShell] swaps to this instead
/// of [SlidingPillTabBar] below the ~768px breakpoint, matching the
/// `@media (max-width: 768px)` rule that hides the header's tab row and
/// shows this dock in its place.
class MobileDockNav extends StatelessWidget {
  const MobileDockNav({
    super.key,
    required this.colors,
    required this.currentIndex,
    required this.tabs,
    required this.icons,
    required this.onTabSelected,
  });

  final AppColors colors;
  final int currentIndex;
  final List<String> tabs;
  final List<IconData> icons;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: GlassContainer(
        colors: colors,
        blurSigma: 40,
        borderRadius: 100,
        backgroundColor: colors.headerBg,
        borderColor: colors.headerBorder,
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 52,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / tabs.length;
              return Stack(
                children: [
                  // Sliding Magnetic Pill Indicator (mirrors
                  // updateMobileNavIndicator() + .mobile-nav-pill-indicator).
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: slotWidth * currentIndex,
                    top: 0,
                    bottom: 0,
                    width: slotWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.accentColor, colors.accentCyan],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primaryGlow.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(tabs.length, (index) {
                      final isSelected = index == currentIndex;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () => onTabSelected(index),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : colors.textSecondary,
                                fontSize: 9.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutBack,
                                    scale: isSelected ? 1.15 : 1.0,
                                    child: Icon(
                                      icons[index],
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tabs[index],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
