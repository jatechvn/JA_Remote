import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import '../core/utils/app_storage.dart';

/// Custom [WidgetsFlutterBinding] that gates frame scheduling (`vsync`) when
/// the application window is hidden, minimized, or unfocused.
///
/// Dart timers, I/O, and background isolates continue normally while frame
/// rendering is paused.
class PowerAwareWidgetsFlutterBinding extends WidgetsFlutterBinding {
  bool _wasRenderingActive = true;

  @override
  void initInstances() {
    super.initInstances();
    AppPowerManager.instance.indicatorsAnimationNotifier.addListener(
      _onRenderingActiveChanged,
    );
  }

  void _onRenderingActiveChanged() {
    final isActive = AppPowerManager.instance.isRenderingActive;
    final transitionedToActive = !_wasRenderingActive && isActive;
    _wasRenderingActive = isActive;
    if (transitionedToActive && super.framesEnabled) {
      scheduleFrame();
    }
  }

  @override
  bool get framesEnabled =>
      super.framesEnabled && AppPowerManager.instance.isRenderingActive;

  /// Initializes [PowerAwareWidgetsFlutterBinding] if no binding has been
  /// initialized yet; otherwise returns the existing [WidgetsBinding]
  /// (e.g. inside `flutter test`).
  static WidgetsBinding ensureInitialized() {
    try {
      // Check if a binding is already initialized (such as TestWidgetsFlutterBinding)
      return WidgetsBinding.instance;
    } catch (_) {
      PowerAwareWidgetsFlutterBinding();
      return WidgetsBinding.instance;
    }
  }
}

/// Centralized 4-Tier Power & Animation Coordinator for JA Remote Desktop.
///
/// Tier 1 (Active): Focused + Visible + User Active -> All animations ON
/// Tier 2 (Idle Sleep): Focused + Visible + User Idle (>= timeout) ->
///   Heavy decorative shaders/orbs & marquee OFF; lightweight status indicators ON
/// Tier 3 (Unfocused): Unfocused + Visible -> All animations & TickerMode OFF
/// Tier 4 (Hidden/Minimized): Invisible -> All animations & frame scheduling OFF
class AppPowerManager extends ChangeNotifier {
  static final AppPowerManager instance = AppPowerManager._();

  AppPowerManager._() {
    _resetIdleTimer();
  }

  static const String _settingsFileName = 'power_settings.json';

  bool _isWindowFocused = true;
  bool _isWindowVisible = true;
  bool _isUserIdle = false;

  bool _enableIdleSleep = true;
  int _idleTimeoutSeconds = 12;

  Timer? _idleTimer;
  bool _allowIdleTimerInTests = false;
  DateTime _lastInteractionResetTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _syncGeneration = 0;

  bool get isWindowFocused => _isWindowFocused;
  bool get isWindowVisible => _isWindowVisible;
  bool get isUserIdle => _isUserIdle;
  bool get enableIdleSleep => _enableIdleSleep;
  int get idleTimeoutSeconds => _idleTimeoutSeconds;

  /// True when the window is both visible and focused.
  bool get isRenderingActive => _isWindowFocused && _isWindowVisible;

  /// Heavy decorative animations (e.g., MeshOrb background shaders).
  /// Pauses on blur, minimize/hide, OR user idle sleep.
  bool get shouldAnimateBackground =>
      _isWindowFocused &&
      _isWindowVisible &&
      (!_enableIdleSleep || !_isUserIdle);

  /// Lightweight status indicators (WaveIndicator, BorderBeam, TickerMode).
  /// Stays active during Idle Sleep so live status remains visible,
  /// but pauses immediately when unfocused or minimized.
  bool get shouldAnimateIndicators => _isWindowFocused && _isWindowVisible;

  /// Marquee text auto-scrolling.
  /// Pauses on blur, minimize/hide, OR user idle sleep.
  bool get shouldAnimateMarquee =>
      _isWindowFocused &&
      _isWindowVisible &&
      (!_enableIdleSleep || !_isUserIdle);

  final ValueNotifier<bool> backgroundAnimationNotifier = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> indicatorsAnimationNotifier = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> marqueeAnimationNotifier = ValueNotifier<bool>(
    true,
  );

  /// Loads persisted power settings from `power_settings.json`.
  Future<void> loadSettings() async {
    try {
      final file = await AppStorage.getFile(_settingsFileName);
      if (await file.exists()) {
        final raw = await file.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final enabled = map['enableIdleSleep'];
        final timeout = map['idleTimeoutSeconds'];
        if (enabled is bool) {
          _enableIdleSleep = enabled;
        }
        if (timeout is int) {
          _idleTimeoutSeconds = timeout.clamp(5, 300);
        }
        if (!_enableIdleSleep) {
          _isUserIdle = false;
          _idleTimer?.cancel();
        } else {
          _resetIdleTimer();
        }
        _updateNotifiers();
      }
    } catch (e) {
      debugPrint('Failed to load power settings: $e');
    }
  }

  /// Persists current power settings to `power_settings.json`.
  Future<void> saveSettings() async {
    try {
      final file = await AppStorage.getFile(_settingsFileName);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'enableIdleSleep': _enableIdleSleep,
          'idleTimeoutSeconds': _idleTimeoutSeconds,
        }),
      );
    } catch (e) {
      debugPrint('Failed to save power settings: $e');
    }
  }

  void setWindowFocused(bool focused) {
    if (_isWindowFocused == focused) return;
    _isWindowFocused = focused;
    if (focused) {
      _wakeUpFromIdle();
    } else {
      _idleTimer?.cancel();
    }
    _updateNotifiers();
  }

  /// Sets window visibility. Note: restoring visibility alone does NOT force
  /// `_isWindowFocused = true` (Unfocused Restore Guard).
  void setWindowVisible(bool visible) {
    if (_isWindowVisible == visible) return;
    _isWindowVisible = visible;
    if (visible && _isWindowFocused) {
      _wakeUpFromIdle();
    } else if (!visible) {
      _idleTimer?.cancel();
    }
    _updateNotifiers();
  }

  void setEnableIdleSleep(bool enable, {bool persist = true}) {
    if (_enableIdleSleep == enable) return;
    _enableIdleSleep = enable;
    if (!enable) {
      _isUserIdle = false;
      _idleTimer?.cancel();
    } else {
      _wakeUpFromIdle();
    }
    _updateNotifiers();
    if (persist) {
      unawaited(saveSettings());
    }
  }

  void setIdleTimeoutSeconds(int seconds, {bool persist = true}) {
    final clamped = seconds.clamp(5, 300);
    if (_idleTimeoutSeconds == clamped) return;
    _idleTimeoutSeconds = clamped;
    if (_enableIdleSleep) {
      _wakeUpFromIdle();
    }
    _updateNotifiers();
    if (persist) {
      unawaited(saveSettings());
    }
  }

  /// Called by global pointer/keyboard listeners.
  /// Throttled to at most once per 600ms while active to avoid timer churn on
  /// high-polling-rate gaming mice.
  void recordUserInteraction() {
    if (!_enableIdleSleep || !_isWindowFocused || !_isWindowVisible) return;

    final now = DateTime.now();
    if (!_isUserIdle &&
        now.difference(_lastInteractionResetTime).inMilliseconds < 600) {
      return;
    }
    _lastInteractionResetTime = now;

    if (_isUserIdle) {
      _isUserIdle = false;
      _updateNotifiers();
    }
    _resetIdleTimer();
  }

  /// Queries `window_manager` for ground-truth native window visibility,
  /// minimization, and focus state. Guards against stale async completions.
  Future<void> syncNativeWindowState() async {
    final int gen = ++_syncGeneration;
    try {
      final results = await Future.wait<bool>([
        windowManager.isVisible(),
        windowManager.isMinimized(),
        windowManager.isFocused(),
      ]);
      if (gen != _syncGeneration) return;

      final bool visible = results[0] && !results[1];
      final bool focused = visible && results[2];

      final bool changed =
          (_isWindowVisible != visible) || (_isWindowFocused != focused);
      _isWindowVisible = visible;
      _isWindowFocused = focused;

      if (_isWindowVisible && _isWindowFocused) {
        _wakeUpFromIdle();
      } else {
        _idleTimer?.cancel();
      }

      if (changed) {
        _updateNotifiers();
      }
    } catch (_) {
      // Ignore in headless/unit-test environments where window_manager is absent
    }
  }

  void _wakeUpFromIdle() {
    _isUserIdle = false;
    _lastInteractionResetTime = DateTime.now();
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_enableIdleSleep || !_isWindowFocused || !_isWindowVisible) return;
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        !_allowIdleTimerInTests) {
      return;
    }

    _idleTimer = Timer(Duration(seconds: _idleTimeoutSeconds), () {
      if (_isWindowFocused && _isWindowVisible && _enableIdleSleep) {
        _isUserIdle = true;
        _updateNotifiers();
      }
    });
  }

  void _updateNotifiers() {
    bool changed = false;
    if (backgroundAnimationNotifier.value != shouldAnimateBackground) {
      backgroundAnimationNotifier.value = shouldAnimateBackground;
      changed = true;
    }
    if (indicatorsAnimationNotifier.value != shouldAnimateIndicators) {
      indicatorsAnimationNotifier.value = shouldAnimateIndicators;
      changed = true;
    }
    if (marqueeAnimationNotifier.value != shouldAnimateMarquee) {
      marqueeAnimationNotifier.value = shouldAnimateMarquee;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Resets internal state for unit tests.
  @visibleForTesting
  void resetForTesting({
    bool focused = true,
    bool visible = true,
    bool enableIdleSleep = true,
    int idleTimeoutSeconds = 12,
    bool allowIdleTimerInTests = false,
  }) {
    _syncGeneration++;
    _idleTimer?.cancel();
    _allowIdleTimerInTests = allowIdleTimerInTests;
    _isWindowFocused = focused;
    _isWindowVisible = visible;
    _isUserIdle = false;
    _enableIdleSleep = enableIdleSleep;
    _idleTimeoutSeconds = idleTimeoutSeconds;
    _lastInteractionResetTime = DateTime.fromMillisecondsSinceEpoch(0);
    backgroundAnimationNotifier.value = shouldAnimateBackground;
    indicatorsAnimationNotifier.value = shouldAnimateIndicators;
    marqueeAnimationNotifier.value = shouldAnimateMarquee;
    if (_enableIdleSleep && _isWindowFocused && _isWindowVisible) {
      _resetIdleTimer();
    }
    notifyListeners();
  }
}
