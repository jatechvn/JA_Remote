part of 'dashboard_shell.dart';

class _SettingsOtaUpdateTab extends StatefulWidget {
  final AppColors colors;
  final LanguageProvider language;

  const _SettingsOtaUpdateTab({required this.colors, required this.language});

  @override
  State<_SettingsOtaUpdateTab> createState() => _SettingsOtaUpdateTabState();
}

class _SettingsOtaUpdateTabState extends State<_SettingsOtaUpdateTab> {
  final OtaUpdateService _otaService = OtaUpdateService();
  late TextEditingController _serverPathController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late String _checkInterval;

  bool _isTestingConnection = false;
  String? _testConnectionResult;
  bool _testConnectionSuccess = false;

  bool _isCheckingUpdates = false;
  UpdateCheckResult? _manualCheckResult;

  @override
  void initState() {
    super.initState();
    final cfg = _otaService.config;
    _serverPathController = TextEditingController(text: cfg.serverPath);
    _usernameController = TextEditingController(text: cfg.username);
    _passwordController = TextEditingController(text: cfg.password);
    _checkInterval = cfg.checkInterval;
  }

  @override
  void dispose() {
    _serverPathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentConfig() async {
    final updated = _otaService.config.copyWith(
      serverPath: _serverPathController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      checkInterval: _checkInterval,
    );
    await _otaService.saveExternalConfigFile(updated);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _testConnectionResult = null;
    });

    await _saveCurrentConfig();

    final success = await _otaService.connectSmbShare(
      path: _serverPathController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testConnectionSuccess = success;
        _testConnectionResult = success
            ? widget.language.t('ota_connection_ok')
            : widget.language.t('ota_connection_failed');
      });
    }
  }

  Future<void> _checkForUpdatesManually() async {
    setState(() {
      _isCheckingUpdates = true;
      _manualCheckResult = null;
    });

    await _saveCurrentConfig();

    final result = await _otaService.checkForUpdates(
      overrideServerPath: _serverPathController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isCheckingUpdates = false;
        _manualCheckResult = result;
      });

      if (result.hasUpdate && result.packageInfo != null) {
        showGlassUpdateDialog(
          context: context,
          packageInfo: result.packageInfo!,
        );
      }
    }
  }

  void _openConfigFolder() {
    final file = _otaService.getConfigFile();
    final dir = file.parent;
    if (Platform.isWindows) {
      Process.run('explorer.exe', [dir.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final lang = widget.language;
    final cfg = _otaService.config;

    final lastCheckStr = cfg.lastCheckTime != null
        ? '${cfg.lastCheckTime!.hour.toString().padLeft(2, '0')}:${cfg.lastCheckTime!.minute.toString().padLeft(2, '0')} ${cfg.lastCheckTime!.day.toString().padLeft(2, '0')}/${cfg.lastCheckTime!.month.toString().padLeft(2, '0')}/${cfg.lastCheckTime!.year}'
        : lang.t('ota_never_checked');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Current Version & Quick Check Card
          _OtaVersionStatusCard(
            colors: colors,
            language: lang,
            lastCheckStr: lastCheckStr,
            isCheckingUpdates: _isCheckingUpdates,
            manualCheckResult: _manualCheckResult,
            onCheckNow: _checkForUpdatesManually,
          ),
          const SizedBox(height: 16),

          // 2. Server Share Configuration Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('ota_server_path'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _serverPathController,
                  onChanged: (_) => _saveCurrentConfig(),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.textPrimary,
                    fontFamily: 'JetBrains Mono',
                  ),
                  decoration: InputDecoration(
                    hintText: lang.t('ota_server_path_hint'),
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      color: colors.textMuted.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: colors.cardHoverBg.withValues(alpha: 0.25),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: colors.subCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: colors.subCardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: colors.accentCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Username and Password in 2 columns
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.t('ota_username'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _usernameController,
                            onChanged: (_) => _saveCurrentConfig(),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'user',
                              filled: true,
                              fillColor: colors.cardHoverBg.withValues(
                                alpha: 0.25,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colors.subCardBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colors.subCardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colors.accentCyan,
                                ),
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
                            lang.t('ota_password'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            onChanged: (_) => _saveCurrentConfig(),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '••••••',
                              filled: true,
                              fillColor: colors.cardHoverBg.withValues(
                                alpha: 0.25,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colors.subCardBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colors.subCardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colors.accentCyan,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Check Interval Selector
                Row(
                  children: [
                    Text(
                      lang.t('ota_interval'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: colors.cardHoverBg.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.subCardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _checkInterval,
                          dropdownColor: colors.cardBg,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text(lang.t('ota_interval_daily')),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text(lang.t('ota_interval_weekly')),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text(lang.t('ota_interval_monthly')),
                            ),
                            DropdownMenuItem(
                              value: 'off',
                              child: Text(lang.t('ota_interval_off')),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _checkInterval = val);
                              _saveCurrentConfig();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Actions: Test Connection & Open Config Folder
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isTestingConnection ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accentCyan,
                        side: BorderSide(
                          color: colors.accentCyan.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isTestingConnection
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find_rounded, size: 15),
                      label: Text(
                        _isTestingConnection
                            ? lang.t('ota_testing_connection')
                            : lang.t('ota_test_connection'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openConfigFolder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.subCardBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_rounded, size: 15),
                      label: Text(
                        lang.t('ota_open_config_dir'),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),

                // Connection test result
                if (_testConnectionResult != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _testConnectionSuccess
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 15,
                        color: _testConnectionSuccess
                            ? colors.accentEmerald
                            : colors.accentRose,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _testConnectionResult!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _testConnectionSuccess
                                ? colors.accentEmerald
                                : colors.accentRose,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
