import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_colors.dart';
import 'styles_win10.dart';
import 'styles_win11.dart';

/// Performance Tier Mode for Graphic & Hardware Tuning.
enum PerfTierMode {
  auto('auto', 'Auto'),
  ultra('ultra', 'Ultra'),
  balanced('balanced', 'Balanced'),
  lite('lite', 'Lite');

  final String id;
  final String label;
  const PerfTierMode(this.id, this.label);
}

/// Effective Hardware Graphic Tier
enum HardwareTier {
  ultra('Ultra', '120 FPS • Max Glass', Icons.bolt_rounded, Color(0xFF0066FF)),
  balanced(
    'Balanced',
    '60 FPS • Laptop Opt',
    Icons.balance_rounded,
    Color(0xFF10B981),
  ),
  lite('Lite', 'Low Power • Zero Lag', Icons.eco_rounded, Color(0xFFF59E0B));

  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  const HardwareTier(this.label, this.desc, this.icon, this.color);
}

class ThemeProvider extends ChangeNotifier {
  static const _themeChannel = MethodChannel('ja_remote/theme');

  String _themeMode = 'system';
  bool _isWin11 = false;

  // Performance & Graphic Tier Profiling
  PerfTierMode _perfMode = PerfTierMode.auto;
  late HardwareTier _detectedTier;
  int _cpuCores = 4;
  int _hardwareScore = 50;

  // Glassmorphism live tuning parameters (Image 1 defaults)
  double _cardBlur = 20.0;
  double _cardOpacity = 0.25;
  double _dialogBlur = 20.0;
  double _dialogOpacity = 0.85;
  double _dropdownBlur = 20.0;
  double _dropdownOpacity = 0.95;

  ThemeProvider({String initialMode = 'system'}) {
    _themeMode = initialMode;
    _detectWindowsVersion();
    _profileHardware();
    _syncNativeTheme();
  }

  void _syncNativeTheme() {
    if (!Platform.isWindows) return;
    try {
      _themeChannel.invokeMethod<void>('setTheme', {'isDark': isDark});
    } catch (_) {}
  }

  void _detectWindowsVersion() {
    if (!Platform.isWindows) return;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        _isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }

  void _profileHardware() {
    try {
      _cpuCores = Platform.numberOfProcessors;
    } catch (_) {
      _cpuCores = 4;
    }

    int score = 50;
    if (_cpuCores >= 8) {
      score += 30;
    } else if (_cpuCores >= 4) {
      score += 10;
    } else {
      score -= 25;
    }

    if (_isWin11) score += 10;

    _hardwareScore = score.clamp(10, 100);
    if (_hardwareScore < 40) {
      _detectedTier = HardwareTier.lite;
    } else if (_hardwareScore < 70) {
      _detectedTier = HardwareTier.balanced;
    } else {
      _detectedTier = HardwareTier.ultra;
    }

    _applyTierParameters(effectiveTier, notify: false);
  }

  PerfTierMode get perfMode => _perfMode;
  HardwareTier get detectedTier => _detectedTier;
  HardwareTier get effectiveTier {
    switch (_perfMode) {
      case PerfTierMode.auto:
        return _detectedTier;
      case PerfTierMode.ultra:
        return HardwareTier.ultra;
      case PerfTierMode.balanced:
        return HardwareTier.balanced;
      case PerfTierMode.lite:
        return HardwareTier.lite;
    }
  }

  String get perfLabel {
    if (_perfMode == PerfTierMode.auto) {
      return 'Auto (${effectiveTier.label})';
    }
    return _perfMode.label;
  }

  int get cpuCores => _cpuCores;
  int get hardwareScore => _hardwareScore;

  /// Cycles through: auto -> ultra -> balanced -> lite -> auto
  void cyclePerfTier() {
    switch (_perfMode) {
      case PerfTierMode.auto:
        _perfMode = PerfTierMode.ultra;
        break;
      case PerfTierMode.ultra:
        _perfMode = PerfTierMode.balanced;
        break;
      case PerfTierMode.balanced:
        _perfMode = PerfTierMode.lite;
        break;
      case PerfTierMode.lite:
        _perfMode = PerfTierMode.auto;
        break;
    }
    _applyTierParameters(effectiveTier, notify: true);
  }

  void setPerfTierMode(PerfTierMode mode) {
    if (_perfMode != mode) {
      _perfMode = mode;
      _applyTierParameters(effectiveTier, notify: true);
    }
  }

  void _applyTierParameters(HardwareTier tier, {bool notify = true}) {
    switch (tier) {
      case HardwareTier.ultra:
        _cardBlur = 20.0;
        _cardOpacity = 0.25;
        _dialogBlur = 20.0;
        _dialogOpacity = 0.85;
        _dropdownBlur = 20.0;
        _dropdownOpacity = 0.94;
        break;
      case HardwareTier.balanced:
        _cardBlur = 14.0;
        _cardOpacity = 0.35;
        _dialogBlur = 16.0;
        _dialogOpacity = 0.92;
        _dropdownBlur = 14.0;
        _dropdownOpacity = 0.96;
        break;
      case HardwareTier.lite:
        _cardBlur = 0.0;
        _cardOpacity = 0.75;
        _dialogBlur = 8.0;
        _dialogOpacity = 0.95;
        _dropdownBlur = 0.0;
        _dropdownOpacity = 0.98;
        break;
    }
    if (notify) notifyListeners();
  }

  String get themeMode => _themeMode;

  bool get isDark {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'light') return false;
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  bool get isWin11 => _isWin11;

  double get cardBlur => _cardBlur;
  double get cardOpacity => _cardOpacity;
  double get dialogBlur => _dialogBlur;
  double get dialogOpacity => _dialogOpacity;
  double get dropdownBlur => _dropdownBlur;
  double get dropdownOpacity => _dropdownOpacity;

  AppColors get colors {
    if (isDark) {
      return _isWin11 ? win11DarkColors : win10DarkColors;
    } else {
      return _isWin11 ? win11LightColors : win10LightColors;
    }
  }

  /// 1-Click Direct Toggle between Light and Dark
  void toggleTheme() {
    _themeMode = isDark ? 'light' : 'dark';
    _syncNativeTheme();
    notifyListeners();
  }

  void setThemeMode(String mode) {
    _themeMode = mode;
    _syncNativeTheme();
    notifyListeners();
  }

  /// Real-time live tuning for Glassmorphism sliders
  void setLiveGlassmorphism({
    double? cardBlur,
    double? cardOpacity,
    double? dialogBlur,
    double? dialogOpacity,
    double? dropdownBlur,
    double? dropdownOpacity,
  }) {
    if (cardBlur != null) _cardBlur = cardBlur;
    if (cardOpacity != null) _cardOpacity = cardOpacity;
    if (dialogBlur != null) _dialogBlur = dialogBlur;
    if (dialogOpacity != null) _dialogOpacity = dialogOpacity;
    if (dropdownBlur != null) _dropdownBlur = dropdownBlur;
    if (dropdownOpacity != null) _dropdownOpacity = dropdownOpacity;
    notifyListeners();
  }

  void setCardBlur(double blur) {
    _cardBlur = blur;
    notifyListeners();
  }

  void setCardOpacity(double opacity) {
    _cardOpacity = opacity;
    notifyListeners();
  }

  void setDialogBlur(double blur) {
    _dialogBlur = blur;
    notifyListeners();
  }

  void setDialogOpacity(double opacity) {
    _dialogOpacity = opacity;
    notifyListeners();
  }

  void setDropdownBlur(double blur) {
    _dropdownBlur = blur;
    notifyListeners();
  }

  void setDropdownOpacity(double opacity) {
    _dropdownOpacity = opacity;
    notifyListeners();
  }

  void resetToDefaults() {
    _perfMode = PerfTierMode.auto;
    _cardBlur = 20.0;
    _cardOpacity = 0.25;
    _dialogBlur = 20.0;
    _dialogOpacity = 0.85;
    _dropdownBlur = 20.0;
    _dropdownOpacity = 0.86;
    _profileHardware();
    notifyListeners();
  }
}

extension ThemeExtension on BuildContext {
  AppColors get appColors => watch<ThemeProvider>().colors;
}
