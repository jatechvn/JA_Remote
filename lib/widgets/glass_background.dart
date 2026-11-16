part of 'glass_widgets.dart';

class MeshOrb extends StatefulWidget {
  const MeshOrb({
    super.key,
    required this.color,
    required this.size,
    required this.duration,
    required this.travel,
  });

  final Color color;
  final double size;
  final Duration duration;
  final Offset travel;

  @override
  State<MeshOrb> createState() => _MeshOrbState();
}

class _MeshOrbState extends State<MeshOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    // Pauses the drift while the window is unfocused, minimized/hidden, or in
    // 12s Idle Sleep Mode via AppPowerManager (0% background GPU/CPU).
    if (AppPowerManager.instance.shouldAnimateBackground) {
      _resumeAnimation();
    }
    AppPowerManager.instance.backgroundAnimationNotifier.addListener(
      _onPowerChanged,
    );
  }

  void _onPowerChanged() {
    if (!mounted) return;
    if (AppPowerManager.instance.shouldAnimateBackground) {
      if (!_controller.isAnimating) {
        _resumeAnimation();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  void _resumeAnimation() {
    final bool reverseFirst = _controller.status == AnimationStatus.reverse;
    if (reverseFirst) {
      _controller.reverse().then((_) {
        if (mounted && AppPowerManager.instance.shouldAnimateBackground) {
          _controller.repeat(reverse: true);
        }
      });
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    AppPowerManager.instance.backgroundAnimationNotifier.removeListener(
      _onPowerChanged,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary gives this continuously-drifting orb its own
    // compositor layer, so the 85px blur isn't recomputed as part of
    // whatever sits above it in the tree. Mirrors `will-change: transform`
    // + `translate3d(0,0,0)` on `.orb` in UI_DESIGN_Sample.html.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(_controller.value);
          return Transform.translate(
            offset: Offset(widget.travel.dx * t, widget.travel.dy * t),
            child: child,
          );
        },
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient mesh background: 3 drifting [MeshOrb]s behind the app content.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -160,
          left: -160,
          child: MeshOrb(
            color: colors.orb1.withValues(alpha: colors.orbOpacity),
            size: 480,
            duration: const Duration(seconds: 16),
            travel: const Offset(60, 70),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -120,
          child: MeshOrb(
            color: colors.orb2.withValues(alpha: colors.orbOpacity),
            size: 440,
            duration: const Duration(seconds: 18),
            travel: const Offset(-60, -60),
          ),
        ),
        Positioned(
          top: 180,
          right: 120,
          child: MeshOrb(
            color: colors.orb3.withValues(alpha: colors.orbOpacity),
            size: 340,
            duration: const Duration(seconds: 20),
            travel: const Offset(-40, 45),
          ),
        ),
      ],
    );
  }
}
