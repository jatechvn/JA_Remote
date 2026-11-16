part of 'glass_widgets.dart';

/// Asymmetric Ping-Pong Marquee Text widget:
/// - Only scrolls if text overflows the container constraints.
/// - Hold at start for [pauseStart] (e.g. 1400ms).
/// - Smoothly scrolls forward to the end with [forwardCurve].
/// - Hold at end for [pauseEnd] (e.g. 1400ms).
/// - Smoothly scrolls back to start with [returnCurve].
/// - Zero performance overhead when text fits within bounds.
/// - Session Epoch Guard & AppPowerManager integration to prevent ghost timer
///   callbacks and freeze scroll position when paused/idle.
class AsymmetricMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseStart;
  final Duration pauseEnd;
  final double velocity; // px/sec
  final Curve forwardCurve;
  final Curve returnCurve;

  const AsymmetricMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseStart = const Duration(milliseconds: 1400),
    this.pauseEnd = const Duration(milliseconds: 1400),
    this.velocity = 35.0,
    this.forwardCurve = Curves.easeInOutCubic,
    this.returnCurve = Curves.easeInOutCubic,
  });

  @override
  State<AsymmetricMarqueeText> createState() => _AsymmetricMarqueeTextState();
}

class _AsymmetricMarqueeTextState extends State<AsymmetricMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isDisposed = false;
  bool _isPaused = false;
  int _sessionEpoch = 0;

  @override
  void initState() {
    super.initState();
    _isPaused = !AppPowerManager.instance.shouldAnimateMarquee;
    AppPowerManager.instance.marqueeAnimationNotifier.addListener(
      _onPowerChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted && !_isPaused) {
        _scheduleStart(++_sessionEpoch);
      }
    });
  }

  void _onPowerChanged() {
    if (_isDisposed || !mounted) return;
    final shouldRun = AppPowerManager.instance.shouldAnimateMarquee;
    if (shouldRun && _isPaused) {
      _isPaused = false;
      _scheduleStart(++_sessionEpoch);
    } else if (!shouldRun && !_isPaused) {
      _isPaused = true;
      _sessionEpoch++;
      _timer?.cancel();
      if (_scrollController.hasClients) {
        final currentOffset = _scrollController.offset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(currentOffset);
      }
    }
  }

  @override
  void didUpdateWidget(covariant AsymmetricMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _sessionEpoch++;
      _timer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted && !_isPaused) {
          _scheduleStart(++_sessionEpoch);
        }
      });
    }
  }

  void _scheduleStart(int epoch) {
    _timer?.cancel();
    if (_isDisposed || !mounted || _isPaused || epoch != _sessionEpoch) return;
    if (!_scrollController.hasClients) {
      _timer = Timer(const Duration(milliseconds: 150), () {
        if (epoch == _sessionEpoch) _scheduleStart(epoch);
      });
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _timer = Timer(widget.pauseStart, () {
      if (epoch == _sessionEpoch) _animateForward(epoch);
    });
  }

  void _animateForward(int epoch) {
    _timer?.cancel();
    if (_isDisposed ||
        !mounted ||
        _isPaused ||
        epoch != _sessionEpoch ||
        !_scrollController.hasClients) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final remaining = (maxScroll - _scrollController.offset).clamp(
      0.0,
      maxScroll,
    );
    final duration = Duration(
      milliseconds: ((remaining / widget.velocity) * 1000)
          .round()
          .clamp(300, 6000)
          .toInt(),
    );

    _scrollController
        .animateTo(maxScroll, duration: duration, curve: widget.forwardCurve)
        .then((_) {
          if (_isDisposed || !mounted || _isPaused || epoch != _sessionEpoch) {
            return;
          }
          _timer = Timer(widget.pauseEnd, () {
            if (epoch == _sessionEpoch) _animateReturn(epoch);
          });
        });
  }

  void _animateReturn(int epoch) {
    _timer?.cancel();
    if (_isDisposed ||
        !mounted ||
        _isPaused ||
        epoch != _sessionEpoch ||
        !_scrollController.hasClients) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final duration = Duration(
      milliseconds: ((maxScroll / (widget.velocity * 1.25)) * 1000)
          .round()
          .clamp(300, 5000)
          .toInt(),
    );

    _scrollController
        .animateTo(0, duration: duration, curve: widget.returnCurve)
        .then((_) {
          if (_isDisposed || !mounted || _isPaused || epoch != _sessionEpoch) {
            return;
          }
          _timer = Timer(widget.pauseStart, () {
            if (epoch == _sessionEpoch) _animateForward(epoch);
          });
        });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionEpoch++;
    _timer?.cancel();
    AppPowerManager.instance.marqueeAnimationNotifier.removeListener(
      _onPowerChanged,
    );
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

typedef MarqueeText = AsymmetricMarqueeText;
typedef BounceMarqueeText = AsymmetricMarqueeText;
