part of 'glass_widgets.dart';

class BorderBeam extends StatefulWidget {
  const BorderBeam({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.colors = const [
      Color(0xFF00D2FF),
      Color(0xFF0066FF),
      Color(0xFFA855F7),
    ],
    this.strokeWidth = 1.5,
    this.duration = const Duration(seconds: 5),
  });

  final Widget child;
  final double borderRadius;
  final List<Color> colors;
  final double strokeWidth;
  final Duration duration;

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Stops the gradient sweep while the window is minimized/hidden,
    // mirroring the Page Visibility low-power sleep mode added to
    // UI_DESIGN_Sample.html (0% background CPU when document.hidden).
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            _controller.stop();
          case AppLifecycleState.resumed:
            _controller.repeat();
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
    // Same isolation as MeshOrb: this beam repaints every frame while it's
    // visible, so give it its own layer instead of dragging the card
    // content along for each repaint.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _BorderBeamPainter(
              progress: _controller.value,
              borderRadius: widget.borderRadius,
              colors: widget.colors,
              strokeWidth: widget.strokeWidth,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  _BorderBeamPainter({
    required this.progress,
    required this.borderRadius,
    required this.colors,
    required this.strokeWidth,
  });

  final double progress;
  final double borderRadius;
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final gradient = SweepGradient(
      colors: [...colors, colors.first],
      stops: List.generate(colors.length + 1, (i) => i / colors.length),
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Mouse-follow spotlight glow — wrap a card's child to add a soft radial
/// highlight that tracks the cursor on hover.
class SpotlightGlow extends StatefulWidget {
  const SpotlightGlow({
    super.key,
    required this.colors,
    required this.child,
    this.borderRadius = 20,
    this.glowColor,
  });

  final AppColors colors;
  final Widget child;
  final double borderRadius;
  final Color? glowColor;

  @override
  State<SpotlightGlow> createState() => _SpotlightGlowState();
}

class _SpotlightGlowState extends State<SpotlightGlow> {
  // ValueNotifier instead of setState: mouse-move on Windows can fire far
  // more often than the frame rate, and setState would rebuild `child`
  // on every single event. Scoping the rebuild to a ValueListenableBuilder
  // around just the glow overlay is the Flutter equivalent of the
  // rAF-pending-flag throttle UI_DESIGN_Sample.html uses for its cursor
  // spotlight (`handleCardMouseMoveThrottled` / `_rafPending`).
  final ValueNotifier<Offset?> _localPosition = ValueNotifier(null);

  @override
  void dispose() {
    _localPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? widget.colors.accentColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return MouseRegion(
            onHover: (event) => _localPosition.value = event.localPosition,
            onExit: (_) => _localPosition.value = null,
            child: Stack(
              children: [
                widget.child,
                if (w > 0 && h > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<Offset?>(
                          valueListenable: _localPosition,
                          builder: (context, position, _) {
                            if (position == null) {
                              return const SizedBox.shrink();
                            }
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(
                                    (position.dx / w) * 2 - 1,
                                    (position.dy / h) * 2 - 1,
                                  ),
                                  radius: 0.9,
                                  colors: [
                                    glow.withValues(alpha: 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
