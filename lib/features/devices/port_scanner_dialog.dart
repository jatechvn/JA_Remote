import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/port_scan_service.dart';
import '../../core/process/process_runner.dart';
import '../../theme/app_colors.dart';
import '../../theme/language_provider.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/glass_widgets.dart';

/// Opens the Port Scanner and TCP diagnostics dialog.
Future<void> showPortScannerDialog(
  BuildContext context, {
  String? initialHost,
  int? initialPort,
}) {
  final theme = context.read<ThemeProvider>();
  final colors = theme.colors;
  final language = context.read<LanguageProvider>();

  return showGlassDialog(
    context: context,
    colors: colors,
    title: language.t('port_scanner_title'),
    icon: Icons.radar_rounded,
    width: 680,
    content: PortScannerDialogContent(
      initialHost: initialHost,
      initialPort: initialPort,
    ),
  );
}

enum _ScanMode { single, common, range }

class PortScannerDialogContent extends StatefulWidget {
  final String? initialHost;
  final int? initialPort;

  const PortScannerDialogContent({
    super.key,
    this.initialHost,
    this.initialPort,
  });

  @override
  State<PortScannerDialogContent> createState() =>
      _PortScannerDialogContentState();
}

class _PortScannerDialogContentState extends State<PortScannerDialogContent> {
  final PortScanService _service = PortScanService();

  late final TextEditingController _hostController;
  late final TextEditingController _singlePortController;
  final TextEditingController _fromPortController = TextEditingController(
    text: '1',
  );
  final TextEditingController _toPortController = TextEditingController(
    text: '1024',
  );
  final ScrollController _scrollController = ScrollController();

  late _ScanMode _mode;
  bool _isScanning = false;
  bool _filterOpenOnly = false;
  int _totalToScan = 0;
  int _scannedCount = 0;

  final List<PortScanResult> _results = [];
  CancellationToken? _cancellationToken;
  StreamSubscription<PortScanResult>? _subscription;

  static const List<(int, String)> _quickSinglePorts = [
    (3389, 'RDP'),
    (22, 'SSH'),
    (5985, 'WinRM'),
    (445, 'SMB'),
    (80, 'HTTP'),
    (443, 'HTTPS'),
    (3306, 'MySQL'),
    (1433, 'MSSQL'),
    (5900, 'VNC'),
    (8080, 'Web-8080'),
  ];

  static const List<(int, int, String)> _rangePresets = [
    (1, 1024, '1 - 1024 (Well-Known)'),
    (1025, 5000, '1025 - 5000 (Services)'),
    (8000, 9000, '8000 - 9000 (Web & APIs)'),
    (1, 65535, '1 - 65535 (Full Scan)'),
  ];

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(
      text: widget.initialHost?.trim().isNotEmpty == true
          ? widget.initialHost!
          : '127.0.0.1',
    );
    _singlePortController = TextEditingController(
      text: widget.initialPort?.toString() ?? '3389',
    );
    _mode = widget.initialPort != null ? _ScanMode.single : _ScanMode.common;
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _subscription?.cancel();
    _hostController.dispose();
    _singlePortController.dispose();
    _fromPortController.dispose();
    _toPortController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScan() {
    _cancellationToken?.cancel();
    _subscription?.cancel();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _startScan() async {
    final language = context.read<LanguageProvider>();
    final colors = context.read<ThemeProvider>().colors;
    final host = _hostController.text.trim();

    if (host.isEmpty) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('dialog_ip_required'),
        icon: Icons.warning_rounded,
        accentColor: colors.accentAmber,
      );
      return;
    }

    _stopScan();

    List<int> portsToScan = [];
    int concurrency = 10;

    switch (_mode) {
      case _ScanMode.single:
        final port = int.tryParse(_singlePortController.text.trim());
        if (port == null || port < 1 || port > 65535) {
          showAppToast(
            context,
            colors: colors,
            message: language.t('port_scan_invalid_range'),
            icon: Icons.error_outline_rounded,
            accentColor: colors.accentRose,
          );
          return;
        }
        portsToScan = [port];
        concurrency = 1;
        break;

      case _ScanMode.common:
        portsToScan = PortScanService.commonPorts;
        concurrency = 10;
        break;

      case _ScanMode.range:
        final start = int.tryParse(_fromPortController.text.trim());
        final end = int.tryParse(_toPortController.text.trim());

        if (start == null ||
            end == null ||
            start < 1 ||
            end > 65535 ||
            start > end) {
          showAppToast(
            context,
            colors: colors,
            message: language.t('port_scan_invalid_range'),
            icon: Icons.error_outline_rounded,
            accentColor: colors.accentRose,
          );
          return;
        }
        portsToScan = List<int>.generate(end - start + 1, (i) => start + i);
        concurrency = 25;
        break;
    }

    setState(() {
      _isScanning = true;
      _results.clear();
      _scannedCount = 0;
      _totalToScan = portsToScan.length;
    });

    final token = CancellationToken();
    _cancellationToken = token;

    final stream = _service.scanPortsStream(
      host,
      portsToScan,
      timeout: const Duration(milliseconds: 700),
      concurrency: concurrency,
      cancelToken: token,
    );

    _subscription = stream.listen(
      (result) {
        if (!mounted || token.isCancelled) return;
        setState(() {
          _results.add(result);
          _scannedCount++;
        });
      },
      onDone: () {
        if (!mounted || token.isCancelled) return;
        setState(() {
          _isScanning = false;
        });
      },
      onError: (err) {
        if (!mounted || token.isCancelled) return;
        setState(() {
          _isScanning = false;
        });
      },
      cancelOnError: false,
    );
  }

  void _launchAction(PortScanResult result) {
    final host = result.host;
    final port = result.port;
    final colors = context.read<ThemeProvider>().colors;
    final language = context.read<LanguageProvider>();

    if (port == 3389) {
      ProcessRunner.launchRdp(host);
      showAppToast(
        context,
        colors: colors,
        message: 'RDP -> $host:$port...',
        icon: Icons.desktop_windows_rounded,
      );
    } else if (port == 445) {
      ProcessRunner.launchExplorerShare(host);
      showAppToast(
        context,
        colors: colors,
        message: 'Explorer -> \\\\$host\\c\$...',
        icon: Icons.folder_shared_rounded,
      );
    } else if (port == 22) {
      if (Platform.isWindows) {
        Process.start('cmd.exe', [
          '/c',
          'start',
          'ssh',
          host,
          '-p',
          '$port',
        ], mode: ProcessStartMode.detached);
        showAppToast(
          context,
          colors: colors,
          message: 'SSH -> $host:$port...',
          icon: Icons.terminal_rounded,
        );
      }
    } else if (port == 80 ||
        port == 443 ||
        port == 8080 ||
        port == 8443 ||
        port == 8090 ||
        port == 8888 ||
        port == 3000 ||
        port == 9000 ||
        port == 9090) {
      final scheme = (port == 443 || port == 8443) ? 'https' : 'http';
      final url = '$scheme://$host:$port';
      if (Platform.isWindows) {
        Process.start('cmd.exe', [
          '/c',
          'start',
          '',
          url,
        ], mode: ProcessStartMode.detached);
        showAppToast(
          context,
          colors: colors,
          message: '$url...',
          icon: Icons.open_in_browser_rounded,
        );
      }
    } else {
      Clipboard.setData(ClipboardData(text: '$host:$port'));
      showAppToast(
        context,
        colors: colors,
        message: '${language.t('port_scanner_action_copy')}: $host:$port',
        icon: Icons.copy_rounded,
        accentColor: colors.accentEmerald,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final isDark = theme.isDark;
    final language = context.watch<LanguageProvider>();

    final openCount = _results.where((r) => r.isOpen).length;
    final displayedResults = _filterOpenOnly
        ? _results.where((r) => r.isOpen).toList()
        : _results;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language.t('port_scanner_desc'),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 14),

          // Host Input & Mode Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.t('port_scanner_target_host'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.borderDefault),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.computer_rounded,
                            size: 16,
                            color: colors.accentCyan,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _hostController,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '192.168.1.100',
                                hintStyle: TextStyle(
                                  color: colors.textMuted.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chế độ quét',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          _buildModeTab(
                            _ScanMode.single,
                            language.t('port_scanner_mode_single'),
                            colors,
                            isDark,
                          ),
                          _buildModeTab(
                            _ScanMode.common,
                            language.t('port_scanner_mode_common'),
                            colors,
                            isDark,
                          ),
                          _buildModeTab(
                            _ScanMode.range,
                            language.t('port_scanner_mode_range'),
                            colors,
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Mode-specific configuration area
          _buildModeConfig(colors, language),

          const SizedBox(height: 14),

          // Progress & Scan Summary Row
          Row(
            children: [
              if (_isScanning) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accentCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${language.t('port_scanner_scanned_count')}: $_scannedCount / $_totalToScan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$openCount ${language.t('port_scanner_open_ports_found')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.accentEmerald,
                  ),
                ),
              ),
              const Spacer(),
              // Open only filter switch
              InkWell(
                onTap: () => setState(() => _filterOpenOnly = !_filterOpenOnly),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _filterOpenOnly
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: _filterOpenOnly
                            ? colors.accentCyan
                            : colors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        language.t('port_scanner_filter_open_only'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _filterOpenOnly
                              ? colors.textPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isScanning && _totalToScan > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _scannedCount / _totalToScan,
                minHeight: 4,
                backgroundColor: colors.cardBg,
                valueColor: AlwaysStoppedAnimation(colors.accentCyan),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Results Box
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: colors.cardBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderDefault),
            ),
            child: displayedResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isScanning
                              ? Icons.radar_rounded
                              : Icons.device_hub_rounded,
                          size: 32,
                          color: colors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isScanning
                              ? 'Đang kiểm tra các cổng TCP...'
                              : (_results.isNotEmpty && _filterOpenOnly
                                    ? 'Không tìm thấy cổng nào đang mở'
                                    : 'Chưa có kết quả. Nhấn bắt đầu để quét.'),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: displayedResults.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (ctx, index) {
                      final item = displayedResults[index];
                      return _buildResultTile(item, colors, language);
                    },
                  ),
          ),

          const SizedBox(height: 14),

          // Action Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GlassButton(
                label: language.t('dialog_cancel'),
                colors: colors,
                onTap: () {
                  _stopScan();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              if (_isScanning)
                GlassButton(
                  label: language.t('port_scanner_btn_stop'),
                  icon: Icons.stop_rounded,
                  colors: colors,
                  accentColor: colors.accentRose,
                  onTap: _stopScan,
                )
              else
                GlassButton(
                  label: language.t('port_scanner_btn_scan'),
                  icon: Icons.play_arrow_rounded,
                  colors: colors,
                  accentColor: colors.accentCyan,
                  onTap: _startScan,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(
    _ScanMode mode,
    String label,
    AppColors colors,
    bool isDark,
  ) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: _isScanning
            ? null
            : () {
                setState(() {
                  _mode = mode;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.accentCyan : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeConfig(AppColors colors, LanguageProvider language) {
    switch (_mode) {
      case _ScanMode.single:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.t('port_scanner_port_number'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderDefault),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: _singlePortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(top: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cổng thông dụng gợi ý',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _quickSinglePorts.map((item) {
                          final port = item.$1;
                          final label = item.$2;
                          final isCurrent =
                              _singlePortController.text == port.toString();
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _singlePortController.text = port.toString();
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? colors.accentCyan.withValues(alpha: 0.2)
                                    : colors.cardBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isCurrent
                                      ? colors.accentCyan
                                      : colors.borderDefault,
                                ),
                              ),
                              child: Text(
                                '$port ($label)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isCurrent
                                      ? colors.accentCyan
                                      : colors.textMuted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );

      case _ScanMode.common:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.cardBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.borderDefault),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colors.accentCyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quét nhanh 30 cổng chuẩn: RDP (3389), SSH (22), WinRM (5985/5986), SMB (445), Web (80/443), DB (MySQL, MSSQL, Redis, Postgres), VNC...',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ),
            ],
          ),
        );

      case _ScanMode.range:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.t('port_scanner_range_from'),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderDefault),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: _fromPortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(top: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    '->',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.t('port_scanner_range_to'),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderDefault),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: _toPortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(top: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dải định sẵn (Presets)',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _rangePresets.map((p) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _fromPortController.text = p.$1.toString();
                                _toPortController.text = p.$2.toString();
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.cardBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.borderDefault),
                              ),
                              child: Text(
                                p.$3,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildResultTile(
    PortScanResult result,
    AppColors colors,
    LanguageProvider language,
  ) {
    Color statusColor;
    String statusText;

    switch (result.status) {
      case PortStatus.open:
        statusColor = colors.accentEmerald;
        statusText = language.t('port_scanner_status_open');
        break;
      case PortStatus.closed:
        statusColor = colors.textMuted;
        statusText = language.t('port_scanner_status_closed');
        break;
      case PortStatus.timeout:
        statusColor = colors.accentAmber;
        statusText = language.t('port_scanner_status_timeout');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: result.isOpen
            ? colors.accentEmerald.withValues(alpha: 0.08)
            : colors.cardBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.isOpen
              ? colors.accentEmerald.withValues(alpha: 0.3)
              : colors.borderDefault.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Port number & Service name
          SizedBox(
            width: 70,
            child: Text(
              '${result.port}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: result.isOpen ? colors.accentCyan : colors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.serviceName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  result.description,
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Latency if open
          if (result.isOpen) ...[
            Text(
              '${result.latencyMs}ms',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: colors.accentEmerald,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Quick Action buttons on open port
          if (result.isOpen) ...[
            if (result.port == 3389)
              _buildActionButton(
                label: 'RDP',
                icon: Icons.desktop_windows_rounded,
                color: colors.accentCyan,
                onTap: () => _launchAction(result),
              ),
            if (result.port == 22)
              _buildActionButton(
                label: 'SSH',
                icon: Icons.terminal_rounded,
                color: colors.accentAmber,
                onTap: () => _launchAction(result),
              ),
            if (result.port == 445)
              _buildActionButton(
                label: 'SMB',
                icon: Icons.folder_shared_rounded,
                color: colors.accentAmber,
                onTap: () => _launchAction(result),
              ),
            if (result.port == 80 ||
                result.port == 443 ||
                result.port == 8080 ||
                result.port == 8443 ||
                result.port == 8090 ||
                result.port == 8888 ||
                result.port == 3000 ||
                result.port == 9000 ||
                result.port == 9090)
              _buildActionButton(
                label: 'Web',
                icon: Icons.open_in_browser_rounded,
                color: colors.accentCyan,
                onTap: () => _launchAction(result),
              ),
            // Always allow Copy
            _buildActionButton(
              label: '',
              icon: Icons.copy_rounded,
              color: colors.textMuted,
              onTap: () => _launchAction(result),
              tooltip: language.t('port_scanner_action_copy'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label.isNotEmpty ? 6 : 4,
          vertical: 3,
        ),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}
