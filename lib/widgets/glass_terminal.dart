import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/language_provider.dart';
import '../theme/theme_provider.dart';
import 'app_toast.dart';
import 'glass_widgets.dart';

/// Semantic classification for terminal log output.
enum TerminalLineType {
  command,
  info,
  success,
  warn,
  error,
  system,
  output,
  ascii,
}

/// Single record in the terminal stream.
class TerminalLine {
  final String text;
  final TerminalLineType type;
  final DateTime timestamp;

  TerminalLine(
    this.text, {
    this.type = TerminalLineType.output,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Controller to manipulate terminal output stream from external callers.
class GlassTerminalController {
  _GlassTerminalPanelState? _state;

  void appendLine(
    String text, {
    TerminalLineType type = TerminalLineType.output,
  }) {
    _state?.appendExternalLine(text, type: type);
  }

  void appendLines(
    List<String> lines, {
    TerminalLineType type = TerminalLineType.output,
  }) {
    _state?.appendExternalLines(lines, type: type);
  }

  void clear() {
    _state?.clearStream();
  }

  int get lineCount => _state?._lines.length ?? 0;
}

/// Dedicated high-contrast color palette inspired by Fedora 44 (Ptyxis / GNOME Console).
/// Ensures crisp, high-contrast legibility across both Dark Mode (Obsidian Velvet)
/// and Light Mode (Adwaita Porcelain / Ivory) with WCAG AAA/AA compliant contrast ratios.
class _TerminalThemePalette {
  final bool isDark;

  // Containers & Canvas
  final Color cardBg;
  final Color streamBg;
  final Color headerBg;
  final Color promptBg;
  final Color chipsBarBg;
  final Color borderColor;
  final Color innerBorderColor;

  // Text & Syntax Colors
  final Color textPrimary;
  final Color textMuted;
  final Color timestamp;
  final Color commandText;
  final Color infoText;
  final Color successText;
  final Color warnText;
  final Color errorText;
  final Color systemText;
  final Color asciiText;

  // Prompt Pill (➜ ~)
  final Color promptPillBg;
  final Color promptPillBorder;
  final Color promptPillText;

  // Quick Action Chips
  final Color chipBg;
  final Color chipBorder;
  final Color chipText;
  final Color chipHoverBg;

  // Title Pill & Status Badge
  final Color titlePillBg;
  final Color titlePillBorder;
  final Color titlePillText;
  final Color statusBadgeBg;
  final Color statusBadgeBorder;
  final Color statusBadgeText;
  final Color headerIconColor;

  // Prompt Input Bar
  final Color inputTextColor;
  final Color inputHintColor;
  final Color submitBtnBg;
  final Color submitBtnIcon;

  const _TerminalThemePalette._({
    required this.isDark,
    required this.cardBg,
    required this.streamBg,
    required this.headerBg,
    required this.promptBg,
    required this.chipsBarBg,
    required this.borderColor,
    required this.innerBorderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.timestamp,
    required this.commandText,
    required this.infoText,
    required this.successText,
    required this.warnText,
    required this.errorText,
    required this.systemText,
    required this.asciiText,
    required this.promptPillBg,
    required this.promptPillBorder,
    required this.promptPillText,
    required this.chipBg,
    required this.chipBorder,
    required this.chipText,
    required this.chipHoverBg,
    required this.titlePillBg,
    required this.titlePillBorder,
    required this.titlePillText,
    required this.statusBadgeBg,
    required this.statusBadgeBorder,
    required this.statusBadgeText,
    required this.headerIconColor,
    required this.inputTextColor,
    required this.inputHintColor,
    required this.submitBtnBg,
    required this.submitBtnIcon,
  });

  factory _TerminalThemePalette.resolve({
    required bool isDark,
    required AppColors colors,
  }) {
    if (isDark) {
      // Fedora 44 Dark Mode (Ptyxis Obsidian Velvet)
      return _TerminalThemePalette._(
        isDark: true,
        cardBg: const Color(0xE60E131E),
        streamBg: const Color(0xF40A0E17),
        headerBg: const Color(0xF0121724),
        promptBg: const Color(0xF0121724),
        chipsBarBg: const Color(0xEB0F1420),
        borderColor: const Color(0x3894A3B8),
        innerBorderColor: const Color(0x2294A3B8),
        textPrimary: const Color(0xFFF1F5F9),
        textMuted: const Color(0xFF94A3B8),
        timestamp: const Color(0xFF64748B),
        commandText: const Color(0xFF34D399),
        infoText: const Color(0xFF38BDF8),
        successText: const Color(0xFF4ADE80),
        warnText: const Color(0xFFFBBF24),
        errorText: const Color(0xFFF87171),
        systemText: const Color(0xFFC084FC),
        asciiText: const Color(0xFF34D399),
        promptPillBg: const Color(0x2510B981),
        promptPillBorder: const Color(0x5510B981),
        promptPillText: const Color(0xFF34D399),
        chipBg: const Color(0x301E293B),
        chipBorder: const Color(0x50475569),
        chipText: const Color(0xFF38BDF8),
        chipHoverBg: const Color(0x55334155),
        titlePillBg: const Color(0x401E293B),
        titlePillBorder: const Color(0x50475569),
        titlePillText: const Color(0xFFF1F5F9),
        statusBadgeBg: const Color(0x2010B981),
        statusBadgeBorder: const Color(0x4010B981),
        statusBadgeText: const Color(0xFF34D399),
        headerIconColor: const Color(0xFF94A3B8),
        inputTextColor: const Color(0xFFF1F5F9),
        inputHintColor: const Color(0xFF64748B),
        submitBtnBg: const Color(0x2510B981),
        submitBtnIcon: const Color(0xFF34D399),
      );
    } else {
      // Fedora 44 Light Mode (Ptyxis / Adwaita Clean Porcelain Canvas)
      return _TerminalThemePalette._(
        isDark: false,
        cardBg: const Color(0xF6F8FAFC),
        streamBg: const Color(0xFFFFFFFF),
        headerBg: const Color(0xF4F1F5F9),
        promptBg: const Color(0xF4F1F5F9),
        chipsBarBg: const Color(0xEFF1F5F9),
        borderColor: const Color(0xFFCBD5E1),
        innerBorderColor: const Color(0xFFE2E8F0),
        textPrimary: const Color(0xFF0F172A),
        textMuted: const Color(0xFF475569),
        timestamp: const Color(0xFF64748B),
        commandText: const Color(0xFF047857),
        infoText: const Color(0xFF0284C7),
        successText: const Color(0xFF059669),
        warnText: const Color(0xFFB45309),
        errorText: const Color(0xFFDC2626),
        systemText: const Color(0xFF7C3AED),
        asciiText: const Color(0xFF0F172A),
        promptPillBg: const Color(0xFFDCFCE7),
        promptPillBorder: const Color(0xFF86EFAC),
        promptPillText: const Color(0xFF047857),
        chipBg: const Color(0xFFE2E8F0),
        chipBorder: const Color(0xFFCBD5E1),
        chipText: const Color(0xFF0369A1),
        chipHoverBg: const Color(0xFFCBD5E1),
        titlePillBg: const Color(0xFFFFFFFF),
        titlePillBorder: const Color(0xFFCBD5E1),
        titlePillText: const Color(0xFF0F172A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        statusBadgeBorder: const Color(0xFF86EFAC),
        statusBadgeText: const Color(0xFF047857),
        headerIconColor: const Color(0xFF475569),
        inputTextColor: const Color(0xFF0F172A),
        inputHintColor: const Color(0xFF64748B),
        submitBtnBg: const Color(0xFFDCFCE7),
        submitBtnIcon: const Color(0xFF047857),
      );
    }
  }
}

/// Simulated Bento Glassmorphic Command Terminal Panel.
///
/// Provides a sleek, high-contrast command prompt with macOS/Fedora-style window chrome,
/// glowing syntax highlighting, authentic command history (Up/Down arrow keys),
/// live blinking cursor persistence upon Enter, Tab auto-completion,
/// quick action chips, and a built-in mock command execution engine.
class GlassTerminalPanel extends StatefulWidget {
  final String? terminalTitle;
  final String? initialWelcomeText;
  final FutureOr<String?> Function(String command)? onCommand;
  final GlassTerminalController? controller;
  final List<String>? quickCommands;

  const GlassTerminalPanel({
    super.key,
    this.terminalTitle,
    this.initialWelcomeText,
    this.onCommand,
    this.controller,
    this.quickCommands,
  });

  @override
  State<GlassTerminalPanel> createState() => _GlassTerminalPanelState();
}

class _GlassTerminalPanelState extends State<GlassTerminalPanel> {
  final List<TerminalLine> _lines = [];
  final List<String> _history = [];
  int _historyIndex = -1;
  String _currentDraft = '';

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'TerminalPromptFocusNode',
    onKeyEvent: _handleKeyEvent,
  );

  bool _autoScroll = true;

  static const _knownCommands = [
    'help',
    'status',
    'ping',
    'nodes',
    'devices',
    'theme',
    'matrix',
    'clear',
    'cls',
    'echo',
    'date',
    'time',
    'version',
  ];

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _initTerminalSession();
  }

  @override
  void didUpdateWidget(GlassTerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  void _initTerminalSession() {
    LanguageProvider? lang;
    try {
      lang = Provider.of<LanguageProvider>(context, listen: false);
    } catch (_) {}

    final initMsg = lang != null
        ? lang.t('terminal_subsystem_init')
        : 'JA Terminal Subsystem Initialized';

    final welcome =
        widget.initialWelcomeText ??
        (lang != null
            ? '${lang.t('terminal_default_banner')}\n${lang.t('terminal_default_help_hint')}'
            : 'JA Remote Command Console [Version 1.2.0]\n'
                  'Type "help" to view available diagnostic and system commands.');

    _lines.add(TerminalLine(initMsg, type: TerminalLineType.system));
    for (final line in welcome.split('\n')) {
      _lines.add(TerminalLine(line, type: TerminalLineType.info));
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void appendExternalLine(
    String text, {
    TerminalLineType type = TerminalLineType.output,
  }) {
    if (!mounted) return;
    setState(() {
      _lines.add(TerminalLine(text, type: type));
    });
    _scrollToBottom();
  }

  void appendExternalLines(
    List<String> lines, {
    TerminalLineType type = TerminalLineType.output,
  }) {
    if (!mounted) return;
    setState(() {
      for (final line in lines) {
        _lines.add(TerminalLine(line, type: type));
      }
    });
    _scrollToBottom();
  }

  void clearStream() {
    if (!mounted) return;
    setState(() {
      _lines.clear();
    });
  }

  void _keepPromptFocused() {
    if (!mounted) return;
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _scrollToBottom() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateHistory(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _navigateHistory(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        _autoCompleteCommand();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _navigateHistory(int direction) {
    if (_history.isEmpty) return;

    if (_historyIndex == -1) {
      // User is currently at the live prompt line, save current typed text as draft
      _currentDraft = _inputController.text;
      if (direction < 0) {
        _historyIndex = _history.length - 1;
      } else {
        return; // Already at the live line, cannot go forward
      }
    } else {
      _historyIndex += direction;
    }

    if (_historyIndex < 0) {
      _historyIndex = 0; // Clamped at the oldest command
    } else if (_historyIndex >= _history.length) {
      // Reached back to the live draft
      _historyIndex = -1;
      _inputController.text = _currentDraft;
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
      return;
    }

    _inputController.text = _history[_historyIndex];
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
  }

  void _autoCompleteCommand() {
    final current = _inputController.text.trim();
    if (current.isEmpty) return;

    final matches = _knownCommands
        .where((cmd) => cmd.startsWith(current.toLowerCase()))
        .toList();

    if (matches.length == 1) {
      _inputController.text = '${matches.first} ';
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
    } else if (matches.length > 1) {
      setState(() {
        _lines.add(
          TerminalLine('➜ ~ $current', type: TerminalLineType.command),
        );
        _lines.add(
          TerminalLine(matches.join('   '), type: TerminalLineType.info),
        );
      });
      _scrollToBottom();
      _keepPromptFocused();
    }
  }

  Future<void> _executeCommand(String rawCommand) async {
    final cmd = rawCommand.trim();
    if (cmd.isEmpty) {
      // In real terminals, pressing Enter on empty prompt prints blank prompt line
      setState(() {
        _lines.add(TerminalLine('➜ ~', type: TerminalLineType.command));
      });
      _inputController.clear();
      _scrollToBottom();
      _keepPromptFocused();
      return;
    }

    // Add to history (avoid consecutive duplicates)
    if (_history.isEmpty || _history.last != cmd) {
      _history.add(cmd);
    }
    _historyIndex = -1;
    _currentDraft = '';

    setState(() {
      _lines.add(TerminalLine('➜ ~ $cmd', type: TerminalLineType.command));
    });

    _inputController.clear();
    _scrollToBottom();
    _keepPromptFocused();

    // Hook: external consumer callback
    if (widget.onCommand != null) {
      final customResult = await widget.onCommand!(cmd);
      if (customResult != null) {
        if (!mounted) return;
        setState(() {
          for (final l in customResult.split('\n')) {
            _lines.add(TerminalLine(l, type: TerminalLineType.output));
          }
        });
        _scrollToBottom();
        _keepPromptFocused();
        return;
      }
    }

    // Built-in Mock Execution Engine
    final parts = cmd.split(RegExp(r'\s+'));
    final mainCmd = parts[0].toLowerCase();
    final args = parts.sublist(1);

    if (!mounted) return;

    switch (mainCmd) {
      case 'clear':
      case 'cls':
        setState(() {
          _lines.clear();
        });
        _keepPromptFocused();
        return;

      case 'help':
        _printHelp();
        break;

      case 'status':
        _printStatus();
        break;

      case 'ping':
        await _simulatePing(args.isNotEmpty ? args[0] : '127.0.0.1');
        break;

      case 'nodes':
      case 'devices':
        _printNodes();
        break;

      case 'theme':
        _handleThemeCommand(args);
        break;

      case 'matrix':
        await _simulateMatrixRain();
        break;

      case 'echo':
        setState(() {
          _lines.add(
            TerminalLine(args.join(' '), type: TerminalLineType.output),
          );
        });
        break;

      case 'date':
      case 'time':
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        setState(() {
          _lines.add(
            TerminalLine(
              '${lang.t('terminal_current_time')}: ${DateTime.now().toIso8601String()}',
              type: TerminalLineType.info,
            ),
          );
        });
        break;

      case 'version':
        setState(() {
          _lines.add(
            TerminalLine(
              'JA Showcase Terminal v1.2.0 [Fedora 44 / Bento Glass Engine]',
              type: TerminalLineType.system,
            ),
          );
        });
        break;

      default:
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        setState(() {
          _lines.add(
            TerminalLine(
              lang.t('terminal_cmd_not_found', {'cmd': cmd}),
              type: TerminalLineType.error,
            ),
          );
        });
    }

    _scrollToBottom();
    _keepPromptFocused();
  }

  void _printHelp() {
    LanguageProvider? lang;
    try {
      lang = Provider.of<LanguageProvider>(context, listen: false);
    } catch (_) {}

    final header =
        lang?.t('terminal_help_header') ??
        'Available Diagnostic & Shell Commands:';
    final helpDesc =
        lang?.t('terminal_help_cmd_help') ??
        'Show this list of available commands';
    final statusDesc =
        lang?.t('terminal_help_cmd_status') ??
        'Print runtime status, graphic tier & hardware specs';
    final pingDesc =
        lang?.t('terminal_help_cmd_ping') ??
        'Send simulated ICMP echo packets with latency report';
    final nodesDesc =
        lang?.t('terminal_help_cmd_nodes') ??
        'Display connected hardware nodes table';
    final themeDesc =
        lang?.t('terminal_help_cmd_theme') ??
        'Toggle or set theme ("dark" or "light")';
    final matrixDesc =
        lang?.t('terminal_help_cmd_matrix') ??
        'Simulate digital cyber code stream';
    final echoDesc =
        lang?.t('terminal_help_cmd_echo') ??
        'Print text string to console output';
    final dateDesc =
        lang?.t('terminal_help_cmd_date') ??
        'Display current system date and timestamp';
    final versionDesc =
        lang?.t('terminal_help_cmd_version') ??
        'Print terminal & application version';
    final clearDesc =
        lang?.t('terminal_help_cmd_clear') ??
        'Wipe clean terminal stream buffer';

    final helpLines = [
      header,
      '  help            $helpDesc',
      '  status          $statusDesc',
      '  ping <host>     $pingDesc',
      '  nodes           $nodesDesc',
      '  theme [mode]    $themeDesc',
      '  matrix          $matrixDesc',
      '  echo <text>     $echoDesc',
      '  date            $dateDesc',
      '  version         $versionDesc',
      '  clear / cls     $clearDesc',
    ];

    setState(() {
      for (final l in helpLines) {
        _lines.add(TerminalLine(l, type: TerminalLineType.info));
      }
    });
  }

  void _printStatus() {
    final theme = context.read<ThemeProvider>();
    final tierName = theme.effectiveTier.name.toUpperCase();
    final perfMode = theme.perfMode.name.toUpperCase();

    final statusLines = [
      '[SYSTEM RUNTIME STATUS]',
      '  Host OS:         ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      '  Dart/Flutter:    3.10.x+ (Null Safety Active)',
      '  Graphic Tier:    $tierName (Profile: $perfMode)',
      '  Hardware Score:  ${theme.hardwareScore} pts (Cores: ${theme.cpuCores})',
      '  Active Blur:     ${theme.cardBlur.toStringAsFixed(1)} px (Card Opacity: ${(theme.dropdownOpacity * 100).toInt()}%)',
      '  DWM Compositor:  DirectComposition / BlurSurface Active',
      '  Engine Health:   100% OPERATIONAL (Zero Packet Drops)',
    ];

    setState(() {
      for (final l in statusLines) {
        _lines.add(TerminalLine(l, type: TerminalLineType.success));
      }
    });
  }

  Future<void> _simulatePing(String host) async {
    setState(() {
      _lines.add(
        TerminalLine(
          'PING $host ($host): 56 data bytes',
          type: TerminalLineType.system,
        ),
      );
    });
    _scrollToBottom();

    final rnd = math.Random();
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      final ms = (rnd.nextDouble() * 18 + 8).toStringAsFixed(1);
      setState(() {
        _lines.add(
          TerminalLine(
            '64 bytes from $host: icmp_seq=$i ttl=118 time=${ms}ms',
            type: TerminalLineType.output,
          ),
        );
      });
      _scrollToBottom();
    }

    if (!mounted) return;
    setState(() {
      _lines.add(
        TerminalLine(
          '--- $host ping statistics: 4 packets transmitted, 4 received, 0% packet loss ---',
          type: TerminalLineType.info,
        ),
      );
    });
  }

  void _printNodes() {
    const table = [
      '┌──────────────┬────────────────┬──────────────┬─────────┐',
      '│ Node ID      │ IP Address     │ Role         │ Status  │',
      '├──────────────┼────────────────┼──────────────┼─────────┤',
      '│ JA-EDGE-01   │ 192.168.1.10   │ Primary Core │ ONLINE  │',
      '│ JA-SENSOR-X  │ 192.168.1.42   │ Telemetry    │ ONLINE  │',
      '│ JA-GW-BETA   │ 192.168.1.99   │ Relay Mesh   │ STANDBY │',
      '│ JA-CAM-04    │ 192.168.1.105  │ Video Stream │ ONLINE  │',
      '└──────────────┴────────────────┴──────────────┴─────────┘',
    ];

    setState(() {
      for (final l in table) {
        _lines.add(TerminalLine(l, type: TerminalLineType.ascii));
      }
    });
  }

  void _handleThemeCommand(List<String> args) {
    final theme = context.read<ThemeProvider>();
    if (args.isEmpty) {
      theme.cyclePerfTier();
      setState(() {
        _lines.add(
          TerminalLine(
            'Perf Mode cycled. Current: ${theme.perfLabel}',
            type: TerminalLineType.success,
          ),
        );
      });
      return;
    }

    final mode = args[0].toLowerCase();
    if (mode == 'dark' || mode == 'light') {
      setState(() {
        _lines.add(
          TerminalLine(
            'Theme toggle supported via header button.',
            type: TerminalLineType.info,
          ),
        );
      });
    } else {
      setState(() {
        _lines.add(TerminalLine('Usage: theme', type: TerminalLineType.warn));
      });
    }
  }

  Future<void> _simulateMatrixRain() async {
    setState(() {
      _lines.add(
        TerminalLine(
          '[INITIALIZING CYBERSTREAM BUFFER...]',
          type: TerminalLineType.system,
        ),
      );
    });
    _scrollToBottom();

    final rnd = math.Random();
    const chars = '0123456789ABCDEF!@#%&*+-=<>~';
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final buffer = StringBuffer();
      for (int c = 0; c < 48; c++) {
        buffer.write(chars[rnd.nextInt(chars.length)]);
      }
      setState(() {
        _lines.add(
          TerminalLine(buffer.toString(), type: TerminalLineType.ascii),
        );
      });
      _scrollToBottom();
    }

    if (!mounted) return;
    setState(() {
      _lines.add(
        TerminalLine(
          '[CYBERSTREAM SEQUENCE COMPLETE]',
          type: TerminalLineType.success,
        ),
      );
    });
  }

  void _copyAllLogs(
    BuildContext context,
    AppColors colors,
    LanguageProvider lang,
  ) {
    final buffer = StringBuffer();
    for (final line in _lines) {
      final timeStr =
          '[${line.timestamp.hour.toString().padLeft(2, '0')}:${line.timestamp.minute.toString().padLeft(2, '0')}:${line.timestamp.second.toString().padLeft(2, '0')}]';
      buffer.writeln('$timeStr ${line.text}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showAppToast(
      context,
      message: lang.t('terminal_copied'),
      colors: colors,
      icon: Icons.content_copy_rounded,
    );
    _keepPromptFocused();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final colors = theme.colors;

    // Resolve high-contrast Fedora 44 palette (adaptive dark/light)
    final palette = _TerminalThemePalette.resolve(
      isDark: theme.isDark,
      colors: colors,
    );

    return BentoCard(
      colors: colors,
      padding: EdgeInsets.zero,
      blurSigma: theme.cardBlur,
      customBg: palette.cardBg,
      customBorder: palette.borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. macOS / Fedora Window Header Bar
          _TerminalHeader(
            terminalTitle:
                widget.terminalTitle ?? 'terminal@ja-remote: ~ (powershell)',
            palette: palette,
            language: language,
            autoScroll: _autoScroll,
            onToggleAutoScroll: () {
              setState(() => _autoScroll = !_autoScroll);
              _keepPromptFocused();
            },
            onClear: () {
              setState(() => _lines.clear());
              _keepPromptFocused();
            },
            onCopy: () => _copyAllLogs(context, colors, language),
          ),

          // 2. High-Contrast Terminal Console Stream (Ptyxis / Fedora 44 Canvas)
          Expanded(
            child: GestureDetector(
              onTap: _keepPromptFocused,
              behavior: HitTestBehavior.translucent,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.streamBg,
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: palette.innerBorderColor,
                      width: 1,
                    ),
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    return _TerminalLineWidget(
                      line: _lines[index],
                      palette: palette,
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. Quick Action Chips Bar (With solid contrast and borders)
          _QuickActionChips(
            palette: palette,
            quickCommands: widget.quickCommands,
            onCommandSelected: (cmd) {
              _executeCommand(cmd);
              _keepPromptFocused();
            },
          ),

          // 4. Interactive Command Prompt Bar (Persistently focused cursor)
          _TerminalPromptBar(
            palette: palette,
            language: language,
            controller: _inputController,
            focusNode: _focusNode,
            onSubmitted: _executeCommand,
          ),
        ],
      ),
    );
  }
}

/// Window Chrome Bar with traffic lights, title pill, live badge, and action buttons.
class _TerminalHeader extends StatelessWidget {
  final String terminalTitle;
  final _TerminalThemePalette palette;
  final LanguageProvider language;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;
  final VoidCallback onClear;
  final VoidCallback onCopy;

  const _TerminalHeader({
    required this.terminalTitle,
    required this.palette,
    required this.language,
    required this.autoScroll,
    required this.onToggleAutoScroll,
    required this.onClear,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.headerBg,
        border: Border(
          bottom: BorderSide(color: palette.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          _TerminalTrafficLights(isDark: palette.isDark),
          const SizedBox(width: 14),

          // Title Badge
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.titlePillBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.titlePillBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.terminal_rounded,
                        size: 13,
                        color: palette.infoText,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          terminalTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.titlePillText,
                            fontSize: 11.5,
                            fontFamily: 'JetBrains Mono',
                            fontFamilyFallback: const ['Consolas', 'monospace'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PillBadge(
                  label: 'LIVE • READY',
                  color: palette.statusBadgeText,
                  bg: palette.statusBadgeBg,
                  border: palette.statusBadgeBorder,
                  showDot: true,
                  fontSize: 10,
                ),
              ],
            ),
          ),

          // Action Buttons: Clear, Copy, Auto-Scroll Lock
          _HeaderIconButton(
            icon: Icons.delete_sweep_rounded,
            tooltip: language.t('terminal_clear'),
            color: palette.headerIconColor,
            onTap: onClear,
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.content_copy_rounded,
            tooltip: language.t('terminal_copy'),
            color: palette.headerIconColor,
            onTap: onCopy,
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: autoScroll
                ? Icons.vertical_align_bottom_rounded
                : Icons.pause_circle_outline_rounded,
            tooltip: language.t('terminal_autoscroll'),
            color: autoScroll
                ? palette.statusBadgeText
                : palette.textMuted.withValues(alpha: 0.6),
            onTap: onToggleAutoScroll,
          ),
        ],
      ),
    );
  }
}

/// macOS / Fedora Traffic Lights (Red, Amber, Green) with glowing circles.
class _TerminalTrafficLights extends StatelessWidget {
  final bool isDark;
  const _TerminalTrafficLights({this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LightDot(
          color: const Color(0xFFFF5F56),
          borderColor: isDark ? null : const Color(0x35000000),
        ),
        const SizedBox(width: 6),
        _LightDot(
          color: const Color(0xFFFFBD2E),
          borderColor: isDark ? null : const Color(0x35000000),
        ),
        const SizedBox(width: 6),
        _LightDot(
          color: const Color(0xFF27C93F),
          borderColor: isDark ? null : const Color(0x35000000),
        ),
      ],
    );
  }
}

class _LightDot extends StatelessWidget {
  final Color color;
  final Color? borderColor;

  const _LightDot({required this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? color.withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// Quick action chips for executing predefined diagnostic commands.
class _QuickActionChips extends StatelessWidget {
  final _TerminalThemePalette palette;
  final ValueChanged<String> onCommandSelected;
  final List<String>? quickCommands;

  const _QuickActionChips({
    required this.palette,
    required this.onCommandSelected,
    this.quickCommands,
  });

  static const _defaultCommands = [
    'help',
    'status',
    'ping 8.8.8.8',
    'nodes',
    'matrix',
    'clear',
  ];

  @override
  Widget build(BuildContext context) {
    final commands = quickCommands ?? _defaultCommands;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: palette.chipsBarBg,
        border: Border(
          top: BorderSide(color: palette.innerBorderColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: commands
              .map((cmd) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => onCommandSelected(cmd),
                    borderRadius: BorderRadius.circular(6),
                    hoverColor: palette.chipHoverBg,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chipBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.chipBorder),
                      ),
                      child: Text(
                        cmd,
                        style: TextStyle(
                          color: palette.chipText,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                          fontFamilyFallback: const ['Consolas', 'monospace'],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// Formatted single log line with syntax coloring and monospace styling.
class _TerminalLineWidget extends StatelessWidget {
  final TerminalLine line;
  final _TerminalThemePalette palette;

  const _TerminalLineWidget({required this.line, required this.palette});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${line.timestamp.hour.toString().padLeft(2, '0')}:${line.timestamp.minute.toString().padLeft(2, '0')}:${line.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              color: palette.timestamp,
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: const ['Consolas', 'monospace'],
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),

          // Output body
          Expanded(
            child: SelectableText(
              line.text,
              style: _resolveStyle(line.type, palette),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _resolveStyle(
    TerminalLineType type,
    _TerminalThemePalette palette,
  ) {
    const base = TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: ['Consolas', 'monospace'],
      fontSize: 12.5,
      height: 1.4,
    );

    switch (type) {
      case TerminalLineType.command:
        return base.copyWith(
          color: palette.commandText,
          fontWeight: FontWeight.w700,
        );
      case TerminalLineType.info:
        return base.copyWith(
          color: palette.infoText,
          fontWeight: FontWeight.w600,
        );
      case TerminalLineType.success:
        return base.copyWith(
          color: palette.successText,
          fontWeight: FontWeight.w600,
        );
      case TerminalLineType.warn:
        return base.copyWith(
          color: palette.warnText,
          fontWeight: FontWeight.w600,
        );
      case TerminalLineType.error:
        return base.copyWith(
          color: palette.errorText,
          fontWeight: FontWeight.w600,
        );
      case TerminalLineType.system:
        return base.copyWith(
          color: palette.systemText,
          fontWeight: FontWeight.w600,
        );
      case TerminalLineType.ascii:
        return base.copyWith(
          color: palette.asciiText,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
        );
      case TerminalLineType.output:
        return base.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w500,
        );
    }
  }
}

/// Prompt input bar at the bottom with neon arrow indicator, persistent focus, and submit button.
class _TerminalPromptBar extends StatelessWidget {
  final _TerminalThemePalette palette;
  final LanguageProvider language;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  const _TerminalPromptBar({
    required this.palette,
    required this.language,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.promptBg,
        border: Border(top: BorderSide(color: palette.borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Prompt symbol: ➜ ~
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: palette.promptPillBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.promptPillBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 12,
                  color: palette.promptPillText,
                ),
                const SizedBox(width: 4),
                Text(
                  '➜ ~',
                  style: TextStyle(
                    color: palette.promptPillText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: const ['Consolas', 'monospace'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Interactive TextField with persistent blinking cursor
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              showCursor: true,
              cursorColor: palette.commandText,
              cursorWidth: 2.5,
              cursorRadius: const Radius.circular(1.5),
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: palette.inputTextColor,
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const ['Consolas', 'monospace'],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: language.t('terminal_prompt_hint'),
                hintStyle: TextStyle(
                  color: palette.inputHintColor,
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: const ['Consolas', 'monospace'],
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: (value) {
                onSubmitted(value);
                focusNode.requestFocus();
              },
            ),
          ),

          // Submit Arrow Button
          InkWell(
            onTap: () {
              onSubmitted(controller.text);
              focusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.submitBtnBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: palette.submitBtnIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
