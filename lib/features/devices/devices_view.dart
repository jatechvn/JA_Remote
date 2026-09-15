import '../../widgets/route_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../data/models/managed_device.dart';
import '../../services/device_service.dart';
import '../../services/power_service.dart';
import '../../services/tool_launcher_service.dart';
import '../../services/config_backup_service.dart';
import '../../core/utils/file_dialog_helper.dart';
import '../../core/network/network_utils.dart';
import '../../widgets/glass_search_history_field.dart';
import 'device_detail_dialog.dart';
import 'add_device_dialog.dart';

class DevicesView extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  final bool isActive;

  const DevicesView({super.key, this.onNavigateTab, this.isActive = false});

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  final _searchFocus = FocusNode();
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<DeviceService>().searchQuery,
    );
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DevicesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(String column) {
    context.read<DeviceService>().setSort(column);
  }

  List<ManagedDevice> _getSortedDevices(
    List<ManagedDevice> devices,
    DeviceService service,
  ) {
    final list = List<ManagedDevice>.of(devices);
    final sortCol = service.sortColumn;
    final sortAsc = service.sortAscending;
    list.sort((a, b) {
      int cmp = 0;
      switch (sortCol) {
        case 'name':
          final aName = a.name.isNotEmpty ? a.name : a.hostname;
          final bName = b.name.isNotEmpty ? b.name : b.hostname;
          cmp = aName.toLowerCase().compareTo(bName.toLowerCase());
          break;
        case 'ip':
          cmp = NetworkUtils.compareIps(a.ip, b.ip);
          break;
        case 'mac':
          final aMac = a.mac ?? '';
          final bMac = b.mac ?? '';
          cmp = aMac.toLowerCase().compareTo(bMac.toLowerCase());
          break;
        case 'ping':
          if (a.pingMs == null && b.pingMs == null) {
            cmp = 0;
          } else if (a.pingMs == null) {
            return 1;
          } else if (b.pingMs == null) {
            return -1;
          } else {
            final res = a.pingMs!.compareTo(b.pingMs!);
            return sortAsc ? res : -res;
          }
          break;
        case 'status':
          final aVal = a.online ? 1 : 0;
          final bVal = b.online ? 1 : 0;
          cmp = bVal.compareTo(aVal); // Online first
          if (cmp == 0) {
            cmp = NetworkUtils.compareIps(a.ip, b.ip);
          }
          break;
        default:
          cmp = NetworkUtils.compareIps(a.ip, b.ip);
      }
      return sortAsc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final deviceService = context.watch<DeviceService>();
    final rawDevices = deviceService.filteredDevices;
    final devices = _getSortedDevices(rawDevices, deviceService);
    final selectedCount = deviceService.selectedIds.length;

    return RouteShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showAddDeviceDialog(context),
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            deviceService.refreshAllStatus(),
        const SingleActivator(
          LogicalKeyboardKey.keyA,
          control: true,
          shift: true,
        ): deviceService.selectAll,
        const SingleActivator(
          LogicalKeyboardKey.keyD,
          control: true,
          shift: true,
        ): deviceService.deselectAll,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Toolbar: Search, Filters, Refresh, Add
                _buildTopToolbar(context, deviceService, colors),
                const SizedBox(height: 12),

                // Devices Table / List
                Expanded(
                  child: GlassCard(
                    colors: colors,
                    child: devices.isEmpty
                        ? _buildEmptyState(context, colors)
                        : _buildDeviceList(
                            context,
                            deviceService,
                            devices,
                            colors,
                          ),
                  ),
                ),
                // Padding for bottom batch action bar if active
                if (selectedCount > 0) const SizedBox(height: 64),
              ],
            ),

            // Floating Batch Actions Dock
            if (selectedCount > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: _buildBatchDock(
                  context,
                  deviceService,
                  colors,
                  selectedCount,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar(
    BuildContext context,
    DeviceService service,
    dynamic colors,
  ) {
    final language = context.watch<LanguageProvider>();
    final filteredCount = service.filteredDevices.length;
    final totalCount = service.totalCount;
    final onlineCount = service.onlineCount;
    final isFiltered =
        service.searchQuery.trim().isNotEmpty ||
        service.selectedGroup != 'All' ||
        service.statusFilter != 'All';

    return GlassCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Search box with history suggestions
          Expanded(
            flex: 3,
            child: GlassSearchHistoryField(
              controller: _searchController,
              focusNode: _searchFocus,
              category: 'devices',
              hintText: language.t('dev_search_hint'),
              height: 36,
              fontSize: 13,
              hintFontSize: 12,
              borderRadius: 8,
              suffixBadge: service.searchQuery.trim().isNotEmpty
                  ? Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accentCyan.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: colors.accentCyan.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '$filteredCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: colors.accentCyan,
                        ),
                      ),
                    )
                  : null,
              onChanged: (val) {
                service.setSearchQuery(val);
                setState(() {});
              },
              onSubmitted: (val) {
                service.setSearchQuery(val);
                setState(() {});
              },
              onClear: () {
                service.setSearchQuery('');
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 10),

          // Group Filter Dropdown
          SizedBox(
            width: 170,
            child: GlassDropdown<String>(
              colors: colors,
              items: service.availableGroups.map((group) {
                return GlassDropdownItem<String>(
                  value: group,
                  label: '${language.t('dev_group_prefix')}$group',
                  icon: Icons.folder_open_rounded,
                  accentColor: colors.accentCyan,
                );
              }).toList(),
              value: service.selectedGroup,
              hintText: 'Nhóm máy…',
              enableSearch: service.availableGroups.length > 5,
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onChanged: (val) => service.setGroup(val),
            ),
          ),
          const SizedBox(width: 8),

          // Status Filter Buttons (All, Online, Offline)
          _buildStatusToggle(service, colors, language),
          const SizedBox(width: 8),

          // Count / Filter Indicator Chip
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFiltered
                    ? colors.accentCyan.withValues(alpha: 0.4)
                    : colors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFiltered ? Icons.filter_alt_rounded : Icons.devices_rounded,
                  size: 14,
                  color: isFiltered ? colors.accentCyan : colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  isFiltered
                      ? language.t('dev_count_filtered', {
                          'filtered': filteredCount.toString(),
                          'total': totalCount.toString(),
                        })
                      : language.t('dev_count_all', {
                          'count': totalCount.toString(),
                          'online': onlineCount.toString(),
                        }),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                    color: isFiltered
                        ? colors.accentCyan
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Auto Polling indicator / toggle
          IconButton(
            tooltip: service.isPolling
                ? language.t('dev_tooltip_autoping_on')
                : language.t('dev_tooltip_autoping_off'),
            icon: Icon(
              service.isPolling
                  ? Icons.autorenew_rounded
                  : Icons.pause_circle_outline_rounded,
              color: service.isPolling
                  ? colors.accentEmerald
                  : colors.textMuted,
            ),
            onPressed: service.togglePolling,
          ),

          // Refresh ping button
          IconButton(
            tooltip: language.t('dev_tooltip_refresh'),
            icon: Icon(Icons.refresh_rounded, color: colors.accentCyan),
            onPressed: () {
              service.refreshAllStatus();
              showAppToast(
                context,
                colors: colors,
                message: 'Đang kiểm tra kết nối các máy...',
                icon: Icons.sync_rounded,
              );
            },
          ),
          const SizedBox(width: 6),

          // Export Config Button
          GlassButton(
            label: language.t('dev_btn_export'),
            icon: Icons.upload_file_rounded,
            colors: colors,
            accentColor: colors.accentAmber,
            onTap: () => _handleExport(context, colors, language),
          ),
          const SizedBox(width: 6),

          // Import Config Button
          GlassButton(
            label: language.t('dev_btn_import'),
            icon: Icons.file_download_rounded,
            colors: colors,
            accentColor: colors.accentPurple,
            onTap: () => _handleImport(context, service, colors, language),
          ),
          const SizedBox(width: 6),

          // Add Device Button
          GlassButton(
            label: language.t('dev_btn_add'),
            icon: Icons.add_rounded,
            colors: colors,
            accentColor: colors.accentCyan,
            onTap: () => showAddDeviceDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    dynamic colors,
    LanguageProvider language,
  ) async {
    final path = await FileDialogHelper.pickSaveFile(
      defaultFileName: 'ja_remote_config.json',
      title: language.t('dev_btn_export'),
    );
    if (path == null) return;

    try {
      final count = await ConfigBackupService().exportConfig(path);
      if (context.mounted) {
        showAppToast(
          context,
          colors: colors,
          message: language.t('dev_export_success', {
            'count': count.toString(),
          }),
          icon: Icons.check_circle_rounded,
          accentColor: colors.accentEmerald,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(
          context,
          colors: colors,
          message: 'Lỗi xuất file: $e',
          icon: Icons.error_outline_rounded,
          accentColor: colors.accentRose,
        );
      }
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    DeviceService service,
    dynamic colors,
    LanguageProvider language,
  ) async {
    final path = await FileDialogHelper.pickOpenFile(
      title: language.t('dev_import_title'),
    );
    if (path == null) return;

    final preview = await ConfigBackupService().previewConfigFile(path);
    if (!preview.isValid) {
      if (context.mounted) {
        showAppToast(
          context,
          colors: colors,
          message: preview.error ?? 'Lỗi đọc file JSON',
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
      title: language.t('dev_import_title'),
      icon: Icons.file_download_rounded,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language.t('dev_import_preview_msg', {
              'count': preview.deviceCount.toString(),
              'creds': preview.credentialCount.toString(),
              'templates': preview.templateCount.toString(),
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.devices.isNotEmpty)
                  ...preview.devices.take(4).map((d) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${d.name} (${d.ip}) [${d.group}]',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    );
                  }),
                if (preview.commandTemplates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${preview.commandTemplates.length} kịch bản lệnh mẫu (${preview.commandTemplates.take(2).map((t) => t.name).join(', ')}${preview.commandTemplates.length > 2 ? '...' : ''})',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.accentCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        GlassButton(
          label: 'Hủy bỏ',
          colors: colors,
          onTap: () => Navigator.pop(context),
        ),
        const Spacer(),
        GlassButton(
          label: language.t('dev_import_mode_merge'),
          icon: Icons.merge_type_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: () async {
            Navigator.pop(context);
            await ConfigBackupService().applyImport(preview, overwrite: false);
            await service.reloadDevices();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('dev_import_success', {
                  'count': preview.deviceCount.toString(),
                }),
                icon: Icons.check_circle_rounded,
                accentColor: colors.accentEmerald,
              );
            }
          },
        ),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('dev_import_mode_overwrite'),
          icon: Icons.refresh_rounded,
          colors: colors,
          accentColor: colors.accentRose,
          onTap: () async {
            Navigator.pop(context);
            await ConfigBackupService().applyImport(preview, overwrite: true);
            await service.reloadDevices();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('dev_import_success', {
                  'count': preview.deviceCount.toString(),
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

  Widget _buildStatusToggle(
    DeviceService service,
    dynamic colors,
    LanguageProvider language,
  ) {
    final current = service.statusFilter;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['All', 'Online', 'Offline'].map((filter) {
          final isSelected = current == filter;
          String label = filter == 'All'
              ? language.t('dev_filter_all')
              : (filter == 'Online'
                    ? language.t('dev_filter_online')
                    : language.t('dev_filter_offline'));
          return InkWell(
            onTap: () => service.setStatusFilter(filter),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accentCyan.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colors.accentCyan : colors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortHeader({
    required String title,
    required String columnKey,
    required dynamic colors,
    required DeviceService service,
    int? flex,
    double? width,
  }) {
    final isActive = service.sortColumn == columnKey;
    final content = InkWell(
      onTap: () => _onSort(columnKey),
      borderRadius: BorderRadius.circular(4),
      hoverColor: colors.accentCyan.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? colors.accentCyan : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? (service.sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: isActive
                  ? colors.accentCyan
                  : colors.textMuted.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return Expanded(flex: flex ?? 1, child: content);
  }

  Widget _buildDeviceList(
    BuildContext context,
    DeviceService service,
    List<ManagedDevice> devices,
    dynamic colors,
  ) {
    final language = context.watch<LanguageProvider>();
    final allSelected =
        devices.isNotEmpty &&
        devices.every((d) => service.selectedIds.contains(d.id));

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.cardBg.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: colors.cardBorder)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (v) {
                  if (v == true) {
                    service.selectAll();
                  } else {
                    service.deselectAll();
                  }
                },
                activeColor: colors.accentCyan,
              ),
              const SizedBox(width: 8),
              _buildSortHeader(
                title: '${language.t('dev_col_name')} (${devices.length})',
                columnKey: 'name',
                flex: 3,
                colors: colors,
                service: service,
              ),
              _buildSortHeader(
                title: language.t('dev_col_ip'),
                columnKey: 'ip',
                flex: 2,
                colors: colors,
                service: service,
              ),
              _buildSortHeader(
                title: language.t('dev_col_mac'),
                columnKey: 'mac',
                flex: 2,
                colors: colors,
                service: service,
              ),
              _buildSortHeader(
                title: language.t('dev_col_ping'),
                columnKey: 'ping',
                flex: 1,
                colors: colors,
                service: service,
              ),
              _buildSortHeader(
                title: language.t('dev_col_status'),
                columnKey: 'status',
                flex: 2,
                colors: colors,
                service: service,
              ),
              SizedBox(
                width: 144,
                child: Text(
                  language.t('dev_col_actions'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: colors.cardBorder),
            itemBuilder: (ctx, index) {
              final dev = devices[index];
              final isSelected = service.selectedIds.contains(dev.id);

              return _DeviceRow(
                device: dev,
                isSelected: isSelected,
                colors: colors,
                onToggleSelect: () => service.toggleSelection(dev.id),
                onShowDetail: () => showDeviceDetailDialog(context, dev),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other_rounded, size: 54, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Chưa có thiết bị nào phù hợp bộ lọc',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm máy tính thủ công hoặc quét dải mạng LAN để phát hiện thiết bị.',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchDock(
    BuildContext context,
    DeviceService service,
    dynamic colors,
    int selectedCount,
  ) {
    final language = context.watch<LanguageProvider>();

    return GlassCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_box_rounded, color: colors.accentCyan, size: 18),
          const SizedBox(width: 7),
          Text(
            language.t('dev_batch_selected', {
              'count': selectedCount.toString(),
            }),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 14),

          // Scrollable batch actions
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Wake selected
                  GlassButton(
                    label: language.t('dev_batch_wake'),
                    icon: Icons.bolt_rounded,
                    colors: colors,
                    accentColor: colors.accentEmerald,
                    onTap: () async {
                      await service.batchWakeSelected();
                      if (context.mounted) {
                        showAppToast(
                          context,
                          colors: colors,
                          message:
                              'Đã gửi lệnh Magic Packet đến các máy đã chọn!',
                          icon: Icons.bolt_rounded,
                          accentColor: colors.accentEmerald,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),

                  // Restart selected
                  GlassButton(
                    label: language.t('dev_batch_restart'),
                    icon: Icons.restart_alt_rounded,
                    colors: colors,
                    accentColor: colors.accentAmber,
                    onTap: () async {
                      await service.batchRestartSelected();
                      if (context.mounted) {
                        showAppToast(
                          context,
                          colors: colors,
                          message: 'Đang gửi lệnh Restart hàng loạt...',
                          icon: Icons.restart_alt_rounded,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),

                  // Shutdown selected
                  GlassButton(
                    label: language.t('dev_batch_shutdown'),
                    icon: Icons.power_settings_new_rounded,
                    colors: colors,
                    accentColor: colors.accentRose,
                    onTap: () async {
                      await service.batchShutdownSelected();
                      if (context.mounted) {
                        showAppToast(
                          context,
                          colors: colors,
                          message: 'Đang gửi lệnh Shutdown hàng loạt...',
                          icon: Icons.power_settings_new_rounded,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),

                  // Run command tab navigate
                  if (widget.onNavigateTab != null) ...[
                    GlassButton(
                      label: language.t('dev_batch_cmd'),
                      icon: Icons.terminal_rounded,
                      colors: colors,
                      accentColor: colors.accentPurple,
                      onTap: () => widget.onNavigateTab?.call(
                        2,
                      ), // Switch to Command Runner Tab
                    ),
                    const SizedBox(width: 6),
                    GlassButton(
                      label: language.t('dev_batch_deploy'),
                      icon: Icons.drive_folder_upload_rounded,
                      colors: colors,
                      accentColor: colors.accentCyan,
                      onTap: () => widget.onNavigateTab?.call(
                        3,
                      ), // Switch to File Deploy Tab
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Change Group
                  GlassButton(
                    label: language.t('dev_batch_change_group'),
                    icon: Icons.drive_file_move_rounded,
                    colors: colors,
                    accentColor: colors.accentCyan,
                    onTap: () => _showBatchChangeGroupDialog(
                      context,
                      service,
                      colors,
                      language,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Export Selected
                  GlassButton(
                    label: language.t('dev_batch_export_selected'),
                    icon: Icons.file_download_outlined,
                    colors: colors,
                    accentColor: colors.accentAmber,
                    onTap: () async {
                      final path = await FileDialogHelper.pickSaveFile(
                        defaultFileName:
                            'JA_Remote_Selected_${DateTime.now().millisecondsSinceEpoch}.json',
                      );
                      if (path != null) {
                        final backupService = ConfigBackupService();
                        final count = await backupService.exportSelectedDevices(
                          path,
                          service.selectedDevices,
                        );
                        if (context.mounted) {
                          showAppToast(
                            context,
                            colors: colors,
                            message: language.t('dev_export_success', {
                              'count': count.toString(),
                            }),
                            icon: Icons.check_circle_rounded,
                            accentColor: colors.accentEmerald,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 6),

                  // Delete Selected
                  GlassButton(
                    label: language.t('dev_batch_delete', {
                      'count': selectedCount.toString(),
                    }),
                    icon: Icons.delete_outline_rounded,
                    colors: colors,
                    accentColor: colors.accentRose,
                    onTap: () =>
                        _confirmBatchDelete(context, service, colors, language),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Deselect button
          TextButton.icon(
            onPressed: service.deselectAll,
            icon: Icon(Icons.close_rounded, size: 14, color: colors.textMuted),
            label: Text(
              language.t('dev_batch_deselect'),
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBatchDelete(
    BuildContext context,
    DeviceService service,
    dynamic colors,
    LanguageProvider language,
  ) {
    final selectedDevices = service.selectedDevices;
    final count = selectedDevices.length;

    showGlassDialog(
      context: context,
      title: language.t('dev_batch_delete_title', {'count': count.toString()}),
      icon: Icons.delete_forever_rounded,
      width: 480,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.accentRose.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colors.accentRose,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  language.t('dev_batch_delete_msg', {
                    'count': count.toString(),
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Device list preview
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.cardBorder),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: selectedDevices.length,
              separatorBuilder: (_, _) => Divider(
                height: 8,
                color: colors.cardBorder.withValues(alpha: 0.5),
              ),
              itemBuilder: (_, i) {
                final d = selectedDevices[i];
                return Row(
                  children: [
                    Icon(
                      Icons.computer_rounded,
                      size: 14,
                      color: colors.accentRose,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      d.ip,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            language.t('action_cancel'),
            style: TextStyle(color: colors.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accentRose,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            await service.removeSelectedDevices();
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('dev_batch_delete_success', {
                  'count': count.toString(),
                }),
                icon: Icons.check_circle_rounded,
                accentColor: colors.accentEmerald,
              );
            }
          },
          icon: const Icon(Icons.delete_forever_rounded, size: 16),
          label: Text(
            language.t('dev_batch_delete_confirm_btn'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showBatchChangeGroupDialog(
    BuildContext context,
    DeviceService service,
    dynamic colors,
    LanguageProvider language,
  ) {
    final count = service.selectedIds.length;
    final availableGroups = service.availableGroups
        .where((g) => g != 'All')
        .toList();
    final groupController = TextEditingController();

    showGlassDialog(
      context: context,
      title: language.t('dev_batch_group_title', {'count': count.toString()}),
      icon: Icons.folder_shared_rounded,
      width: 440,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.t('dev_batch_group_hint'),
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),

              // Existing Groups Chips
              if (availableGroups.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: availableGroups.map((group) {
                    final isSelected = groupController.text == group;
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          groupController.text = group;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accentCyan.withValues(alpha: 0.2)
                              : colors.cardBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? colors.accentCyan
                                : colors.borderDefault,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 13,
                              color: isSelected
                                  ? colors.accentCyan
                                  : colors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              group,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colors.accentCyan
                                    : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Custom group name textfield
              TextField(
                controller: groupController,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Tên nhóm / Group Name',
                  labelStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: colors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: colors.accentCyan,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            language.t('action_cancel'),
            style: TextStyle(color: colors.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accentCyan,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () async {
            final newGroup = groupController.text.trim();
            if (newGroup.isEmpty) return;
            Navigator.of(context).pop();
            await service.batchUpdateGroup(newGroup);
            if (context.mounted) {
              showAppToast(
                context,
                colors: colors,
                message: language.t('dev_batch_group_success', {
                  'count': count.toString(),
                  'group': newGroup,
                }),
                icon: Icons.check_circle_rounded,
                accentColor: colors.accentEmerald,
              );
            }
          },
          child: Text(
            language.t('dev_batch_group_confirm_btn'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final ManagedDevice device;
  final bool isSelected;
  final dynamic colors;
  final VoidCallback onToggleSelect;
  final VoidCallback onShowDetail;

  const _DeviceRow({
    required this.device,
    required this.isSelected,
    required this.colors,
    required this.onToggleSelect,
    required this.onShowDetail,
  });

  @override
  Widget build(BuildContext context) {
    final toolService = ToolLauncherService();
    final powerService = PowerService();

    return InkWell(
      onTap: onShowDetail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: isSelected
            ? colors.accentCyan.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelect(),
              activeColor: colors.accentCyan,
            ),
            const SizedBox(width: 8),

            // Name + Hostname
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Icon(
                    device.os.toLowerCase() == 'linux'
                        ? Icons.terminal_rounded
                        : Icons.window_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          device.hostname,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // IP
            Expanded(
              flex: 2,
              child: Text(
                device.ip,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: colors.accentCyan,
                ),
              ),
            ),

            // MAC
            Expanded(
              flex: 2,
              child: Text(
                device.mac ?? '--',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: colors.textSecondary,
                ),
              ),
            ),

            // Ping
            Expanded(
              flex: 1,
              child: device.pingMs != null && device.online
                  ? LatencyBadge(latencyMs: device.pingMs!, colors: colors)
                  : Text(
                      '--',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
            ),

            // Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  StatusPill(
                    label: device.online ? 'Online' : 'Offline',
                    dotColor: device.online
                        ? colors.accentEmerald
                        : colors.textMuted,
                    backgroundColor: device.online
                        ? colors.accentEmerald.withValues(alpha: 0.12)
                        : colors.cardBg,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Text(
                      device.group,
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            SizedBox(
              width: 144,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // RDP Button
                  IconButton(
                    iconSize: 18,
                    tooltip: 'Mở Remote Desktop',
                    icon: Icon(
                      Icons.desktop_windows_rounded,
                      color: colors.accentCyan,
                    ),
                    onPressed: () {
                      toolService.launchRdp(device);
                      showAppToast(
                        context,
                        colors: colors,
                        message: 'Đang mở RDP tới ${device.ip}...',
                        icon: Icons.desktop_windows_rounded,
                      );
                    },
                  ),
                  // Wake (WOL)
                  IconButton(
                    iconSize: 18,
                    tooltip: 'Bật máy (WOL)',
                    icon: Icon(Icons.bolt_rounded, color: colors.accentEmerald),
                    onPressed: () async {
                      final ok = await powerService.wakeDevice(device);
                      if (context.mounted) {
                        showAppToast(
                          context,
                          colors: colors,
                          message: ok
                              ? 'Đã gửi gói Wake-on-LAN tới ${device.name}!'
                              : 'Không thể gửi WOL (thiếu MAC)',
                          icon: Icons.bolt_rounded,
                          accentColor: ok
                              ? colors.accentEmerald
                              : colors.accentRose,
                        );
                      }
                    },
                  ),
                  // Details
                  IconButton(
                    iconSize: 18,
                    tooltip: 'Chi tiết & Quản trị',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: onShowDetail,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
