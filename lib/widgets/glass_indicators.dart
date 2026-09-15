part of 'glass_widgets.dart';

class WaveIndicator extends StatefulWidget {
  final Color color;
  final double height;
  const WaveIndicator({super.key, required this.color, this.height = 14});

  @override
  State<WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<WaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Stops the equalizer bars while the window is minimized/hidden,
    // mirroring the Page Visibility low-power sleep mode added to
    // UI_DESIGN_Sample.html (0% background CPU when document.hidden).
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            _controller.stop();
          case AppLifecycleState.resumed:
            _controller.repeat(reverse: true);
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final h1 = (widget.height * (0.3 + 0.7 * val)).clamp(
          3.0,
          widget.height,
        );
        final h2 = (widget.height * (0.9 - 0.6 * val)).clamp(
          3.0,
          widget.height,
        );
        final h3 = (widget.height * (0.4 + 0.5 * (1 - val))).clamp(
          3.0,
          widget.height,
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1),
            const SizedBox(width: 2),
            _buildBar(h2),
            const SizedBox(width: 2),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Dynamic Island Status Capsule for the top header with Asymmetric Marquee text.
class DynamicIslandCapsule extends StatelessWidget {
  final AppColors colors;
  final bool isRunning;
  final String statusText;
  final String? subText;
  final VoidCallback? onTap;
  final Color? customColor;

  const DynamicIslandCapsule({
    super.key,
    required this.colors,
    required this.isRunning,
    required this.statusText,
    this.subText,
    this.onTap,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = customColor ?? colors.accentEmerald;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          decoration: BoxDecoration(
            color: colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isRunning
                  ? activeColor.withValues(alpha: 0.45)
                  : colors.subCardBorder,
            ),
            boxShadow: [
              if (isRunning)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRunning) ...[
                WaveIndicator(color: activeColor, height: 12),
                const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                    boxShadow: [BoxShadow(color: activeColor, blurRadius: 6)],
                  ),
                ),
              ] else ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 85),
                child: AsymmetricMarqueeText(
                  text: statusText,
                  style: TextStyle(
                    color: isRunning ? activeColor : colors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                    letterSpacing: 0.35,
                  ),
                ),
              ),
              if (subText != null && subText!.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(maxWidth: 90),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.subCardBorder.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AsymmetricMarqueeText(
                    text: subText!,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Intelligent Adaptive Sliding Magnetic Pill Tab Bar with Mirror Glass Specular Hover Effect.
/// - When window is wide / maximized: displays all tabs with full icons and labels.
/// Intelligent Adaptive Sliding Magnetic Pill Tab Bar.
/// - Responsive Space Adaptation:
///   * Wide / Spacious: displays full icons and labels for all tabs.
///   * Medium / Standard: intelligently switches to sleek Text-Only mode to fit all tabs (e.g. Vietnamese titles) without hiding or cutting off.
///   * Compact / Narrow: collapses unselected tabs to icons (accordion mode) with smooth hover expand preview.
/// - Tactile Bounce Hint Nudge: mirrors sample_components_motion elastic bounce on load, overflow, or language change so users instantly know more tabs exist.
/// - Windows Desktop Mouse-Wheel Scrolling: seamless horizontal scrolling with mouse wheel.
/// - Glass Navigation Chevrons: subtle interactive glowing arrow buttons that appear when scrolled/overflowed.
/// - Active Tab Auto-Scroll: automatically ensures the selected tab glides into view.
class SlidingPillTabBar extends StatefulWidget {
  final AppColors colors;
  final int currentIndex;
  final List<String> tabs;
  final List<IconData> icons;
  final ValueChanged<int> onTabSelected;
  final bool adaptiveCollapse;
  final bool enableBounceHint;
  final bool enableChevrons;

  const SlidingPillTabBar({
    super.key,
    required this.colors,
    required this.currentIndex,
    required this.tabs,
    required this.icons,
    required this.onTabSelected,
    this.adaptiveCollapse = true,
    this.enableBounceHint = true,
    this.enableChevrons = true,
  });

  @override
  State<SlidingPillTabBar> createState() => _SlidingPillTabBarState();
}

class _SlidingPillTabBarState extends State<SlidingPillTabBar> {
  int? _hoveredIndex;
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _tabKeys;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _hasTriggeredInitialBounce = false;
  Timer? _bounceTimer;

  @override
  void initState() {
    super.initState();
    _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollIndicators();
      _scrollToIndex(widget.currentIndex, animate: false);
      if (widget.enableBounceHint) {
        _checkAndTriggerBounce();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SlidingPillTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(widget.currentIndex);
      });
    }
    // Re-trigger bounce hint if tab titles changed (e.g. switching between EN and VI)
    if (oldWidget.tabs.join('|') != widget.tabs.join('|')) {
      _hasTriggeredInitialBounce = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateScrollIndicators();
        if (widget.enableBounceHint) {
          _checkAndTriggerBounce();
        }
      });
    }
  }

  @override
  void dispose() {
    _bounceTimer?.cancel();
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 4.0;
    final canRight = offset < maxScroll - 4.0;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (index < 0 || index >= _tabKeys.length) return;
    final keyContext = _tabKeys[index].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  void _checkAndTriggerBounce() {
    if (_hasTriggeredInitialBounce) return;
    _bounceTimer?.cancel();
    _bounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 6.0) {
        _hasTriggeredInitialBounce = true;
        _triggerBounceHint();
      }
    });
  }

  /// Tactile Bounce Top / Right Nudge hint animation (mirrors sample_components_motion pattern)
  void _triggerBounceHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final startOffset = _scrollController.offset;
    final peekOffset = math.min(startOffset + 38.0, maxScroll);
    if (peekOffset <= startOffset) return;

    _scrollController
        .animateTo(
          peekOffset,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            startOffset,
            duration: const Duration(milliseconds: 480),
            curve: Curves.elasticOut,
          );
        });
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildNavArrow({required bool isLeft}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => _scrollBy(isLeft ? -130.0 : 130.0),
        child: Container(
          width: 22,
          height: 26,
          decoration: BoxDecoration(
            color: widget.colors.accentColor.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.colors.accentColor.withValues(alpha: 0.50),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.accentColor.withValues(alpha: 0.18),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 15,
            color: widget.colors.accentColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final tabCount = widget.tabs.length;

        // Smart space calculations:
        // Full width (Icon + Text): ~105px per tab + container padding
        final fullWidthNeeded = tabCount * 105.0 + 16.0;
        // Text-only width (No icon): ~76px per tab + container padding
        final textOnlyWidthNeeded = tabCount * 76.0 + 16.0;

        final bool canFitFull = availableWidth >= fullWidthNeeded;
        final bool canFitTextOnly = availableWidth >= textOnlyWidthNeeded;

        // When space is medium: omit icons so all tab labels fit without cutting off.
        // When space is narrow: unselected tabs collapse to icons (accordion dock).
        final bool showIcon =
            canFitFull || (!canFitTextOnly && widget.adaptiveCollapse);
        final bool shouldCollapse =
            widget.adaptiveCollapse && !canFitFull && !canFitTextOnly;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateScrollIndicators();
            if (widget.enableBounceHint) {
              _checkAndTriggerBounce();
            }
          }
        });

        return Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: widget.colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: widget.colors.subCardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent &&
                      _scrollController.hasClients) {
                    final double delta = pointerSignal.scrollDelta.dy != 0
                        ? pointerSignal.scrollDelta.dy
                        : pointerSignal.scrollDelta.dx;
                    final newOffset = (_scrollController.offset + delta).clamp(
                      0.0,
                      _scrollController.position.maxScrollExtent,
                    );
                    _scrollController.jumpTo(newOffset);
                  }
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.tabs.length, (index) {
                      final isSelected = widget.currentIndex == index;
                      final isHovered = _hoveredIndex == index;
                      final showLabel =
                          isSelected || isHovered || !shouldCollapse;

                      // Specular Mirror Glass Hover & Selected Gradient Decoration
                      final decoration = isSelected
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.colors.accentColor,
                                  widget.colors.accentCyan.withValues(
                                    alpha: 0.88,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.colors.primaryGlow.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            )
                          : (isHovered
                                ? BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: const Alignment(-0.8, -1.0),
                                      end: const Alignment(0.8, 1.0),
                                      colors: [
                                        widget.colors.glassHighlight.withValues(
                                          alpha: 0.32,
                                        ),
                                        widget.colors.cardHoverBg.withValues(
                                          alpha: 0.65,
                                        ),
                                        widget.colors.glassHighlight.withValues(
                                          alpha: 0.08,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: widget.colors.accentColor
                                          .withValues(alpha: 0.45),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.colors.accentColor
                                            .withValues(alpha: 0.16),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                      BoxShadow(
                                        color: widget.colors.glassHighlight
                                            .withValues(alpha: 0.30),
                                        blurRadius: 4,
                                        offset: const Offset(0, -1),
                                      ),
                                    ],
                                  )
                                : const BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(100),
                                    ),
                                  ));

                      // Specular Mirror Top Reflection Line
                      final foregroundDeco = isSelected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                            )
                          : (isHovered
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border(
                                      top: BorderSide(
                                        color: widget.colors.glassHighlight
                                            .withValues(alpha: 0.95),
                                        width: 1.2,
                                      ),
                                    ),
                                  )
                                : null);

                      return MouseRegion(
                        key: _tabKeys[index],
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: Tooltip(
                          message: widget.tabs[index],
                          waitDuration: const Duration(milliseconds: 600),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _scrollToIndex(index);
                              widget.onTabSelected(index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(
                                horizontal: showLabel ? 10 : 8,
                                vertical: 5,
                              ),
                              decoration: decoration,
                              foregroundDecoration: foregroundDeco,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showIcon) ...[
                                    Icon(
                                      widget.icons[index],
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : (isHovered
                                                ? widget.colors.textPrimary
                                                : widget.colors.textSecondary),
                                    ),
                                    if (showLabel) const SizedBox(width: 5),
                                  ],
                                  if (showLabel) ...[
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: canFitFull ? 130 : 105,
                                      ),
                                      child: isSelected
                                          ? AsymmetricMarqueeText(
                                              text: widget.tabs[index],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            )
                                          : Text(
                                              widget.tabs[index],
                                              style: TextStyle(
                                                color: isHovered
                                                    ? widget.colors.textPrimary
                                                    : widget
                                                          .colors
                                                          .textSecondary,
                                                fontSize: 12,
                                                fontWeight: isHovered
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Left fade gradient and navigation chevron
              if (_canScrollLeft) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(100),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            widget.colors.subCardBg,
                            widget.colors.subCardBg.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.enableChevrons)
                  Positioned(left: 2, child: _buildNavArrow(isLeft: true)),
              ],
              // Right fade gradient and navigation chevron
              if (_canScrollRight) ...[
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(100),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            widget.colors.subCardBg,
                            widget.colors.subCardBg.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.enableChevrons)
                  Positioned(right: 2, child: _buildNavArrow(isLeft: false)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Asymmetric Bouncing Marquee Text widget:
/// - Cuộn CHẬM tuyến tính tới cuối chuỗi (Curves.linear, duration = text.length * 60ms).
/// - Dừng 1500ms ở cuối chuỗi.
/// - BẬT NẢY NHANH về đầu chuỗi (Curves.easeOut, cố định 800ms).
/// - Dừng 1500ms ở đầu chuỗi trước khi lặp lại.
/// - 0% CPU khi chữ vừa vặn khung (maxScrollExtent <= 0).

/// Seamless Glassmorphic Horizontal Scroll View with:
/// - Windows Desktop Mouse-Wheel Scrolling: effortlessly scrolls horizontally when mouse wheel rolls (dy/dx) anywhere over the container.
/// - Tactile Smart Bounce Hint: elastic bounce nudge on initial display/overflow to notify user that more content exists off-screen.
/// - BouncingScrollPhysics: natural elastic physics on drag or boundary scroll.
/// - Ambient Glass Navigation Chevrons & Edge Fades: subtle glowing arrows appear when scrolled/overflowed for 1-click gliding.
class GlassHorizontalScrollView extends StatefulWidget {
  final Widget child;
  final AppColors colors;
  final bool enableBounceHint;
  final bool enableChevrons;
  final double scrollStep;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  const GlassHorizontalScrollView({
    super.key,
    required this.child,
    required this.colors,
    this.enableBounceHint = true,
    this.enableChevrons = true,
    this.scrollStep = 160.0,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  @override
  State<GlassHorizontalScrollView> createState() =>
      _GlassHorizontalScrollViewState();
}

class _GlassHorizontalScrollViewState extends State<GlassHorizontalScrollView> {
  late ScrollController _scrollController;
  bool _ownsController = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _hasTriggeredBounce = false;
  Timer? _bounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollIndicators();
      if (widget.enableBounceHint) {
        _checkAndTriggerBounce();
      }
    });
  }

  @override
  void didUpdateWidget(covariant GlassHorizontalScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _scrollController.removeListener(_updateScrollIndicators);
      if (_ownsController) {
        _scrollController.dispose();
      }
      if (widget.controller != null) {
        _scrollController = widget.controller!;
        _ownsController = false;
      } else {
        _scrollController = ScrollController();
        _ownsController = true;
      }
      _scrollController.addListener(_updateScrollIndicators);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollIndicators();
      if (widget.enableBounceHint && !_hasTriggeredBounce) {
        _checkAndTriggerBounce();
      }
    });
  }

  @override
  void dispose() {
    _bounceTimer?.cancel();
    _scrollController.removeListener(_updateScrollIndicators);
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 4.0;
    final canRight = offset < maxScroll - 4.0;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _checkAndTriggerBounce() {
    if (_hasTriggeredBounce) return;
    _bounceTimer?.cancel();
    _bounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 6.0) {
        _hasTriggeredBounce = true;
        _triggerBounceHint();
      }
    });
  }

  /// Tactile Bounce Nudge hint animation (mirrors sample_components_motion pattern)
  void _triggerBounceHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 4.0) return;

    final startOffset = _scrollController.offset;
    final peekOffset = math.min(startOffset + 48.0, maxScroll);
    if (peekOffset <= startOffset) return;

    _scrollController
        .animateTo(
          peekOffset,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            startOffset,
            duration: const Duration(milliseconds: 480),
            curve: Curves.elasticOut,
          );
        });
  }

  Widget _buildChevron({required bool isLeft}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () {
          if (!_scrollController.hasClients) return;
          final delta = isLeft ? -widget.scrollStep : widget.scrollStep;
          final target = (_scrollController.offset + delta).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 20,
          height: 24,
          decoration: BoxDecoration(
            color: widget.colors.accentCyan.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.colors.accentCyan.withValues(alpha: 0.55),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.accentCyan.withValues(alpha: 0.20),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 14,
            color: widget.colors.accentCyan,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent &&
                _scrollController.hasClients) {
              final double delta = pointerSignal.scrollDelta.dy != 0
                  ? pointerSignal.scrollDelta.dy
                  : pointerSignal.scrollDelta.dx;
              final target = (_scrollController.offset + delta).clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              );
              _scrollController.jumpTo(target);
            }
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        ),
        // Left fade gradient and navigation chevron
        if (_canScrollLeft) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      widget.colors.cardBg,
                      widget.colors.cardBg.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.enableChevrons)
            Positioned(left: 2, child: _buildChevron(isLeft: true)),
        ],
        // Right fade gradient and navigation chevron
        if (_canScrollRight) ...[
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      widget.colors.cardBg,
                      widget.colors.cardBg.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.enableChevrons)
            Positioned(right: 2, child: _buildChevron(isLeft: false)),
        ],
      ],
    );
  }
}
