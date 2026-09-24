import 'dart:math' as math;
import '../../widgets/route_shortcuts.dart';
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
import '../../data/repositories/command_template_repository.dart';
import '../../services/device_service.dart';
import '../../services/remote_command_service.dart';
import '../../services/config_backup_service.dart';
import '../../core/utils/command_variable_resolver.dart';
import '../../core/utils/file_dialog_helper.dart';

class CommandRunnerView extends StatefulWidget {
  final bool isActive;
  const CommandRunnerView({super.key, this.isActive = false});

  @override
  State<CommandRunnerView> createState() => _CommandRunnerViewState();
}

class _CommandRunnerViewState extends State<CommandRunnerView> {
  final _commandController = TextEditingController();
  final _usernameController = TextEditingController(text: 'Administrator');
  final _passwordController = TextEditingController();
  final _commandService = RemoteCommandService();
  final _credRepo = CredentialRepository();
  final _templateRepo = CommandTemplateRepository();
  final _terminalController = GlassTerminalController();
  final _scriptFocus = FocusNode();
  final _terminalPromptFocus = FocusNode();

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
    _loadTemplates();
    _credRepo.loadCredentials().then((creds) {
      if (mounted && creds.isNotEmpty && _passwordController.text.isEmpty) {
        setState(() {
          _usernameController.text = creds.first.username;
          _passwordController.text = creds.first.password;
        });
      }
    });
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusRemoteCommandPrompt();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CommandRunnerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusRemoteCommandPrompt();
      });
    }
  }

  void _focusRemoteCommandPrompt() {
    if (!mounted) return;
    _terminalPromptFocus.requestFocus();
  }

  Future<void> _loadTemplates() async {
    final list = await _templateRepo.loadTemplates();
    if (!mounted) return;
    setState(() {
      _templates = list;
      if (_selectedTemplate == null ||
          !_templates.any((t) => t.id == _selectedTemplate?.id)) {
        if (_templates.isNotEmpty) {
          _applyTemplate(_templates.first);
        }
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
    _scriptFocus.dispose();
    _terminalPromptFocus.dispose();
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
          Text(
            language.t('cmd_winrm_intro'),
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
                  tooltip: language.t('cmd_copy_command'),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: script));
                    showAppToast(
                      context,
                      colors: colors,
                      message: language.t('cmd_winrm_copied'),
                      icon: Icons.check_circle_rounded,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            language.t('cmd_winrm_details'),
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
          label: language.t('ui_close'),
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('cmd_copy_command'),
          icon: Icons.copy_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: () {
            Clipboard.setData(const ClipboardData(text: script));
            Navigator.pop(context);
            showAppToast(
              context,
              colors: colors,
              message: language.t('cmd_winrm_script_copied'),
              icon: Icons.check_circle_rounded,
            );
          },
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentCyan.withValues(alpha: 0.2)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? colors.accentCyan : colors.cardBorder,
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colors.accentCyan : colors.textMuted,
          ),
        ),
      ),
    );
  }

  void _showSaveTemplateDialog(
    BuildContext context,
    AppColors colors,
    LanguageProvider language, {
    CommandTemplate? editTemplate,
  }) {
    final firstLine = _commandController.text.trim().split('\n').first.trim();
    final defaultName = firstLine.length > 30
        ? firstLine.substring(0, 30)
        : firstLine;
    final nameCtrl = TextEditingController(
      text:
          editTemplate?.name ??
          (defaultName.isNotEmpty ? defaultName : language.t('cmd_new_script')),
    );
    final descCtrl = TextEditingController(
      text: editTemplate?.description ?? '',
    );
    String platform =
        editTemplate?.platform ??
        (_protocol == 'powershell' ? 'windows' : 'linux');
    String type = editTemplate?.type ?? _protocol;
    final cmdCtrl = TextEditingController(
      text: editTemplate?.command ?? _commandController.text,
    );

    showGlassDialog(
      context: context,
      colors: colors,
      title: editTemplate != null
          ? language.t('cmd_edit_script')
          : language.t('cmd_template_save_title'),
      icon: Icons.bookmark_add_rounded,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return SizedBox(
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  language.t('cmd_template_name_label'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(fontSize: 12, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: language.t('cmd_name_hint'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: colors.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  language.t('cmd_template_desc_label'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(fontSize: 12, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: language.t('cmd_description_hint'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: colors.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language.t('cmd_template_platform_label'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildChoiceChip(
                                label: 'Windows',
                                selected: platform == 'windows',
                                colors: colors,
                                onTap: () => setDialogState(() {
                                  platform = 'windows';
                                  type = 'powershell';
                                }),
                              ),
                              const SizedBox(width: 8),
                              _buildChoiceChip(
                                label: 'Linux',
                                selected: platform == 'linux',
                                colors: colors,
                                onTap: () => setDialogState(() {
                                  platform = 'linux';
                                  type = 'ssh';
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              _buildChoiceChip(
                                label: 'PowerShell',
                                selected: type == 'powershell',
                                colors: colors,
                                onTap: () =>
                                    setDialogState(() => type = 'powershell'),
                              ),
                              const SizedBox(width: 8),
                              _buildChoiceChip(
                                label: 'SSH',
                                selected: type == 'ssh',
                                colors: colors,
                                onTap: () => setDialogState(() => type = 'ssh'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  language.t('cmd_content_label'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: cmdCtrl,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: language.t('cmd_content_hint'),
                    contentPadding: const EdgeInsets.all(10),
                    filled: true,
                    fillColor: colors.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.cardBorder),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        GlassButton(
          label: language.t('ui_cancel'),
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('ui_json_save'),
          icon: Icons.check_circle_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: () async {
            final name = nameCtrl.text.trim().isEmpty
                ? language.t('cmd_custom_command')
                : nameCtrl.text.trim();
            final cmd = cmdCtrl.text.trim();
            if (cmd.isEmpty) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('cmd_empty_command'),
                icon: Icons.warning_rounded,
                accentColor: colors.accentAmber,
              );
              return;
            }

            final id =
                editTemplate?.id ??
                'custom_${DateTime.now().millisecondsSinceEpoch}';
            final newTmpl = CommandTemplate(
              id: id,
              name: name,
              platform: platform,
              type: type,
              command: cmd,
              description: descCtrl.text.trim(),
              isCustom: true,
            );

            await _templateRepo.saveTemplate(newTmpl);
            if (context.mounted) {
              Navigator.pop(context);
            }
            await _loadTemplates();
            setState(() {
              _applyTemplate(newTmpl);
            });

            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('cmd_template_saved_toast', {'name': name}),
                icon: Icons.bookmark_added_rounded,
                accentColor: colors.accentEmerald,
              );
            }
          },
        ),
      ],
    );
  }

  void _deleteCurrentTemplate(
    BuildContext context,
    AppColors colors,
    LanguageProvider language,
  ) {
    if (_selectedTemplate == null) return;
    final tmpl = _selectedTemplate!;

    showGlassDialog(
      context: context,
      colors: colors,
      title: language.t('cmd_template_delete_btn'),
      icon: Icons.delete_outline_rounded,
      content: Text(
        language.t('cmd_template_delete_confirm', {'name': tmpl.name}),
        style: const TextStyle(fontSize: 12),
      ),
      actions: [
        GlassButton(
          label: language.t('ui_cancel'),
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('ui_delete'),
          icon: Icons.delete_forever_rounded,
          colors: colors,
          accentColor: colors.accentRose,
          onTap: () async {
            Navigator.pop(context);
            await _templateRepo.deleteTemplate(tmpl.id);
            await _loadTemplates();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('cmd_template_deleted_toast', {
                  'name': tmpl.name,
                }),
                icon: Icons.delete_rounded,
                accentColor: colors.accentRose,
              );
            }
          },
        ),
      ],
    );
  }

  void _resetDefaultTemplates(
    BuildContext context,
    AppColors colors,
    LanguageProvider language,
  ) {
    showGlassDialog(
      context: context,
      colors: colors,
      title: language.t('cmd_template_reset'),
      icon: Icons.restore_rounded,
      content: Text(
        language.t('cmd_template_reset_confirm'),
        style: const TextStyle(fontSize: 12),
      ),
      actions: [
        GlassButton(
          label: language.t('ui_cancel'),
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('ui_restore'),
          icon: Icons.refresh_rounded,
          colors: colors,
          accentColor: colors.accentAmber,
          onTap: () async {
            Navigator.pop(context);
            await _templateRepo.resetToDefaults();
            await _loadTemplates();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('cmd_restored'),
                icon: Icons.check_circle_rounded,
                accentColor: colors.accentEmerald,
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _exportTemplates(
    BuildContext context,
    AppColors colors,
    LanguageProvider language,
  ) async {
    final path = await FileDialogHelper.pickSaveFile(
      defaultFileName: 'ja_remote_command_templates.json',
      title: language.t('cmd_template_export'),
    );
    if (path == null) return;

    try {
      final count = await ConfigBackupService().exportCommandTemplates(path);
      if (context.mounted) {
        showAppToast(
          context,
          colors: colors,
          message: language.t('cmd_exported', {'count': '$count'}),
          icon: Icons.check_circle_rounded,
          accentColor: colors.accentEmerald,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(
          context,
          colors: colors,
          message: language.t('cmd_export_error', {'error': '$e'}),
          icon: Icons.error_outline_rounded,
          accentColor: colors.accentRose,
        );
      }
    }
  }

  Future<void> _importTemplates(
    BuildContext context,
    AppColors colors,
    LanguageProvider language,
  ) async {
    final path = await FileDialogHelper.pickOpenFile(
      title: language.t('cmd_template_import'),
    );
    if (path == null) return;

    final preview = await ConfigBackupService().previewConfigFile(path);
    if (!preview.isValid || preview.commandTemplates.isEmpty) {
      if (context.mounted) {
        showAppToast(
          context,
          colors: colors,
          message: preview.commandTemplates.isEmpty
              ? language.t('cmd_no_templates')
              : (preview.error ?? language.t('cmd_json_error')),
          icon: Icons.error_outline_rounded,
          accentColor: colors.accentRose,
        );
      }
      return;
    }

    if (!context.mounted) return;

    showGlassDialog(
      context: context,
      colors: colors,
      title: language.t('cmd_template_import'),
      icon: Icons.file_download_rounded,
      content: Text(
        language.t('cmd_import_choice', {
          'count': '${preview.commandTemplates.length}',
        }),
        style: const TextStyle(fontSize: 12),
      ),
      actions: [
        GlassButton(
          label: language.t('ui_cancel'),
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const Spacer(),
        GlassButton(
          label: language.t('ui_merge'),
          icon: Icons.merge_type_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: () async {
            Navigator.pop(context);
            await ConfigBackupService().applyImport(
              preview.templatesOnly,
              overwrite: false,
            );
            await _loadTemplates();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('cmd_merged', {
                  'count': '${preview.commandTemplates.length}',
                }),
                icon: Icons.check_circle_rounded,
                accentColor: colors.accentEmerald,
              );
            }
          },
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('ui_overwrite'),
          icon: Icons.refresh_rounded,
          colors: colors,
          accentColor: colors.accentAmber,
          onTap: () async {
            Navigator.pop(context);
            await ConfigBackupService().applyImport(
              preview.templatesOnly,
              overwrite: true,
            );
            await _loadTemplates();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('cmd_overwritten', {
                  'count': '${preview.commandTemplates.length}',
                }),
                icon: Icons.check_circle_rounded,
                accentColor: colors.accentEmerald,
              );
            }
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
    final runUsername = _usernameController.text.trim();
    final runPassword = _passwordController.text;

    setState(() {
      _isExecuting = true;
    });

    final concurrency = targets.length >= 10
        ? math.min(targets.length, 30)
        : math.max(1, targets.length);

    _terminalController.appendLine(
      '${language.t('terminal_batch_starting', {'count': '${targets.length}', 'protocol': _protocol.toUpperCase()})} • [${language.t('cmd_workers', {'count': '$concurrency'})}]',
      type: TerminalLineType.system,
    );
    _terminalController.appendLine('➜ $script', type: TerminalLineType.command);

    final results = await _commandService.executeBatch(
      devices: targets,
      command: script,
      typeOverride: _protocol,
      username: runUsername.isEmpty ? null : runUsername,
      password: runPassword.isEmpty ? null : runPassword,
      maxConcurrent: concurrency,
      onProgress: (completed, total, res) {
        if (!mounted) return;
        if (res.isSuccess) {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] — ${language.t('terminal_device_success', {'ms': '${res.durationMs}'})}',
            type: TerminalLineType.success,
          );
          if (res.output.trim().isNotEmpty) {
            _terminalController.appendLines(
              res.output.trim().split('\n'),
              type: TerminalLineType.output,
            );
          }
        } else {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] — ${language.t('terminal_device_failed', {'ms': '${res.durationMs}'})}',
            type: TerminalLineType.error,
          );
          if (res.error.trim().isNotEmpty) {
            _terminalController.appendLines(
              res.error.trim().split('\n'),
              type: TerminalLineType.error,
            );
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

    if (runPassword.isNotEmpty) {
      await _credRepo.recordCredential(
        runUsername.isEmpty ? 'Administrator' : runUsername,
        runPassword,
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
      targets.addAll(
        deviceService.devices.where((d) => d.id == _singleTargetId),
      );
    }

    final language = context.read<LanguageProvider>();

    if (targets.isEmpty) {
      return language.t('terminal_no_target_selected');
    }

    final concurrency = targets.length >= 10
        ? math.min(targets.length, 30)
        : math.max(1, targets.length);

    _terminalController.appendLine(
      '${language.t('terminal_sending_direct', {'count': '${targets.length}', 'protocol': _protocol.toUpperCase(), 'cmd': cmd})} • [${language.t('cmd_workers', {'count': '$concurrency'})}]',
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
      maxConcurrent: concurrency,
      onProgress: (completed, total, res) {
        if (!mounted) return;
        if (res.isSuccess) {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] (${res.durationMs}ms):',
            type: TerminalLineType.success,
          );
          if (res.output.trim().isNotEmpty) {
            _terminalController.appendLines(
              res.output.trim().split('\n'),
              type: TerminalLineType.output,
            );
          }
        } else {
          _terminalController.appendLine(
            '[${res.device.name} (${res.device.ip})] ${language.t('terminal_error_label')} (${res.durationMs}ms):',
            type: TerminalLineType.error,
          );
          if (res.error.trim().isNotEmpty) {
            _terminalController.appendLines(
              res.error.trim().split('\n'),
              type: TerminalLineType.error,
            );
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

    return RouteShortcuts(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column: Command & Target Configuration
            Expanded(
              flex: 5,
              child: GlassCard(
                colors: colors,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          color: colors.accentPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          language.t('cmd_config_title'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // HUB 1: Target Selector & Protocol Switcher (Dual-Control Row)
                    Row(
                      children: [
                        // Target Selector Segment
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: colors.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentItem(
                                    selected: _targetSelectedOnly,
                                    label: language.t('cmd_target_selected', {
                                      'count': selectedCount.toString(),
                                    }),
                                    icon: Icons.checklist_rounded,
                                    onTap: () => setState(
                                      () => _targetSelectedOnly = true,
                                    ),
                                    colors: colors,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: _buildSegmentItem(
                                    selected: !_targetSelectedOnly,
                                    label: language.t('cmd_target_single'),
                                    icon: Icons.computer_rounded,
                                    onTap: () => setState(
                                      () => _targetSelectedOnly = false,
                                    ),
                                    colors: colors,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Protocol Switcher Segment
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSegmentItem(
                                selected: _protocol == 'powershell',
                                label: 'PowerShell',
                                icon: Icons.window_rounded,
                                onTap: () =>
                                    setState(() => _protocol = 'powershell'),
                                colors: colors,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                              ),
                              const SizedBox(width: 3),
                              _buildSegmentItem(
                                selected: _protocol == 'ssh',
                                label: 'SSH',
                                icon: Icons.terminal_rounded,
                                onTap: () => setState(() => _protocol = 'ssh'),
                                colors: colors,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (!_targetSelectedOnly &&
                        deviceService.devices.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                              _singleTargetId ?? deviceService.devices.first.id,
                          hintText: language.t('cmd_choose_device'),
                          enableSearch: deviceService.devices.length > 5,
                          borderRadius: 8,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
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

                    const SizedBox(height: 8),

                    // HUB 2: Preset Templates Dropdown & Actions Toolbar
                    Row(
                      children: [
                        Expanded(
                          child: GlassDropdown<CommandTemplate>(
                            colors: colors,
                            items: _templates.map((tmpl) {
                              final isWin = tmpl.platform == 'windows';
                              return GlassDropdownItem<CommandTemplate>(
                                value: tmpl,
                                label: language.templateName(tmpl),
                                subtitle: tmpl.description.isNotEmpty
                                    ? language.templateDescription(tmpl)
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
                            hintText: language.t('cmd_template_hint'),
                            enableSearch: _templates.length > 5,
                            borderRadius: 8,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            onChanged: (tmpl) {
                              _applyTemplate(tmpl);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Save Current Command as Template Button
                        Tooltip(
                          message: language.t('cmd_template_save_title'),
                          child: InkWell(
                            onTap: () => _showSaveTemplateDialog(
                              context,
                              colors,
                              language,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentCyan.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.accentCyan.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bookmark_add_rounded,
                                    size: 15,
                                    color: colors.accentCyan,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    language.t('cmd_template_save_btn'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.accentCyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Template Options Menu
                        Container(
                          height: 36,
                          width: 32,
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 16,
                              color: colors.textMuted,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: language.t('cmd_template_manage'),
                            color: theme.isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFFFFFFF),
                            surfaceTintColor: Colors.transparent,
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: theme.isDark
                                    ? const Color(0x38FFFFFF)
                                    : const Color(0x29000000),
                              ),
                            ),
                            onSelected: (val) {
                              switch (val) {
                                case 'edit':
                                  if (_selectedTemplate != null) {
                                    _showSaveTemplateDialog(
                                      context,
                                      colors,
                                      language,
                                      editTemplate: _selectedTemplate,
                                    );
                                  }
                                  break;
                                case 'delete':
                                  _deleteCurrentTemplate(
                                    context,
                                    colors,
                                    language,
                                  );
                                  break;
                                case 'export':
                                  _exportTemplates(context, colors, language);
                                  break;
                                case 'import':
                                  _importTemplates(context, colors, language);
                                  break;
                                case 'reset':
                                  _resetDefaultTemplates(
                                    context,
                                    colors,
                                    language,
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (_selectedTemplate != null)
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                        color: colors.accentCyan,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        language.t('cmd_edit_selected'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_selectedTemplate != null)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: colors.accentRose,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        language.t('cmd_template_delete_btn'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.accentRose,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.file_upload_outlined,
                                      size: 16,
                                      color: colors.accentEmerald,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      language.t('cmd_template_export'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'import',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.file_download_outlined,
                                      size: 16,
                                      color: colors.accentCyan,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      language.t('cmd_template_import'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'reset',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.restore_rounded,
                                      size: 16,
                                      color: colors.accentAmber,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      language.t('cmd_template_reset'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.accentAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // HUB 3: Compact Credentials Row
                    Row(
                      children: [
                        // Username
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 34,
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
                                  size: 15,
                                  color: colors.textMuted,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
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
                        const SizedBox(width: 8),
                        // Password
                        Expanded(
                          flex: 6,
                          child: SizedBox(
                            height: 34,
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
                                  size: 15,
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
                                        size: 15,
                                        color: colors.textMuted,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    PopupMenuButton<SavedCredential>(
                                      icon: Icon(
                                        Icons.vpn_key_rounded,
                                        size: 15,
                                        color: colors.accentAmber,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
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
                                        borderRadius: BorderRadius.circular(10),
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
                                          return PopupMenuItem<SavedCredential>(
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
                                                              FontWeight.bold,
                                                          color: colors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                      Text(
                                                        '●●●●●●●● (${c.lastUsed.hour.toString().padLeft(2, '0')}:${c.lastUsed.minute.toString().padLeft(2, '0')})',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              colors.textMuted,
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
                                    const SizedBox(width: 2),
                                  ],
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
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
                        const SizedBox(width: 8),
                        // WinRM Guide Button
                        Tooltip(
                          message: language.t('cmd_winrm_guide_title'),
                          child: InkWell(
                            onTap: () =>
                                _showWinRmGuide(context, colors, language),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.cardBorder),
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // HUB 4: Bento Glassmorphic Script Editor (Sync with Terminal Engine)
                    Expanded(
                      child: GlassScriptEditor(
                        focusNode: _scriptFocus,
                        controller: _commandController,
                        protocol: _protocol,
                        hintText: language.t('cmd_script_hint'),
                        expands: true,
                        minLines: 8,
                        maxLines: 20,
                        quickSnippets: _protocol == 'powershell'
                            ? [
                                GlassScriptSnippet(
                                  label: language.t('snippet_uptime'),
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
                                  label: language.t('snippet_disk'),
                                  command:
                                      'Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N="Free(GB)";E={[math]::round(\$_.Free/1GB,2)}}',
                                  icon: Icons.pie_chart_outline_rounded,
                                ),
                                GlassScriptSnippet(
                                  label: language.t('snippet_reboot'),
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
                        extraFooterWidget: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            border: Border(
                              top: BorderSide(
                                color: colors.cardBorder.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.data_object_rounded,
                                  size: 13,
                                  color: colors.accentCyan,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Variables:',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                for (final v
                                    in CommandVariableResolver
                                        .availableVariables) ...[
                                  InkWell(
                                    onTap: () {
                                      final token = v['token']!;
                                      final text = _commandController.text;
                                      final selection =
                                          _commandController.selection;
                                      if (selection.start >= 0 &&
                                          selection.end >= 0) {
                                        final newText = text.replaceRange(
                                          selection.start,
                                          selection.end,
                                          token,
                                        );
                                        _commandController
                                            .value = TextEditingValue(
                                          text: newText,
                                          selection: TextSelection.collapsed(
                                            offset:
                                                selection.start + token.length,
                                          ),
                                        );
                                      } else {
                                        _commandController.text = text.isEmpty
                                            ? token
                                            : '$text $token';
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(5),
                                    child: Tooltip(
                                      message: '${v['label']}: ${v['desc']}',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.accentCyan.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          border: Border.all(
                                            color: colors.accentCyan.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          v['token']!,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: colors.accentCyan,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Run Button (Glowing Bento Glass Button) with Ctrl+Enter hint
                    SizedBox(
                      width: double.infinity,
                      child: GlowingActionButton(
                        colors: colors,
                        height: 42,
                        icon: _isExecuting
                            ? Icons.hourglass_top_rounded
                            : Icons.play_arrow_rounded,
                        label: _isExecuting
                            ? language.t('cmd_btn_running')
                            : '${language.t('cmd_btn_run')}  (Ctrl + Enter)',
                        customStartColor: colors.accentPurple,
                        customEndColor: colors.accentCyan,
                        onPressed: _isExecuting ? null : _execute,
                      ),
                    ),
                  ],
                ),
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
                promptFocusNode: _terminalPromptFocus,
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

  Widget _buildSegmentItem({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required dynamic colors,
    EdgeInsetsGeometry? padding,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentPurple.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? colors.accentPurple : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? colors.accentPurple : colors.textMuted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? colors.accentPurple : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
