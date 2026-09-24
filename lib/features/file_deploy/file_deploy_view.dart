import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/route_shortcuts.dart';
import '../../data/models/managed_device.dart';
import '../../data/repositories/credential_repository.dart';
import '../../services/device_service.dart';
import '../../services/file_deploy_service.dart';
import '../../core/utils/file_dialog_helper.dart';
import '../../data/repositories/file_deploy_history_repository.dart';
import '../../widgets/glass_deploy_dest_field.dart';
import '../../widgets/glass_dialog.dart';

class FileDeployView extends StatefulWidget {
  final bool isActive;
  const FileDeployView({super.key, this.isActive = false});

  @override
  State<FileDeployView> createState() => _FileDeployViewState();
}

class _FileDeployViewState extends State<FileDeployView> {
  final _destController = TextEditingController(text: r'C:\Temp\Deploy');
  final _usernameController = TextEditingController(text: 'Administrator');
  final _passwordController = TextEditingController();
  final _preHookController = TextEditingController();
  final _postHookController = TextEditingController();
  final _deployService = FileDeployService();
  final _credRepo = CredentialRepository();
  final _terminalController = GlassTerminalController();
  final _terminalPromptFocus = FocusNode();

  final _historyRepo = FileDeployHistoryRepository();
  List<DeploySourceItem> _sourceHistory = [];

  String? _sourcePath;
  bool _isDirectory = false;
  int _sourceSizeBytes = 0;
  int _sourceFileCount = 0;

  bool _targetSelectedOnly = true;
  bool _createDirIfMissing = true;
  bool _overwrite = true;
  bool _autoKillIfInUse = true;
  bool _abortOnPreFail = true;
  int _concurrency = 4;
  bool _obscurePassword = true;
  bool _isAuthExpanded = false;
  bool _isHooksExpanded = false;
  bool? _isTargetDevicesCollapsedByUser;

  @override
  void initState() {
    super.initState();
    _loadSavedDeployState();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _terminalPromptFocus.requestFocus();
      });
    }

    _credRepo.loadCredentials().then((creds) {
      if (mounted && creds.isNotEmpty && _passwordController.text.isEmpty) {
        setState(() {
          _usernameController.text = creds.first.username;
          _passwordController.text = creds.first.password;
        });
      }
    });

    _deployService.eventStream.listen((event) {
      _terminalController.appendLine(event);
    });

    _deployService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSavedDeployState() async {
    final savedDest = await _historyRepo.getLastDestPath();
    if (mounted) {
      _destController.text = savedDest;
    }

    final savedSource = await _historyRepo.getLastSourcePath();
    final savedIsDir = await _historyRepo.getLastSourceIsDir();
    if (savedSource != null && savedSource.trim().isNotEmpty) {
      await _loadSourceFromPath(savedSource, savedIsDir, saveToHistory: false);
    }

    await _refreshSourceHistory();
  }

  Future<void> _refreshSourceHistory() async {
    final list = await _historyRepo.getSourceHistory();
    if (mounted) {
      setState(() {
        _sourceHistory = list;
      });
    }
  }

  Future<bool> _loadSourceFromPath(
    String path,
    bool isDir, {
    bool saveToHistory = true,
  }) async {
    final clean = path.trim();
    if (clean.isEmpty) return false;

    if (isDir) {
      final dir = Directory(clean);
      if (await dir.exists()) {
        int totalSize = 0;
        int count = 0;
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            count++;
            totalSize += await entity.length();
          }
        }
        if (mounted) {
          setState(() {
            _sourcePath = clean;
            _isDirectory = true;
            _sourceSizeBytes = totalSize;
            _sourceFileCount = count;
          });
        }
        if (saveToHistory) {
          await _historyRepo.addSourceHistory(clean, true);
          await _refreshSourceHistory();
        }
        return true;
      }
    } else {
      final file = File(clean);
      if (await file.exists()) {
        final length = await file.length();
        if (mounted) {
          setState(() {
            _sourcePath = clean;
            _isDirectory = false;
            _sourceSizeBytes = length;
            _sourceFileCount = 1;
          });
        }
        if (saveToHistory) {
          await _historyRepo.addSourceHistory(clean, false);
          await _refreshSourceHistory();
        }
        return true;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant FileDeployView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _terminalPromptFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _terminalPromptFocus.dispose();
    _destController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _preHookController.dispose();
    _postHookController.dispose();
    _deployService.dispose();
    super.dispose();
  }

  Future<void> _pickFile(LanguageProvider language) async {
    final currentPath = _sourcePath;
    String? initialDir;
    if (currentPath != null && currentPath.isNotEmpty) {
      if (File(currentPath).existsSync()) {
        initialDir = File(currentPath).parent.path;
      } else if (Directory(currentPath).existsSync()) {
        initialDir = currentPath;
      }
    }
    final path = await FileDialogHelper.pickAnyFile(
      title: language.t('deploy_pick_file_title'),
      initialDirectory: initialDir,
    );
    if (path != null && mounted) {
      await _loadSourceFromPath(path, false, saveToHistory: true);
    }
  }

  Future<void> _pickFolder(LanguageProvider language) async {
    final currentPath = _sourcePath;
    String? initialDir;
    if (currentPath != null && currentPath.isNotEmpty) {
      if (Directory(currentPath).existsSync()) {
        initialDir = currentPath;
      } else if (File(currentPath).existsSync()) {
        initialDir = File(currentPath).parent.path;
      }
    }
    final path = await FileDialogHelper.pickDirectory(
      title: language.t('deploy_pick_folder_title'),
      initialDirectory: initialDir,
    );
    if (path != null && mounted) {
      await _loadSourceFromPath(path, true, saveToHistory: true);
    }
  }

  List<ManagedDevice> _resolveTargets(DeviceService deviceService) {
    if (_targetSelectedOnly) {
      return deviceService.selectedDevices;
    } else {
      return deviceService.devices.where((d) => d.online).toList();
    }
  }

  Future<void> _startDeploy(
    DeviceService deviceService,
    LanguageProvider language,
    AppColors colors,
  ) async {
    if (_deployService.isRunning) return;

    final targets = _resolveTargets(deviceService);
    if (targets.isEmpty) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('deploy_no_targets_alert'),
        icon: Icons.warning_amber_rounded,
        accentColor: colors.accentAmber,
      );
      return;
    }

    if (_sourcePath == null || _sourcePath!.trim().isEmpty) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('deploy_no_source_alert'),
        icon: Icons.folder_open_rounded,
        accentColor: colors.accentRose,
      );
      return;
    }

    final dest = _destController.text.trim();
    if (dest.isEmpty) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('deploy_no_dest_alert'),
        icon: Icons.edit_note_rounded,
        accentColor: colors.accentRose,
      );
      return;
    }

    // Save active state and history
    await _historyRepo.saveLastState(
      sourcePath: _sourcePath,
      isDirectory: _isDirectory,
      destPath: dest,
    );
    await _historyRepo.addDestHistory(dest);
    if (_sourcePath != null) {
      await _historyRepo.addSourceHistory(_sourcePath!, _isDirectory);
      await _refreshSourceHistory();
    }

    final config = FileDeployJobConfig(
      sourcePath: _sourcePath!,
      isDirectory: _isDirectory,
      destDir: dest,
      createDirIfMissing: _createDirIfMissing,
      overwrite: _overwrite,
      autoKillIfInUse: _overwrite && _autoKillIfInUse,
      maxConcurrency: _concurrency,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      preDeployScript: _preHookController.text.trim().isNotEmpty
          ? _preHookController.text.trim()
          : null,
      postDeployScript: _postHookController.text.trim().isNotEmpty
          ? _postHookController.text.trim()
          : null,
      abortOnPreFail: _abortOnPreFail,
    );

    _terminalController.clear();
    await _deployService.startDeploy(targets: targets, config: config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final deviceService = context.watch<DeviceService>();
    final colors = theme.colors;
    final targets = _resolveTargets(deviceService);

    return RouteShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!_deployService.isRunning) {
            _startDeploy(deviceService, language, colors);
          }
        },
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          // When viewport height is less than 720px, auto-collapse Target Devices
          // to prevent the Start File Deploy button from being pushed off-screen.
          final isStartButtonObstructed = constraints.maxHeight < 720;
          final isTargetDevicesCollapsed =
              _isTargetDevicesCollapsedByUser ?? isStartButtonObstructed;

          if (!isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConfigPanel(
                    context,
                    language,
                    colors,
                    targets,
                    isTargetDevicesCollapsed: isTargetDevicesCollapsed,
                  ),
                  const SizedBox(height: 16),
                  _buildMonitorPanel(context, language, colors),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Configuration Bento Cards
              SizedBox(
                width: 390,
                child: SingleChildScrollView(
                  child: _buildConfigPanel(
                    context,
                    language,
                    colors,
                    targets,
                    isTargetDevicesCollapsed: isTargetDevicesCollapsed,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Right Column: Live Monitor, Device List & Event Logs
              Expanded(child: _buildMonitorPanel(context, language, colors)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConfigPanel(
    BuildContext context,
    LanguageProvider language,
    AppColors colors,
    List<ManagedDevice> targets, {
    required bool isTargetDevicesCollapsed,
  }) {
    final deviceService = context.read<DeviceService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Target Devices Card (Collapsible)
        GlassCard(
          colors: colors,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() {
                  _isTargetDevicesCollapsedByUser = !isTargetDevicesCollapsed;
                }),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.devices_rounded,
                        size: 17,
                        color: colors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          language.t('deploy_targets_title', {
                            'count': targets.length.toString(),
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.accentCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${targets.length} ${language.t('dev_online_pill')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.accentCyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isTargetDevicesCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              // Collapsible Body: Scope selector & Preview list
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scope selector (Selected only vs All Online)
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceChip(
                              label: language.t('deploy_target_selected_only', {
                                'count': deviceService.selectedDevices.length
                                    .toString(),
                              }),
                              isSelected: _targetSelectedOnly,
                              colors: colors,
                              onTap: () =>
                                  setState(() => _targetSelectedOnly = true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildChoiceChip(
                              label: language.t('deploy_target_all_online', {
                                'count': deviceService.onlineCount.toString(),
                              }),
                              isSelected: !_targetSelectedOnly,
                              colors: colors,
                              onTap: () =>
                                  setState(() => _targetSelectedOnly = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Target machines preview chips
                      if (targets.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.accentAmber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.accentAmber.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: colors.accentAmber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  language.t('deploy_no_targets_alert'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.accentAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 110),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: targets.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 6,
                              color: colors.cardBorder.withValues(alpha: 0.5),
                            ),
                            itemBuilder: (ctx, i) {
                              final t = targets[i];
                              return Row(
                                children: [
                                  Icon(
                                    t.os.toLowerCase() == 'linux'
                                        ? Icons.terminal_rounded
                                        : Icons.window_rounded,
                                    size: 14,
                                    color: colors.accentCyan,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      t.name,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    t.ip,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                crossFadeState: isTargetDevicesCollapsed
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Card 2: Source and Destination
        GlassCard(
          colors: colors,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source header
              Row(
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    size: 17,
                    color: colors.accentPurple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      language.t('deploy_source_title'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_sourceHistory.isNotEmpty)
                    InkWell(
                      onTap: () =>
                          _showSourceHistoryDialog(context, colors, language),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colors.accentPurple.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 12,
                              color: colors.accentPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${language.t('deploy_recent_sources')} (${_sourceHistory.length})',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: colors.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: language.t('deploy_pick_file'),
                      icon: Icons.insert_drive_file_outlined,
                      colors: colors,
                      accentColor: colors.accentPurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      onTap: _deployService.isRunning
                          ? null
                          : () => _pickFile(language),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      label: language.t('deploy_pick_folder'),
                      icon: Icons.folder_open_rounded,
                      colors: colors,
                      accentColor: colors.accentPurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      onTap: _deployService.isRunning
                          ? null
                          : () => _pickFolder(language),
                    ),
                  ),
                ],
              ),
              if (_sourceHistory.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _sourceHistory.take(4).map((item) {
                    final isSelected =
                        _sourcePath != null &&
                        _sourcePath!.toLowerCase() == item.path.toLowerCase();
                    return _buildSourcePresetChip(
                      item,
                      colors,
                      language,
                      isSelected,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),

              // Selected source info box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _sourcePath != null
                        ? colors.accentPurple.withValues(alpha: 0.35)
                        : colors.cardBorder,
                  ),
                ),
                child: _sourcePath == null
                    ? Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 15,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              language.t('deploy_source_not_selected'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isDirectory
                                    ? Icons.folder_rounded
                                    : Icons.description_rounded,
                                size: 16,
                                color: colors.accentPurple,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.basename(_sourcePath!),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentPurple.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  DeviceDeployProgress.formatBytes(
                                    _sourceSizeBytes,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.accentPurple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: _deployService.isRunning
                                    ? null
                                    : () {
                                        setState(() {
                                          _sourcePath = null;
                                          _sourceSizeBytes = 0;
                                          _sourceFileCount = 0;
                                        });
                                        _historyRepo.saveLastState(
                                          sourcePath: '',
                                        );
                                      },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sourcePath!,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.textMuted,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_isDirectory) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$_sourceFileCount file bên trong thư mục',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),

              // Destination Header
              Row(
                children: [
                  Icon(
                    Icons.folder_shared_rounded,
                    size: 17,
                    color: colors.accentCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      language.t('deploy_dest_title'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Destination TextField with History Suggestions
              GlassDeployDestField(
                controller: _destController,
                colors: colors,
                language: language,
                enabled: !_deployService.isRunning,
                historyRepo: _historyRepo,
                onChanged: (val) {
                  _historyRepo.saveLastState(destPath: val);
                },
              ),
              const SizedBox(height: 8),

              // Destination Quick Presets Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildPresetChip(r'C:\Temp\Deploy', colors, () {
                    setState(() => _destController.text = r'C:\Temp\Deploy');
                    _historyRepo.saveLastState(destPath: r'C:\Temp\Deploy');
                    _historyRepo.addDestHistory(r'C:\Temp\Deploy');
                  }),
                  _buildPresetChip(r'C:\Users\Public\Downloads', colors, () {
                    setState(
                      () => _destController.text = r'C:\Users\Public\Downloads',
                    );
                    _historyRepo.saveLastState(
                      destPath: r'C:\Users\Public\Downloads',
                    );
                    _historyRepo.addDestHistory(r'C:\Users\Public\Downloads');
                  }),
                  _buildPresetChip('/tmp/deploy/', colors, () {
                    setState(() => _destController.text = '/tmp/deploy/');
                    _historyRepo.saveLastState(destPath: '/tmp/deploy/');
                    _historyRepo.addDestHistory('/tmp/deploy/');
                  }),
                  _buildPresetChip('/opt/deploy/', colors, () {
                    setState(() => _destController.text = '/opt/deploy/');
                    _historyRepo.saveLastState(destPath: '/opt/deploy/');
                    _historyRepo.addDestHistory('/opt/deploy/');
                  }),
                ],
              ),
              const SizedBox(height: 10),

              // Checkbox options
              _buildCheckboxOption(
                label: language.t('deploy_opt_create_dir'),
                value: _createDirIfMissing,
                colors: colors,
                onChanged: _deployService.isRunning
                    ? null
                    : (val) =>
                          setState(() => _createDirIfMissing = val ?? true),
              ),
              _buildCheckboxOption(
                label: language.t('deploy_opt_overwrite'),
                value: _overwrite,
                colors: colors,
                onChanged: _deployService.isRunning
                    ? null
                    : (val) => setState(() {
                        final isChecked = val ?? true;
                        _overwrite = isChecked;
                        if (isChecked) {
                          _autoKillIfInUse = true;
                        } else {
                          _autoKillIfInUse = false;
                        }
                      }),
              ),
              if (_overwrite)
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 1),
                  child: _buildCheckboxOption(
                    label: language.t('deploy_opt_autokill'),
                    tooltip: language.t('deploy_opt_autokill_hint'),
                    value: _autoKillIfInUse,
                    colors: colors,
                    onChanged: _deployService.isRunning
                        ? null
                        : (val) =>
                              setState(() => _autoKillIfInUse = val ?? true),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Card 3: Auth & Concurrency (Collapsible)
        GlassCard(
          colors: colors,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clickable Accordion Header for Authentication & Concurrency
              InkWell(
                onTap: () => setState(() => _isAuthExpanded = !_isAuthExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: colors.accentAmber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          language.t('deploy_auth_title'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isAuthExpanded) ...[
                        if (_usernameController.text.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentAmber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colors.accentAmber.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              _usernameController.text,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: colors.accentAmber,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: colors.accentAmber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$_concurrency ${language.t('deploy_threads')}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: colors.accentAmber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        _isAuthExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              // Collapsible Credentials & Concurrency Body
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              enabled: !_deployService.isRunning,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: language.t('deploy_auth_user'),
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textMuted,
                                ),
                                filled: true,
                                fillColor: colors.cardBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colors.cardBorder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _passwordController,
                              enabled: !_deployService.isRunning,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: language.t('deploy_auth_pass'),
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textMuted,
                                ),
                                filled: true,
                                fillColor: colors.cardBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 16,
                                    color: colors.textMuted,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colors.cardBorder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.t('deploy_auth_optional'),
                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                      ),
                      const SizedBox(height: 10),

                      // Concurrency Slider
                      Row(
                        children: [
                          Text(
                            language.t('deploy_concurrency', {
                              'count': _concurrency.toString(),
                            }),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_concurrency ${language.t('deploy_threads')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.accentAmber,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: _concurrency.toDouble(),
                          min: 1,
                          max: 8,
                          divisions: 7,
                          activeColor: colors.accentAmber,
                          inactiveColor: colors.cardBorder,
                          onChanged: _deployService.isRunning
                              ? null
                              : (v) => setState(() => _concurrency = v.toInt()),
                        ),
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isAuthExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Card 4: Pre & Post Deploy Hooks (Collapsible)
        GlassCard(
          colors: colors,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _isHooksExpanded = !_isHooksExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.integration_instructions_rounded,
                        size: 16,
                        color: colors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pre/Post Deploy Hooks',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isHooksExpanded &&
                          (_preHookController.text.isNotEmpty ||
                              _postHookController.text.isNotEmpty)) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: colors.accentCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Hooks Active',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.accentCyan,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        _isHooksExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pre-deploy script
                      Text(
                        'Pre-Deploy Script (e.g. Stop Service, Taskkill):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _preHookController,
                        enabled: !_deployService.isRunning,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Stop-Service AppService -Force (Supports {{IP}})',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                          filled: true,
                          fillColor: colors.cardBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.cardBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Post-deploy script
                      Text(
                        'Post-Deploy Script (e.g. Start Service, Register DLL):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _postHookController,
                        enabled: !_deployService.isRunning,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Start-Service AppService (Supports {{IP}})',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                          filled: true,
                          fillColor: colors.cardBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.cardBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildCheckboxOption(
                        label: 'Hủy Deploy nếu Pre-Deploy Script thất bại',
                        value: _abortOnPreFail,
                        colors: colors,
                        onChanged: _deployService.isRunning
                            ? null
                            : (val) =>
                                  setState(() => _abortOnPreFail = val ?? true),
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isHooksExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Primary Action Button (Start / Abort)
        if (_deployService.isRunning)
          GlassButton(
            label: language.t('deploy_btn_abort'),
            icon: Icons.cancel_rounded,
            colors: colors,
            accentColor: colors.accentRose,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onTap: _deployService.abort,
          )
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _startDeploy(deviceService, language, colors),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentPurple, colors.accentCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentPurple.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      language.t('deploy_btn_start'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Ctrl+Enter',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonitorPanel(
    BuildContext context,
    LanguageProvider language,
    AppColors colors,
  ) {
    final progressList = _deployService.progressList;
    final overallPercent = _deployService.overallPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Card: Overall Progress and Metrics
        GlassCard(
          colors: colors,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, size: 18, color: colors.accentCyan),
                  const SizedBox(width: 8),
                  Text(
                    language.t('deploy_monitor_title'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(overallPercent * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: colors.accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Animated Overall Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: overallPercent,
                  minHeight: 10,
                  backgroundColor: colors.cardBorder.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _deployService.failedCount > 0 && overallPercent >= 1.0
                        ? colors.accentAmber
                        : colors.accentCyan,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Metrics row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricPill(
                      label: language.t('deploy_stat_total'),
                      value: _deployService.totalDevices.toString(),
                      color: colors.textPrimary,
                      colors: colors,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      label: language.t('deploy_stat_completed'),
                      value: _deployService.completedCount.toString(),
                      color: colors.accentEmerald,
                      colors: colors,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      label: language.t('deploy_stat_transferring'),
                      value: _deployService.transferringCount.toString(),
                      color: colors.accentCyan,
                      colors: colors,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      label: language.t('deploy_stat_failed'),
                      value: _deployService.failedCount.toString(),
                      color: colors.accentRose,
                      colors: colors,
                    ),
                    if (_deployService.transferringCount > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colors.accentCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.network_check_rounded,
                              size: 14,
                              color: colors.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatSpeed(
                                _deployService.totalSpeedBytesPerSec,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: colors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!_deployService.isRunning &&
                        _deployService.failedCount > 0) ...[
                      const SizedBox(width: 8),
                      GlassButton(
                        label: language.t('deploy_btn_retry_failed', {
                          'count': _deployService.failedCount.toString(),
                        }),
                        icon: Icons.refresh_rounded,
                        colors: colors,
                        accentColor: colors.accentRose,
                        onTap: () {
                          if (_deployService.currentConfig != null) {
                            _deployService.retryFailed(
                              config: _deployService.currentConfig!,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Device Progress Cards Grid / List
        Expanded(
          flex: 4,
          child: progressList.isEmpty
              ? GlassCard(
                  colors: colors,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: colors.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          language.t('deploy_ready_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          language.t('deploy_ready_desc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: progressList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final p = progressList[i];
                    return _buildDeviceProgressCard(p, language, colors);
                  },
                ),
        ),
        const SizedBox(height: 12),

        // Event Logs Terminal Card
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GlassTerminalPanel(
              controller: _terminalController,
              terminalTitle: language.t('deploy_terminal_title'),
              promptFocusNode: _terminalPromptFocus,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceProgressCard(
    DeviceDeployProgress prog,
    LanguageProvider language,
    AppColors colors,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (prog.status) {
      case DeployStatus.idle:
        statusColor = colors.textMuted;
        statusIcon = Icons.hourglass_empty_rounded;
        statusLabel = language.t('deploy_status_idle');
        break;
      case DeployStatus.pending:
        statusColor = colors.accentAmber;
        statusIcon = Icons.schedule_rounded;
        statusLabel = language.t('deploy_status_pending');
        break;
      case DeployStatus.connecting:
        statusColor = colors.accentCyan;
        statusIcon = Icons.sync_rounded;
        statusLabel = language.t('deploy_status_connecting');
        break;
      case DeployStatus.transferring:
        statusColor = colors.accentCyan;
        statusIcon = Icons.arrow_upward_rounded;
        statusLabel = language.t('deploy_status_transferring');
        break;
      case DeployStatus.completed:
        statusColor = colors.accentEmerald;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = language.t('deploy_status_completed');
        break;
      case DeployStatus.failed:
        statusColor = colors.accentRose;
        statusIcon = Icons.error_rounded;
        statusLabel = language.t('deploy_status_failed');
        break;
      case DeployStatus.cancelled:
        statusColor = colors.textMuted;
        statusIcon = Icons.cancel_rounded;
        statusLabel = language.t('deploy_status_cancelled');
        break;
    }

    return GlassCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                prog.device.os.toLowerCase() == 'linux'
                    ? Icons.terminal_rounded
                    : Icons.window_rounded,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      prog.device.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prog.device.ip,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_deployService.isRunning &&
                  (prog.status == DeployStatus.failed ||
                      prog.status == DeployStatus.cancelled)) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (_deployService.currentConfig != null) {
                      _deployService.retrySingle(
                        prog.device.id,
                        config: _deployService.currentConfig!,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: colors.accentRose,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prog.percent,
              minHeight: 6,
              backgroundColor: colors.cardBorder.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),

          // Sub-metrics row
          Row(
            children: [
              if (prog.currentFileName.isNotEmpty)
                Expanded(
                  child: Text(
                    prog.currentFileName,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    prog.formattedProgress,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              if (prog.status == DeployStatus.transferring)
                Text(
                  prog.formattedSpeed,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: colors.accentCyan,
                  ),
                )
              else if (prog.status == DeployStatus.completed &&
                  prog.durationMs > 0)
                Text(
                  '${prog.durationMs}ms',
                  style: TextStyle(fontSize: 11, color: colors.accentEmerald),
                ),
              const SizedBox(width: 8),
              Text(
                prog.formattedPercent,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),

          // Error message banner if failed
          if (prog.status == DeployStatus.failed && prog.error != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accentRose.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: colors.accentRose.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 13,
                    color: colors.accentRose,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      prog.error!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colors.accentRose,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required Color color,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11.5, color: colors.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _deployService.isRunning ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accentCyan.withValues(alpha: 0.14)
                : colors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colors.accentCyan.withValues(alpha: 0.5)
                  : colors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colors.accentCyan : colors.textPrimary,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String path, AppColors colors, VoidCallback onTap) {
    return InkWell(
      onTap: _deployService.isRunning ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Text(
          path,
          style: TextStyle(
            fontSize: 10.5,
            fontFamily: 'monospace',
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxOption({
    required String label,
    required bool value,
    required AppColors colors,
    required ValueChanged<bool?>? onChanged,
    String? tooltip,
  }) {
    final row = Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: colors.accentCyan,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, color: colors.textPrimary),
          ),
        ),
      ],
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: row,
      );
    }
    return row;
  }

  static String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    } else if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  Widget _buildSourcePresetChip(
    DeploySourceItem item,
    AppColors colors,
    LanguageProvider language,
    bool isSelected,
  ) {
    final base = p.basename(item.path);
    final exists = item.isDirectory
        ? Directory(item.path).existsSync()
        : File(item.path).existsSync();

    return Tooltip(
      message: exists
          ? item.path
          : '${item.path} (${language.t('deploy_source_missing')})',
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: _deployService.isRunning
            ? null
            : () async {
                final ok = await _loadSourceFromPath(
                  item.path,
                  item.isDirectory,
                  saveToHistory: true,
                );
                if (!ok && mounted) {
                  showAppToast(
                    context,
                    colors: colors,
                    message: language.t('deploy_source_missing'),
                    icon: Icons.error_outline_rounded,
                    accentColor: colors.accentRose,
                  );
                }
              },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accentPurple.withValues(alpha: 0.18)
                : colors.cardBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? colors.accentPurple.withValues(alpha: 0.6)
                  : colors.cardBorder,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.isDirectory
                    ? Icons.folder_rounded
                    : Icons.description_rounded,
                size: 11.5,
                color: exists
                    ? (isSelected ? colors.accentPurple : colors.textSecondary)
                    : colors.textMuted,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  base,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: exists
                        ? (isSelected
                              ? colors.textPrimary
                              : colors.textSecondary)
                        : colors.textMuted,
                    decoration: exists ? null : TextDecoration.lineThrough,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourceHistoryDialog(
    BuildContext context,
    AppColors colors,
    LanguageProvider language,
  ) {
    showGlassDialog(
      context: context,
      title:
          '${language.t('deploy_source_history_title')} (${_sourceHistory.length})',
      icon: Icons.history_rounded,
      width: 540,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (_sourceHistory.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  language.t('deploy_history_empty'),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () async {
                      await _historyRepo.clearSourceHistory();
                      await _refreshSourceHistory();
                      setDialogState(() {});
                      if (mounted) setState(() {});
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        language.t('deploy_history_clear'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accentRose,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sourceHistory.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 8,
                    color: colors.cardBorder.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (c, i) {
                    final item = _sourceHistory[i];
                    final exists = item.isDirectory
                        ? Directory(item.path).existsSync()
                        : File(item.path).existsSync();
                    final isSelected =
                        _sourcePath != null &&
                        _sourcePath!.toLowerCase() == item.path.toLowerCase();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final ok = await _loadSourceFromPath(
                            item.path,
                            item.isDirectory,
                            saveToHistory: true,
                          );
                          if (!ok && mounted && context.mounted) {
                            showAppToast(
                              context,
                              colors: colors,
                              message: language.t('deploy_source_missing'),
                              icon: Icons.error_outline_rounded,
                              accentColor: colors.accentRose,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.isDirectory
                                    ? Icons.folder_rounded
                                    : Icons.description_rounded,
                                size: 16,
                                color: exists
                                    ? (isSelected
                                          ? colors.accentPurple
                                          : colors.accentCyan)
                                    : colors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.basename(item.path),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: exists
                                            ? colors.textPrimary
                                            : colors.textMuted,
                                        decoration: exists
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      item.path,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: colors.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!exists)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accentRose.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Missing',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: colors.accentRose,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () async {
                                  await _historyRepo.removeSourceHistory(
                                    item.path,
                                  );
                                  await _refreshSourceHistory();
                                  setDialogState(() {});
                                  if (mounted) setState(() {});
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
