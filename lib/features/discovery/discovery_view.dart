import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/app_toast.dart';
import '../../services/discovery_service.dart';
import '../../services/device_service.dart';
import '../../core/network/network_utils.dart';
import '../../core/utils/everything_search_matcher.dart';
import '../../data/models/managed_device.dart';

class DiscoveryView extends StatefulWidget {
  const DiscoveryView({super.key});

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  late TextEditingController _subnetController;
  late TextEditingController _searchController;
  String _filterMode = 'all'; // 'all', 'unadded', 'added', 'fast'
  String _viewMode = 'table'; // 'table', 'grid', 'list'
  bool _showAdapters = false;
  final Set<String> _selectedIps = {};

  @override
  void initState() {
    super.initState();
    _subnetController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _subnetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  final _searchFocus = FocusNode();
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final language = context.watch<LanguageProvider>();
    final discovery = context.watch<DiscoveryService>();
    final deviceService = context.watch<DeviceService>();

    if (_subnetController.text.isEmpty && discovery.currentSubnet.isNotEmpty) {
      _subnetController.text = discovery.currentSubnet;
    }

    final isScanning = discovery.isScanning;
    final allDiscovered = discovery.discoveredDevices;
    final adapters = discovery.availableAdapters;

    final savedIps = deviceService.devices.map((d) => d.ip).toSet();
    final query = _searchController.text.trim();

    // Clean up selected IPs that no longer exist in discovered devices
    final discoveredIps = allDiscovered.map((d) => d.ip).toSet();
    _selectedIps.removeWhere((ip) => !discoveredIps.contains(ip));

    final unaddedCount = allDiscovered
        .where((d) => !savedIps.contains(d.ip))
        .length;
    final addedCount = allDiscovered
        .where((d) => savedIps.contains(d.ip))
        .length;
    final fastCount = allDiscovered
        .where((d) => d.pingMs != null && d.pingMs! <= 50)
        .length;

    final filteredItems = allDiscovered.where((dev) {
      final isAlreadyAdded = savedIps.contains(dev.ip);

      switch (_filterMode) {
        case 'unadded':
          if (isAlreadyAdded) return false;
          break;
        case 'added':
          if (!isAlreadyAdded) return false;
          break;
        case 'fast':
          if (dev.pingMs == null || dev.pingMs! > 50) return false;
          break;
        case 'all':
        default:
          break;
      }

      if (query.isNotEmpty) {
        if (!EverythingSearchMatcher.matches(
          query: query,
          targets: [dev.name, dev.ip, dev.hostname, dev.mac],
        )) {
          return false;
        }
      }

      return true;
    }).toList();

    // Check if all unadded filtered items are selected
    final unaddedFiltered = filteredItems
        .where((d) => !savedIps.contains(d.ip))
        .toList();
    final isAllFilteredSelected =
        unaddedFiltered.isNotEmpty &&
        unaddedFiltered.every((d) => _selectedIps.contains(d.ip));
    final selectedCount = _selectedIps.length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Subnet Control Card
            GlassCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.radar_rounded,
                        color: colors.accentCyan,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        language.t('scanner_title'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Compact Subnet Input
                      SizedBox(
                        width: 160,
                        height: 32,
                        child: TextField(
                          controller: _subnetController,
                          enabled: !isScanning,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '172.21.168.0/24',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            filled: true,
                            fillColor: colors.cardBg,
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
                      ),
                      const SizedBox(width: 8),

                      // Start / Stop Scan Button
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isScanning
                                ? colors.accentRose
                                : colors.accentCyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (isScanning) {
                              discovery.stopScan();
                            } else {
                              discovery.setSubnet(
                                _subnetController.text.trim(),
                              );
                              discovery.startScan();
                            }
                          },
                          icon: Icon(
                            isScanning
                                ? Icons.stop_rounded
                                : Icons.search_rounded,
                            size: 16,
                          ),
                          label: Text(
                            isScanning
                                ? language.t('scanner_btn_stop')
                                : language.t('scanner_btn_start'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Auto Detect local subnet button
                      SizedBox(
                        height: 32,
                        child: GlassButton(
                          label: language.t('scanner_auto_detect'),
                          icon: Icons.my_location_rounded,
                          colors: colors,
                          onTap: () async {
                            final autoSubnet =
                                await NetworkUtils.getDefaultLocalSubnet();
                            setState(() {
                              _subnetController.text = autoSubnet;
                            });
                            discovery.setSubnet(autoSubnet);
                            if (context.mounted) {
                              showAppToast(
                                context,
                                colors: colors,
                                message: language.t('scanner_detected_toast', {
                                  'subnet': autoSubnet,
                                }),
                                icon: Icons.check_circle_rounded,
                                accentColor: colors.accentCyan,
                              );
                            }
                          },
                        ),
                      ),

                      // Collapsible Adapters Toggle Chip
                      if (adapters.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              setState(() => _showAdapters = !_showAdapters),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: _showAdapters
                                  ? colors.accentCyan.withValues(alpha: 0.18)
                                  : colors.cardBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _showAdapters
                                    ? colors.accentCyan
                                    : colors.borderDefault,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.settings_ethernet_rounded,
                                  size: 14,
                                  color: _showAdapters
                                      ? colors.accentCyan
                                      : colors.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  language.t('scanner_toggle_adapters', {
                                    'count': adapters.length.toString(),
                                  }),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _showAdapters
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _showAdapters
                                        ? colors.accentCyan
                                        : colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showAdapters
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: _showAdapters
                                      ? colors.accentCyan
                                      : colors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Mini Progress Indicator
                      if (isScanning || discovery.progress > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.borderDefault),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 55,
                                height: 5,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: discovery.progress,
                                    backgroundColor: colors.cardBorder,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.accentCyan,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '${discovery.scannedCount}/${discovery.totalCount} (${(discovery.progress * 100).toInt()}%)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: colors.accentCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Collapsible Adapters list
                  if (_showAdapters && adapters.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: adapters.map((adapter) {
                          final isSelected =
                              _subnetController.text.trim() == adapter.subnet;
                          final isVirtual = adapter.isVirtual;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _subnetController.text = adapter.subnet;
                                });
                                discovery.setSubnet(adapter.subnet);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
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
                                      isVirtual
                                          ? Icons.cloud_queue_rounded
                                          : Icons.settings_ethernet_rounded,
                                      size: 12,
                                      color: isSelected
                                          ? colors.accentCyan
                                          : (isVirtual
                                                ? colors.accentAmber
                                                : colors.accentEmerald),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${adapter.name}: ${adapter.subnet}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? colors.accentCyan
                                            : colors.textPrimary,
                                      ),
                                    ),
                                    if (isVirtual) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.accentAmber.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: const Text(
                                          'VPN',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Discovered Devices Header & Multi-Mode View
            Expanded(
              child: GlassCard(
                colors: colors,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Merged Control Bar (Title, Filter Chips, Search, Mode Switcher, Actions)
                    _buildMergedControlBar(
                      colors: colors,
                      language: language,
                      allCount: allDiscovered.length,
                      unaddedCount: unaddedCount,
                      addedCount: addedCount,
                      fastCount: fastCount,
                      selectedCount: selectedCount,
                      isAllSelected: isAllFilteredSelected,
                      hasUnaddedFiltered: unaddedFiltered.isNotEmpty,
                      onToggleSelectAll: () {
                        setState(() {
                          if (isAllFilteredSelected) {
                            for (final d in unaddedFiltered) {
                              _selectedIps.remove(d.ip);
                            }
                          } else {
                            for (final d in unaddedFiltered) {
                              _selectedIps.add(d.ip);
                            }
                          }
                        });
                      },
                      onAddSelected: selectedCount > 0
                          ? () => _addSelectedDevices(
                              colors: colors,
                              language: language,
                              deviceService: deviceService,
                              allDiscovered: allDiscovered,
                              savedIps: savedIps,
                            )
                          : null,
                      onAddAllUnadded: unaddedCount > 0
                          ? () => _addAllUnaddedDevices(
                              colors: colors,
                              language: language,
                              deviceService: deviceService,
                              items: allDiscovered,
                              savedIps: savedIps,
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // 2. Content (Table / Grid / List / Empty)
                    Expanded(
                      child: allDiscovered.isEmpty
                          ? _buildEmptyIdleOrScanning(
                              isScanning,
                              colors,
                              language,
                            )
                          : filteredItems.isEmpty
                          ? _buildEmptyFilterMatch(colors, language)
                          : _buildDiscoveredContent(
                              items: filteredItems,
                              savedIps: savedIps,
                              colors: colors,
                              language: language,
                              deviceService: deviceService,
                              unaddedFiltered: unaddedFiltered,
                              isAllFilteredSelected: isAllFilteredSelected,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergedControlBar({
    required dynamic colors,
    required LanguageProvider language,
    required int allCount,
    required int unaddedCount,
    required int addedCount,
    required int fastCount,
    required int selectedCount,
    required bool isAllSelected,
    required bool hasUnaddedFiltered,
    required VoidCallback onToggleSelectAll,
    required VoidCallback? onAddSelected,
    required VoidCallback? onAddAllUnadded,
  }) {
    return Row(
      children: [
        // Hosts Count Title
        Icon(Icons.devices_other_rounded, color: colors.accentCyan, size: 17),
        const SizedBox(width: 6),
        Text(
          'HOSTS ($allCount)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),

        // Filter chips (All, Unadded, Added, Fast)
        _buildFilterChip(
          label: language.t('scanner_filter_all'),
          count: allCount,
          mode: 'all',
          colors: colors,
        ),
        const SizedBox(width: 5),
        _buildFilterChip(
          label: language.t('scanner_filter_unadded'),
          count: unaddedCount,
          mode: 'unadded',
          colors: colors,
          accentColor: colors.accentCyan,
          highlightBadge: unaddedCount > 0,
        ),
        const SizedBox(width: 5),
        _buildFilterChip(
          label: language.t('scanner_filter_added'),
          count: addedCount,
          mode: 'added',
          colors: colors,
          accentColor: colors.accentEmerald,
        ),
        const SizedBox(width: 5),
        _buildFilterChip(
          label: language.t('scanner_filter_fast'),
          count: fastCount,
          mode: 'fast',
          colors: colors,
          accentColor: colors.accentAmber,
        ),
        const SizedBox(width: 10),

        // Search Input Box (Compact)
        SizedBox(
          width: 185,
          height: 30,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 11.5, color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: language.t('scanner_search_hint'),
              hintStyle: TextStyle(fontSize: 10.5, color: colors.textMuted),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 15,
                color: _searchController.text.isNotEmpty
                    ? colors.accentCyan
                    : colors.textMuted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 13),
                      color: colors.textMuted,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: colors.cardBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
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
                borderSide: BorderSide(color: colors.accentCyan, width: 1.1),
              ),
            ),
          ),
        ),

        const Spacer(),

        // View Mode Switcher (Table / Grid / List)
        Container(
          height: 30,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewModeIcon(
                mode: 'table',
                icon: Icons.table_rows_rounded,
                tooltip: language.t('scanner_view_table'),
                colors: colors,
              ),
              _buildViewModeIcon(
                mode: 'grid',
                icon: Icons.grid_view_rounded,
                tooltip: language.t('scanner_view_grid'),
                colors: colors,
              ),
              _buildViewModeIcon(
                mode: 'list',
                icon: Icons.view_agenda_rounded,
                tooltip: language.t('scanner_view_list'),
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Select All toggle button
        if (hasUnaddedFiltered) ...[
          InkWell(
            onTap: onToggleSelectAll,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: isAllSelected
                    ? colors.accentCyan.withValues(alpha: 0.15)
                    : colors.cardBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isAllSelected
                      ? colors.accentCyan
                      : colors.borderDefault,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAllSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 15,
                    color: isAllSelected ? colors.accentCyan : colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAllSelected
                        ? language.t('scanner_deselect_all')
                        : language.t('scanner_select_all'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isAllSelected
                          ? colors.accentCyan
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Action: Add Selected
        if (selectedCount > 0 && onAddSelected != null) ...[
          GlassButton(
            label: language.t('scanner_btn_add_selected', {
              'count': selectedCount.toString(),
            }),
            icon: Icons.check_circle_outline_rounded,
            colors: colors,
            accentColor: colors.accentEmerald,
            onTap: onAddSelected,
          ),
          const SizedBox(width: 6),
        ],

        // Action: Add All Unadded
        if (unaddedCount > 0 && onAddAllUnadded != null)
          GlassButton(
            label: language.t('scanner_btn_add_unadded', {
              'count': unaddedCount.toString(),
            }),
            icon: Icons.playlist_add_rounded,
            colors: colors,
            accentColor: colors.accentCyan,
            onTap: onAddAllUnadded,
          ),
      ],
    );
  }

  Widget _buildViewModeIcon({
    required String mode,
    required IconData icon,
    required String tooltip,
    required dynamic colors,
  }) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewMode = mode),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isSelected ? colors.accentCyan : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.white : colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required String mode,
    required dynamic colors,
    Color? accentColor,
    bool highlightBadge = false,
  }) {
    final isSelected = _filterMode == mode;
    final activeColor = accentColor ?? colors.accentCyan;

    return InkWell(
      onTap: () {
        setState(() {
          _filterMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : colors.borderDefault,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : colors.textPrimary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.25)
                    : (highlightBadge
                          ? colors.accentCyan.withValues(alpha: 0.15)
                          : colors.cardBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: isSelected
                      ? activeColor
                      : (highlightBadge ? colors.accentCyan : colors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredContent({
    required List<ManagedDevice> items,
    required Set<String> savedIps,
    required dynamic colors,
    required LanguageProvider language,
    required DeviceService deviceService,
    required List<ManagedDevice> unaddedFiltered,
    required bool isAllFilteredSelected,
  }) {
    switch (_viewMode) {
      case 'grid':
        return _buildGridView(
          items: items,
          savedIps: savedIps,
          colors: colors,
          language: language,
          deviceService: deviceService,
        );
      case 'list':
        return _buildListView(
          items: items,
          savedIps: savedIps,
          colors: colors,
          language: language,
          deviceService: deviceService,
        );
      case 'table':
      default:
        return _buildTableView(
          items: items,
          savedIps: savedIps,
          colors: colors,
          language: language,
          deviceService: deviceService,
          unaddedFiltered: unaddedFiltered,
          isAllFilteredSelected: isAllFilteredSelected,
        );
    }
  }

  // 1. Compact Data Table (Wireshark / DevTools style - 32px height)
  Widget _buildTableView({
    required List<ManagedDevice> items,
    required Set<String> savedIps,
    required dynamic colors,
    required LanguageProvider language,
    required DeviceService deviceService,
    required List<ManagedDevice> unaddedFiltered,
    required bool isAllFilteredSelected,
  }) {
    return Column(
      children: [
        // Table Header
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colors.cardBorder.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: unaddedFiltered.isEmpty
                    ? null
                    : InkWell(
                        onTap: () {
                          setState(() {
                            if (isAllFilteredSelected) {
                              for (final d in unaddedFiltered) {
                                _selectedIps.remove(d.ip);
                              }
                            } else {
                              for (final d in unaddedFiltered) {
                                _selectedIps.add(d.ip);
                              }
                            }
                          });
                        },
                        child: Icon(
                          isAllFilteredSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 15,
                          color: isAllFilteredSelected
                              ? colors.accentCyan
                              : colors.textMuted,
                        ),
                      ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  language.t('scanner_col_device'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  language.t('scanner_col_ip'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  language.t('scanner_col_mac'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  language.t('scanner_col_ping'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Container(
                width: 80,
                alignment: Alignment.centerRight,
                child: Text(
                  language.t('scanner_col_action'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),

        // Table Rows List
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: colors.cardBorder.withValues(alpha: 0.4),
            ),
            itemBuilder: (ctx, index) {
              final dev = items[index];
              final isAlreadyAdded = savedIps.contains(dev.ip);
              final isSelected = _selectedIps.contains(dev.ip);

              return InkWell(
                onTap: isAlreadyAdded
                    ? null
                    : () {
                        setState(() {
                          if (isSelected) {
                            _selectedIps.remove(dev.ip);
                          } else {
                            _selectedIps.add(dev.ip);
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accentCyan.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      // Checkbox or Checked icon
                      SizedBox(
                        width: 32,
                        child: isAlreadyAdded
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: colors.accentEmerald,
                                size: 15,
                              )
                            : Checkbox(
                                value: isSelected,
                                activeColor: colors.accentCyan,
                                checkColor: Colors.white,
                                side: BorderSide(
                                  color: colors.borderDefault,
                                  width: 1.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIps.add(dev.ip);
                                    } else {
                                      _selectedIps.remove(dev.ip);
                                    }
                                  });
                                },
                              ),
                      ),

                      // Device Name & Hostname inline
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Icon(
                              Icons.computer_rounded,
                              size: 14,
                              color: isAlreadyAdded
                                  ? colors.accentEmerald
                                  : colors.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: dev.name,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                  children: [
                                    if (dev.hostname.isNotEmpty &&
                                        dev.hostname != dev.name &&
                                        dev.hostname != dev.ip)
                                      TextSpan(
                                        text: ' (${dev.hostname})',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.normal,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // IP Address
                      Expanded(
                        flex: 3,
                        child: Text(
                          dev.ip,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.accentCyan,
                          ),
                        ),
                      ),

                      // MAC Address
                      Expanded(
                        flex: 3,
                        child: Text(
                          dev.mac ?? '--',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),

                      // Ping
                      SizedBox(
                        width: 70,
                        child: dev.pingMs != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dev.pingMs! <= 50
                                          ? colors.accentEmerald
                                          : colors.accentAmber,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${dev.pingMs}ms',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: dev.pingMs! <= 50
                                          ? colors.accentEmerald
                                          : colors.accentAmber,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                '--',
                                style: TextStyle(fontSize: 10.5),
                              ),
                      ),

                      // Action (Add or Saved)
                      Container(
                        width: 80,
                        alignment: Alignment.centerRight,
                        child: isAlreadyAdded
                            ? Text(
                                language.t('scanner_saved'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.accentEmerald,
                                ),
                              )
                            : SizedBox(
                                height: 23,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.accentCyan
                                        .withValues(alpha: 0.15),
                                    foregroundColor: colors.accentCyan,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      side: BorderSide(
                                        color: colors.accentCyan.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await deviceService.addDevice(dev);
                                    if (mounted) {
                                      showAppToast(
                                        context,
                                        colors: colors,
                                        message: language.t(
                                          'scanner_toast_added_single',
                                          {'name': dev.name, 'ip': dev.ip},
                                        ),
                                        icon: Icons.check_circle_rounded,
                                        accentColor: colors.accentEmerald,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 12),
                                  label: Text(
                                    language.t('scanner_btn_add'),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. Bento Grid View (2 Columns)
  Widget _buildGridView({
    required List<ManagedDevice> items,
    required Set<String> savedIps,
    required dynamic colors,
    required LanguageProvider language,
    required DeviceService deviceService,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final dev = items[index];
        final isAlreadyAdded = savedIps.contains(dev.ip);
        final isSelected = _selectedIps.contains(dev.ip);

        return InkWell(
          onTap: isAlreadyAdded
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedIps.remove(dev.ip);
                    } else {
                      _selectedIps.add(dev.ip);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accentCyan.withValues(alpha: 0.12)
                  : colors.cardBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? colors.accentCyan : colors.borderDefault,
              ),
            ),
            child: Row(
              children: [
                // Selection or Saved
                if (isAlreadyAdded)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.accentEmerald,
                    size: 16,
                  )
                else
                  Checkbox(
                    value: isSelected,
                    activeColor: colors.accentCyan,
                    checkColor: Colors.white,
                    side: BorderSide(color: colors.borderDefault, width: 1.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIps.add(dev.ip);
                        } else {
                          _selectedIps.remove(dev.ip);
                        }
                      });
                    },
                  ),
                const SizedBox(width: 4),

                Icon(
                  Icons.computer_rounded,
                  size: 16,
                  color: isAlreadyAdded
                      ? colors.accentEmerald
                      : colors.accentCyan,
                ),
                const SizedBox(width: 8),

                // Name & IP
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dev.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dev.ip,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: colors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ping badge
                if (dev.pingMs != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (dev.pingMs! <= 50
                                  ? colors.accentEmerald
                                  : colors.accentAmber)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${dev.pingMs}ms',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: dev.pingMs! <= 50
                            ? colors.accentEmerald
                            : colors.accentAmber,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),

                // Add or Saved
                if (isAlreadyAdded)
                  Text(
                    language.t('scanner_saved'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.accentEmerald,
                    ),
                  )
                else
                  SizedBox(
                    height: 23,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accentCyan,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () async {
                        await deviceService.addDevice(dev);
                        if (mounted) {
                          showAppToast(
                            context,
                            colors: colors,
                            message: language.t('scanner_toast_added_single', {
                              'name': dev.name,
                              'ip': dev.ip,
                            }),
                            icon: Icons.check_circle_rounded,
                            accentColor: colors.accentEmerald,
                          );
                        }
                      },
                      child: Text(
                        language.t('scanner_btn_add'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Detailed Card List View (Optimized padding)
  Widget _buildListView({
    required List<ManagedDevice> items,
    required Set<String> savedIps,
    required dynamic colors,
    required LanguageProvider language,
    required DeviceService deviceService,
  }) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.cardBorder),
      itemBuilder: (ctx, index) {
        final dev = items[index];
        final isAlreadyAdded = savedIps.contains(dev.ip);
        final isSelected = _selectedIps.contains(dev.ip);

        return InkWell(
          onTap: isAlreadyAdded
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedIps.remove(dev.ip);
                    } else {
                      _selectedIps.add(dev.ip);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accentCyan.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // Selection Checkbox or Saved Icon
                if (isAlreadyAdded)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: colors.accentEmerald,
                      size: 18,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Checkbox(
                      value: isSelected,
                      activeColor: colors.accentCyan,
                      checkColor: Colors.white,
                      side: BorderSide(color: colors.borderDefault, width: 1.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIps.add(dev.ip);
                          } else {
                            _selectedIps.remove(dev.ip);
                          }
                        });
                      },
                    ),
                  ),

                // Computer Icon
                Icon(
                  Icons.computer_rounded,
                  color: isAlreadyAdded
                      ? colors.accentEmerald
                      : colors.accentCyan,
                  size: 18,
                ),
                const SizedBox(width: 10),

                // Name & Hostname
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dev.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        dev.hostname,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // IP
                Expanded(
                  flex: 2,
                  child: Text(
                    dev.ip,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: colors.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // MAC
                Expanded(
                  flex: 2,
                  child: Text(
                    dev.mac ?? '--',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ),

                // Latency Badge
                if (dev.pingMs != null)
                  LatencyBadge(latencyMs: dev.pingMs!, colors: colors),
                const SizedBox(width: 12),

                // Saved badge or Add button
                if (isAlreadyAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.accentEmerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: colors.accentEmerald,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          language.t('scanner_saved'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: colors.accentEmerald,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GlassButton(
                    label: language.t('scanner_btn_add'),
                    icon: Icons.add_rounded,
                    colors: colors,
                    accentColor: colors.accentCyan,
                    onTap: () async {
                      await deviceService.addDevice(dev);
                      if (mounted) {
                        showAppToast(
                          context,
                          colors: colors,
                          message: language.t('scanner_toast_added_single', {
                            'name': dev.name,
                            'ip': dev.ip,
                          }),
                          icon: Icons.check_circle_rounded,
                          accentColor: colors.accentEmerald,
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyIdleOrScanning(
    bool isScanning,
    dynamic colors,
    LanguageProvider language,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isScanning ? Icons.sync_rounded : Icons.search_off_rounded,
            size: 44,
            color: colors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            isScanning
                ? language.t('scanner_empty_scanning')
                : language.t('scanner_empty_idle'),
            style: TextStyle(color: colors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterMatch(dynamic colors, LanguageProvider language) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 40,
            color: colors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            language.t('scanner_no_filter_match'),
            style: TextStyle(color: colors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          GlassButton(
            label: language.t('scanner_clear_filter'),
            icon: Icons.refresh_rounded,
            colors: colors,
            onTap: () {
              setState(() {
                _searchController.clear();
                _filterMode = 'all';
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addSelectedDevices({
    required dynamic colors,
    required LanguageProvider language,
    required DeviceService deviceService,
    required List<ManagedDevice> allDiscovered,
    required Set<String> savedIps,
  }) async {
    final toAdd = allDiscovered
        .where((d) => _selectedIps.contains(d.ip) && !savedIps.contains(d.ip))
        .toList();

    if (toAdd.isEmpty) {
      setState(() => _selectedIps.clear());
      return;
    }

    await deviceService.addDevices(toAdd);
    setState(() => _selectedIps.clear());

    if (mounted) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('scanner_toast_added_batch', {
          'count': toAdd.length.toString(),
        }),
        icon: Icons.check_circle_rounded,
        accentColor: colors.accentEmerald,
      );
    }
  }

  Future<void> _addAllUnaddedDevices({
    required dynamic colors,
    required LanguageProvider language,
    required DeviceService deviceService,
    required List<ManagedDevice> items,
    required Set<String> savedIps,
  }) async {
    final toAdd = items.where((d) => !savedIps.contains(d.ip)).toList();
    if (toAdd.isEmpty) return;

    await deviceService.addDevices(toAdd);
    setState(() {
      _selectedIps.removeWhere((ip) => toAdd.any((d) => d.ip == ip));
    });

    if (mounted) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('scanner_toast_added_all', {
          'count': toAdd.length.toString(),
        }),
        icon: Icons.check_circle_rounded,
        accentColor: colors.accentEmerald,
      );
    }
  }
}
