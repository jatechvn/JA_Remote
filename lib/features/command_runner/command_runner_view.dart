import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../data/models/command_template.dart';
import '../../data/models/managed_device.dart';
import '../../data/models/saved_credential.dart';
import '../../data/repositories/credential_repository.dart';
import '../../services/device_service.dart';
import '../../services/remote_command_service.dart';

class CommandRunnerView extends StatefulWidget {
  const CommandRunnerView({super.key});

  @override
  State<CommandRunnerView> createState() => _CommandRunnerViewState();
}

class _CommandRunnerViewState extends State<CommandRunnerView> {
  final _commandController = TextEditingController();
  final _usernameController = TextEditingController(text: 'Administrator');
  final _passwordController = TextEditingController();
  final _commandService = RemoteCommandService();
  final _credRepo = CredentialRepository();
  final _terminalController = GlassTerminalController();

  List<CommandTemplate> _templates = [];
  CommandTemplate? _selectedTemplate;

  String _protocol = 'powershell'; // 'powershell' or 'ssh'
  bool _targetSelectedOnly = true;
  String? _singleTargetId;

  bool _isExecuting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _templates = CommandTemplate.getDefaultTemplates();
    if (_templates.isNotEmpty) {
      _applyTemplate(_templates.first);
    }
    _credRepo.loadCredentials().then((creds) {
      if (mounted && creds.isNotEmpty && _passwordController.text.isEmpty) {
        setState(() {
          _usernameController.text = creds.first.username;
          _passwordController.text = creds.first.password;
        });
      }
    });
  }

  void _applyTemplate(CommandTemplate tmpl) {
    setState(() {
      _selectedTemplate = tmpl;
      _commandController.text = tmpl.command;
      _protocol = tmpl.type;
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showWinRmGuide(
    BuildContext context,
    AppColors colors,
    LanguageProvider language,
  ) {
    final theme = context.read<ThemeProvider>();
    const script =
        'Enable-PSRemoting -Force; Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord; Restart-Service WinRM';

    showGlassDialog(
      context: context,
      colors: colors,
      title: language.t('cmd_winrm_guide_title'),
      icon: Icons.electrical_services_rounded,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Để điều khiển máy trạm từ xa qua mạng LAN (Workgroup / Non-domain), trên MÁY ĐÍCH (Target PC) cần mở PowerShell quyền Administrator và chạy lệnh sau:',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? const Color(0xF40A0E17)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.isDark
                    ? const Color(0x3894A3B8)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    script,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Consolas', 'monospace'],
                      fontSize: 11.5,
                      height: 1.4,
                      color: theme.isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.content_copy_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: script));
                    showAppToast(
                      context,
                      colors: colors,
                      message: 'Đã sao chép lệnh WinRM!',
                      icon: Icons.check_circle_rounded,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• Lệnh trên sẽ: Bật dịch vụ WinRM (Port 5985) + Mở Firewall + Cấp quyền cho tài khoản Local Admin điều khiển từ xa (LocalAccountTokenFilterPolicy).'
            '\n• Sau khi chạy lệnh trên, nhập Tài khoản & Mật khẩu của máy đó vào ô Xác thực bên trái để thực thi.',
            style: TextStyle(
              fontSize: 11,
              color: colors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        GlassButton(
          label: 'Đóng',
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: 'Sao chép lệnh (Copy)',
          icon: Icons.copy_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: () {
            Clipboard.setData(const ClipboardData(text: script));
            Navigator.pop(context);
            showAppToast(
              context,
              colors: colors,
              message: 'Đã sao chép script WinRM vào Clipboard!',
              icon: Icons.check_circle_rounded,
            );
          },
        ),
      ],
    );
  }

  Future<void> _execute() async {
    if (_isExecuting) return;
    final deviceService = context.read<DeviceService>();
    final List<ManagedDevice> targets = [];

    if (_targetSelectedOnly) {
      targets.addAll(deviceService.selectedDevices);
      if (targets.isEmpty) {
        final language = context.read<LanguageProvider>();
        showAppToast(
          context,
          colors: context.read<ThemeProvider>().colors,
          message: language.t('cmd_no_device_selected'),
          icon: Icons.warning_rounded,
          accentColor: Colors.amber,
        );
        return;
      }
    } else {
      final matching = deviceService.devices.where(
        (d) => d.id == _singleTargetId,
      );
      if (matching.isEmpty) {
        showAppToast(
          context,
          colors: context.read<ThemeProvider>().colors,
          message: context.read<LanguageProvider>().t('cmd_no_device_selected'),
          icon: Icons.warning_rounded,
          accentColor: Colors.amber,
        );
        return;
      }
      targets.add(matching.first);
    }

    final script = _commandController.text.trim();
    if (script.isEmpty) return;

    final language = context.read<LanguageProvider>();

    setState(() {
      _isExecuting = true;
    });

    _terminalController.appendLine(
      language.t('terminal_batch_starting', {
        'count': '${targets.length}',
        'protocol': _protocol.toUpperCase(),
      }),
      type: TerminalLineType.system,
    );
    _terminalController.appendLine('➜ $script', type: TerminalLineType.command);

    final results = await _commandService.executeBatch(
      devices: targets,
      command: script,
      typeOverride: _protocol,
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
      onProgress: (completed, total, res) {
        if (!mounted) return;
        if (res.isSuccess) {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] — ${language.t('terminal_device_success', {'ms': '${res.durationMs}'})}',
            type: TerminalLineType.success,
          );
          if (res.output.trim().isNotEmpty) {
            for (final line in res.output.trim().split('\n')) {
              _terminalController.appendLine(
                line,
                type: TerminalLineType.output,
              );
            }
          }
        } else {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] — ${language.t('terminal_device_failed', {'ms': '${res.durationMs}'})}',
            type: TerminalLineType.error,
          );
          if (res.error.trim().isNotEmpty) {
            for (final line in res.error.trim().split('\n')) {
              _terminalController.appendLine(
                line,
                type: TerminalLineType.error,
              );
            }
          }
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _isExecuting = false;
    });

    final successCount = results.where((r) => r.isSuccess).length;
    _terminalController.appendLine(
      language.t('terminal_batch_complete', {
        'success': '$successCount',
        'total': '${results.length}',
      }),
      type: successCount == results.length
          ? TerminalLineType.success
          : TerminalLineType.warn,
    );

    if (_passwordController.text.isNotEmpty) {
      await _credRepo.recordCredential(
        _usernameController.text.trim().isEmpty
            ? 'Administrator'
            : _usernameController.text.trim(),
        _passwordController.text,
        label: targets.length == 1 ? targets.first.name : null,
      );
    }
  }

  Future<String?> _handleTerminalCommand(String rawCmd) async {
    final cmd = rawCmd.trim();
    if (cmd.isEmpty) return null;

    final parts = cmd.split(RegExp(r'\s+'));
    final mainCmd = parts.first.toLowerCase();
    if (const [
      'help',
      'status',
      'matrix',
      'clear',
      'cls',
      'theme',
      'date',
      'time',
      'version',
      'nodes',
      'devices',
    ].contains(mainCmd)) {
      return null; // Let built-in terminal mock commands handle it
    }

    final deviceService = context.read<DeviceService>();
    final List<ManagedDevice> targets = [];
    if (_targetSelectedOnly) {
      targets.addAll(deviceService.selectedDevices);
    } else {
      if (_singleTargetId != null) {
        final dev = deviceService.devices.firstWhere(
          (d) => d.id == _singleTargetId,
          orElse: () => deviceService.devices.first,
        );
        targets.add(dev);
      } else if (deviceService.devices.isNotEmpty) {
        targets.add(deviceService.devices.first);
      }
    }

    final language = context.read<LanguageProvider>();

    if (targets.isEmpty) {
      return language.t('terminal_no_target_selected');
    }

    _terminalController.appendLine(
      language.t('terminal_sending_direct', {
        'count': '${targets.length}',
        'protocol': _protocol.toUpperCase(),
        'cmd': cmd,
      }),
      type: TerminalLineType.system,
    );

    final results = await _commandService.executeBatch(
      devices: targets,
      command: cmd,
      typeOverride: _protocol,
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
      onProgress: (completed, total, res) {
        if (res.isSuccess) {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] (${res.durationMs}ms):',
            type: TerminalLineType.success,
          );
          if (res.output.trim().isNotEmpty) {
            for (final line in res.output.trim().split('\n')) {
              _terminalController.appendLine(
                line,
                type: TerminalLineType.output,
              );
            }
          }
        } else {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] ${language.t('terminal_error_label')} (${res.durationMs}ms):',
            type: TerminalLineType.error,
          );
          if (res.error.trim().isNotEmpty) {
            for (final line in res.error.trim().split('\n')) {
              _terminalController.appendLine(
                line,
                type: TerminalLineType.error,
              );
            }
          }
        }
      },
    );

    final successCount = results.where((r) => r.isSuccess).length;
    return language.t('terminal_direct_complete', {
      'success': '$successCount',
      'total': '${results.length}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final language = context.watch<LanguageProvider>();
    final deviceService = context.watch<DeviceService>();
    final selectedCount = deviceService.selectedIds.length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
          includeRepeats: false,
        ): () {
          if (!_isExecuting) _execute();
        },
      },
      child: Focus(
        autofocus: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Command & Target Configuration
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    colors: colors,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.terminal_rounded,
                              color: colors.accentPurple,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              language.t('cmd_config_title'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Target Selector
                        Text(
                          language.t('cmd_target_label'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildTargetChip(
                              selected: _targetSelectedOnly,
                              label: language.t('cmd_target_selected', {
                                'count': selectedCount.toString(),
                              }),
                              icon: Icons.checklist_rounded,
                              onTap: () =>
                                  setState(() => _targetSelectedOnly = true),
                              colors: colors,
                            ),
                            const SizedBox(width: 10),
                            _buildTargetChip(
                              selected: !_targetSelectedOnly,
                              label: language.t('cmd_target_single'),
                              icon: Icons.computer_rounded,
                              onTap: () =>
                                  setState(() => _targetSelectedOnly = false),
                              colors: colors,
                            ),
                          ],
                        ),

                        if (!_targetSelectedOnly &&
                            deviceService.devices.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: GlassDropdown<String>(
                              colors: colors,
                              items: deviceService.devices.map((d) {
                                return GlassDropdownItem<String>(
                                  value: d.id,
                                  label: d.name,
                                  subtitle: '${d.ip} • ${d.hostname}',
                                  icon: d.online
                                      ? Icons.desktop_windows_rounded
                                      : Icons.desktop_access_disabled_rounded,
                                  badge: d.online ? 'ONLINE' : 'OFFLINE',
                                  accentColor: d.online
                                      ? colors.accentEmerald
                                      : colors.accentRose,
                                );
                              }).toList(),
                              value:
                                  _singleTargetId ??
                                  deviceService.devices.first.id,
                              hintText: 'Chọn máy trạm...',
                              enableSearch: deviceService.devices.length > 5,
                              borderRadius: 10,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              onChanged: (val) {
                                setState(() => _singleTargetId = val);
                                final dev = deviceService.devices.firstWhere(
                                  (d) => d.id == val,
                                  orElse: () => deviceService.devices.first,
                                );
                                if (dev.username != null &&
                                    dev.username!.isNotEmpty) {
                                  _usernameController.text = dev.username!;
                                }
                                if (dev.password != null &&
                                    dev.password!.isNotEmpty) {
                                  _passwordController.text = dev.password!;
                                }
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Preset Templates Dropdown
                        Text(
                          language.t('cmd_template_label'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: GlassDropdown<CommandTemplate>(
                            colors: colors,
                            items: _templates.map((tmpl) {
                              final isWin = tmpl.platform == 'windows';
                              return GlassDropdownItem<CommandTemplate>(
                                value: tmpl,
                                label: tmpl.name,
                                subtitle: tmpl.description.isNotEmpty
                                    ? tmpl.description
                                    : tmpl.command,
                                icon: isWin
                                    ? Icons.desktop_windows_rounded
                                    : Icons.terminal_rounded,
                                badge: tmpl.platform.toUpperCase(),
                                accentColor: isWin
                                    ? colors.accentCyan
                                    : colors.accentAmber,
                              );
                            }).toList(),
                            value: _selectedTemplate,
                            hintText: 'Chọn kịch bản lệnh mẫu...',
                            enableSearch: _templates.length > 5,
                            borderRadius: 10,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            onChanged: (tmpl) {
                              _applyTemplate(tmpl);
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Protocol Selector (PowerShell vs SSH)
                        Text(
                          language.t('cmd_protocol_label'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildProtocolChip(
                              'powershell',
                              'PowerShell (WinRM / Local)',
                              Icons.window_rounded,
                              colors,
                            ),
                            const SizedBox(width: 10),
                            _buildProtocolChip(
                              'ssh',
                              'SSH Client',
                              Icons.terminal_rounded,
                              colors,
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Remote Credentials Row
                        Row(
                          children: [
                            Text(
                              language.t('cmd_auth_title'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () =>
                                  _showWinRmGuide(context, colors, language),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.help_outline_rounded,
                                      size: 14,
                                      color: colors.accentCyan,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      language.t('cmd_winrm_guide_btn'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.accentCyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Username
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _usernameController,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: language.t('cmd_auth_user_hint'),
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      size: 16,
                                      color: colors.textMuted,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    filled: true,
                                    fillColor: colors.cardBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colors.cardBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colors.cardBorder,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Password
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: language.t('cmd_auth_pass_hint'),
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 16,
                                      color: colors.textMuted,
                                    ),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 16,
                                            color: colors.textMuted,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                        PopupMenuButton<SavedCredential>(
                                          icon: Icon(
                                            Icons.vpn_key_rounded,
                                            size: 16,
                                            color: colors.accentAmber,
                                          ),
                                          tooltip: language.t(
                                            'cmd_saved_passwords',
                                          ),
                                          color: theme.isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFFFFFFF),
                                          surfaceTintColor: Colors.transparent,
                                          elevation: 10,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: theme.isDark
                                                  ? const Color(0x38FFFFFF)
                                                  : const Color(0x29000000),
                                            ),
                                          ),
                                          onSelected: (cred) {
                                            setState(() {
                                              _usernameController.text =
                                                  cred.username;
                                              _passwordController.text =
                                                  cred.password;
                                            });
                                            showAppToast(
                                              context,
                                              colors: colors,
                                              message: language.t(
                                                'cmd_toast_selected_cred',
                                                {'username': cred.username},
                                              ),
                                              icon: Icons.vpn_key_rounded,
                                            );
                                          },
                                          itemBuilder: (ctx) {
                                            final list = _credRepo.credentials;
                                            if (list.isEmpty) {
                                              return [
                                                PopupMenuItem(
                                                  enabled: false,
                                                  child: Text(
                                                    language.t(
                                                      'cmd_no_saved_passwords',
                                                    ),
                                                    style: TextStyle(
                                                      color: colors.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ];
                                            }
                                            return list.map((c) {
                                              return PopupMenuItem<
                                                SavedCredential
                                              >(
                                                value: c,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.key_rounded,
                                                      size: 14,
                                                      color: colors.accentAmber,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            c.label != null &&
                                                                    c
                                                                        .label!
                                                                        .isNotEmpty
                                                                ? '${c.username} (${c.label})'
                                                                : c.username,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: colors
                                                                  .textPrimary,
                                                            ),
                                                          ),
                                                          Text(
                                                            '●●●●●●●● (${c.lastUsed.hour.toString().padLeft(2, '0')}:${c.lastUsed.minute.toString().padLeft(2, '0')})',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: colors
                                                                  .textMuted,
                                                              fontFamily:
                                                                  'monospace',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList();
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    filled: true,
                                    fillColor: colors.cardBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colors.cardBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colors.cardBorder,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Command Editor Label
                        Text(
                          language.t('cmd_content_label'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Bento Glassmorphic Script Editor (Sync with Terminal Engine)
                        GlassScriptEditor(
                          controller: _commandController,
                          protocol: _protocol,
                          hintText: language.t('cmd_script_hint'),
                          minLines: 5,
                          maxLines: 7,
                          quickSnippets: _protocol == 'powershell'
                              ? const [
                                  GlassScriptSnippet(
                                    label: 'Uptime',
                                    command:
                                        '(get-date) - (gcim Win32_OperatingSystem).LastBootUpTime',
                                    icon: Icons.timer_outlined,
                                  ),
                                  GlassScriptSnippet(
                                    label: 'IPConfig',
                                    command: 'ipconfig /all',
                                    icon: Icons.lan_outlined,
                                  ),
                                  GlassScriptSnippet(
                                    label: 'Disk Free',
                                    command:
                                        'Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N="Free(GB)";E={[math]::round(\$_.Free/1GB,2)}}',
                                    icon: Icons.pie_chart_outline_rounded,
                                  ),
                                  GlassScriptSnippet(
                                    label: 'Reboot',
                                    command: 'Restart-Computer -Force',
                                    icon: Icons.restart_alt_rounded,
                                  ),
                                ]
                              : const [
                                  GlassScriptSnippet(
                                    label: 'uptime',
                                    command: 'uptime',
                                    icon: Icons.timer_outlined,
                                  ),
                                  GlassScriptSnippet(
                                    label: 'ip a',
                                    command: 'ip -brief address',
                                    icon: Icons.lan_outlined,
                                  ),
                                  GlassScriptSnippet(
                                    label: 'df -h',
                                    command: 'df -h',
                                    icon: Icons.pie_chart_outline_rounded,
                                  ),
                                  GlassScriptSnippet(
                                    label: 'reboot',
                                    command: 'sudo reboot',
                                    icon: Icons.restart_alt_rounded,
                                  ),
                                ],
                        ),

                        const SizedBox(height: 16),

                        // Run Button (Glowing Bento Glass Button)
                        SizedBox(
                          width: double.infinity,
                          child: GlowingActionButton(
                            colors: colors,
                            height: 44,
                            icon: _isExecuting
                                ? Icons.hourglass_top_rounded
                                : Icons.play_arrow_rounded,
                            label: _isExecuting
                                ? language.t('cmd_btn_running')
                                : language.t('cmd_btn_run'),
                            customStartColor: colors.accentPurple,
                            customEndColor: colors.accentCyan,
                            onPressed: _isExecuting ? null : _execute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right Column: Professional High-Contrast Glass Terminal Panel (from JA_Mini_Showcase)
            Expanded(
              flex: 6,
              child: GlassTerminalPanel(
                key: ValueKey(
                  'CommandRunnerTerminal_${language.currentLanguage.code}',
                ),
                controller: _terminalController,
                terminalTitle: 'console@ja-remote: ~ ($_protocol)',
                initialWelcomeText:
                    '${language.t('terminal_welcome_banner')}\n'
                    '${language.t('terminal_welcome_desc')}',
                quickCommands: const [
                  'help',
                  'status',
                  'hostname',
                  'ipconfig',
                  'uptime',
                  'matrix',
                  'clear',
                ],
                onCommand: _handleTerminalCommand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetChip({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required dynamic colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentPurple.withValues(alpha: 0.18)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colors.accentPurple : colors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? colors.accentPurple : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? colors.accentPurple : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolChip(
    String val,
    String label,
    IconData icon,
    dynamic colors,
  ) {
    final isSelected = _protocol == val;
    return InkWell(
      onTap: () => setState(() => _protocol = val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accentPurple.withValues(alpha: 0.2)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.accentPurple : colors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.accentPurple : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colors.accentPurple : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
