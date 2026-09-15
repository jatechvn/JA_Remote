import '../../widgets/route_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_search_history_field.dart';
import '../../widgets/app_toast.dart';
import '../../services/discovery_service.dart';
import '../../services/device_service.dart';
import '../../core/network/network_utils.dart';
import '../../core/network/mac_oui_resolver.dart';
import '../../core/utils/everything_search_matcher.dart';
import '../../data/models/managed_device.dart';

class DiscoveryView extends StatefulWidget {
  final bool isActive;
  const DiscoveryView({super.key, this.isActive = false});

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  late TextEditingController _subnetController;
  late TextEditingController _searchController;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final discovery = context.read<DiscoveryService>();
    _subnetController = TextEditingController(text: discovery.currentSubnet);
    _searchController = TextEditingController(text: discovery.searchQuery);
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DiscoveryView oldWidget) {
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
    _subnetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(String column) {
    context.read<DiscoveryService>().setSort(column);
  }

  List<ManagedDevice> _getSortedDiscoveredItems(
    List<ManagedDevice> items,
    DiscoveryService discovery,
  ) {
    final list = List<ManagedDevice>.of(items);
    final sortCol = discovery.sortColumn;
    final sortAsc = discovery.sortAscending;
    list.sort((a, b) {
      int cmp = 0;
      switch (sortCol) {
        case 'device':
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
        default:
          cmp = NetworkUtils.compareIps(a.ip, b.ip);
      }
      return sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Widget _buildSortHeader({
    required String title,
    required String columnKey,
    required dynamic colors,
    required DiscoveryService discovery,
    int? flex,
    double? width,
  }) {
    final isActive = discovery.sortColumn == columnKey;
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
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isActive ? colors.accentCyan : colors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              isActive
                  ? (discovery.sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 12,
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

    if (!_searchFocus.hasFocus &&
        _searchController.text != discovery.searchQuery) {
      _searchController.text = discovery.searchQuery;
    }

    final isScanning = discovery.isScanning;
    final allDiscovered = discovery.discoveredDevices;
    final adapters = discovery.availableAdapters;
    final showAdapters = discovery.showAdapters;
    final filterMode = discovery.filterMode;
    final selectedIps = discovery.selectedIps;

    final savedIps = deviceService.devices.map((d) => d.ip).toSet();
    final query = discovery.searchQuery.trim();

    // Clean up selected IPs that no longer exist in discovered devices
    if (allDiscovered.isNotEmpty) {
      final discoveredIps = allDiscovered.map((d) => d.ip).toSet();
      final staleSelectedIps = selectedIps.difference(discoveredIps);
      if (staleSelectedIps.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          discovery.removeSelectedIps(staleSelectedIps);
        });
      }
    }

    final unaddedCount = allDiscovered
        .where((d) => !savedIps.contains(d.ip))
        .length;
    final addedCount = allDiscovered
        .where((d) => savedIps.contains(d.ip))
        .length;
    final fastCount = allDiscovered
        .where((d) => d.pingMs != null && d.pingMs! <= 50)
        .length;

    final rawFiltered = allDiscovered.where((dev) {
      final isAlreadyAdded = savedIps.contains(dev.ip);

      switch (filterMode) {
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
          targets: [
            dev.name,
            dev.ip,
            dev.hostname,
            dev.mac,
            MacOuiResolver.lookup(dev.mac),
          ],
        )) {
          return false;
        }
      }

      return true;
    }).toList();

    final filteredItems = _getSortedDiscoveredItems(rawFiltered, discovery);

    // Check if all unadded filtered items are selected
    final unaddedFiltered = filteredItems
        .where((d) => !savedIps.contains(d.ip))
        .toList();
    final isAllFilteredSelected =
        unaddedFiltered.isNotEmpty &&
        unaddedFiltered.every((d) => selectedIps.contains(d.ip));
    final selectedCount = selectedIps.length;

    return RouteShortcuts(
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
                          onChanged: discovery.setSubnet,
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
                          onTap: () => discovery.toggleShowAdapters(),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: showAdapters
                                  ? colors.accentCyan.withValues(alpha: 0.18)
                                  : colors.cardBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: showAdapters
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
                                  color: showAdapters
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
                                    fontWeight: showAdapters
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: showAdapters
                                        ? colors.accentCyan
                                        : colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  showAdapters
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: showAdapters
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
                  if (showAdapters && adapters.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GlassHorizontalScrollView(
                      colors: colors,
                      child: Row(
                        children: [
                          for (final adapter in adapters) ...[
                            Padding(
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
                                    color:
                                        _subnetController.text.trim() ==
                                            adapter.subnet
                                        ? colors.accentCyan.withValues(
                                            alpha: 0.2,
                                          )
                                        : colors.cardBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          _subnetController.text.trim() ==
                                              adapter.subnet
                                          ? colors.accentCyan
                                          : colors.borderDefault,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        adapter.isVirtual
                                            ? Icons.cloud_queue_rounded
                                            : Icons.settings_ethernet_rounded,
                                        size: 12,
                                        color:
                                            _subnetController.text.trim() ==
                                                adapter.subnet
                                            ? colors.accentCyan
                                            : (adapter.isVirtual
                                                  ? colors.accentAmber
                                                  : colors.accentEmerald),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${adapter.name}: ${adapter.subnet}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight:
                                              _subnetController.text.trim() ==
                                                  adapter.subnet
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color:
                                              _subnetController.text.trim() ==
                                                  adapter.subnet
                                              ? colors.accentCyan
                                              : colors.textPrimary,
                                        ),
                                      ),
                                      if (adapter.prefixLength < 24) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.accentCyan.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            '/${adapter.prefixLength} Supernet',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              color: colors.accentCyan,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (adapter.isVirtual) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.accentAmber
                                                .withValues(alpha: 0.2),
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
                            ),
                            // Quick chips for subnets if supernet
                            if (adapter.subSlices.length > 1) ...[
                              for (final slice in adapter.subSlices) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _subnetController.text = slice;
                                      });
                                      discovery.setSubnet(slice);
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _subnetController.text.trim() ==
                                                slice
                                            ? colors.accentCyan.withValues(
                                                alpha: 0.25,
                                              )
                                            : colors.cardBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              _subnetController.text.trim() ==
                                                  slice
                                              ? colors.accentCyan
                                              : colors.borderDefault,
                                        ),
                                      ),
                                      child: Text(
                                        slice.contains('.')
                                            ? '.${slice.split('.')[2]}.0/24'
                                            : slice,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontFamily: 'monospace',
                                          fontWeight:
                                              _subnetController.text.trim() ==
                                                  slice
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color:
                                              _subnetController.text.trim() ==
                                                  slice
                                              ? colors.accentCyan
                                              : colors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                            ],
                          ],
                        ],
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
                      discovery: discovery,
                      allCount: allDiscovered.length,
                      filteredCount: filteredItems.length,
                      unaddedCount: unaddedCount,
                      unaddedFilteredCount: unaddedFiltered.length,
                      addedCount: addedCount,
                      fastCount: fastCount,
                      selectedCount: selectedCount,
                      isAllSelected: isAllFilteredSelected,
                      hasUnaddedFiltered: unaddedFiltered.isNotEmpty,
                      onToggleSelectAll: () {
                        if (isAllFilteredSelected) {
                          discovery.removeSelectedIps(
                            unaddedFiltered.map((d) => d.ip),
                          );
                        } else {
                          discovery.selectAllIps(
                            unaddedFiltered.map((d) => d.ip),
                          );
                        }
                      },
                      onAddSelected: selectedCount > 0
                          ? () => _addSelectedDevices(
                              colors: colors,
                              language: language,
                              deviceService: deviceService,
                              discovery: discovery,
                              allDiscovered: allDiscovered,
                              savedIps: savedIps,
                            )
                          : null,
                      onAddAllUnadded: unaddedFiltered.isNotEmpty
                          ? () => _addAllUnaddedDevices(
                              colors: colors,
                              language: language,
                              deviceService: deviceService,
                              discovery: discovery,
                              items: unaddedFiltered,
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
                          ? _buildEmptyFilterMatch(colors, language, discovery)
                          : _buildDiscoveredContent(
                              items: filteredItems,
                              savedIps: savedIps,
                              colors: colors,
                              language: language,
                              deviceService: deviceService,
                              discovery: discovery,
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
    required DiscoveryService discovery,
    required int allCount,
    required int filteredCount,
    required int unaddedCount,
    required int unaddedFilteredCount,
    required int addedCount,
    required int fastCount,
    required int selectedCount,
    required bool isAllSelected,
    required bool hasUnaddedFiltered,
    required VoidCallback onToggleSelectAll,
    required VoidCallback? onAddSelected,
    required VoidCallback? onAddAllUnadded,
  }) {
    final isFiltered = filteredCount != allCount;

    return Row(
      children: [
        // Hosts Count Title
        Icon(Icons.devices_other_rounded, color: colors.accentCyan, size: 17),
        const SizedBox(width: 6),
        Text(
          isFiltered ? 'HOSTS ($filteredCount/$allCount)' : 'HOSTS ($allCount)',
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
          discovery: discovery,
        ),
        const SizedBox(width: 5),
        _buildFilterChip(
          label: language.t('scanner_filter_unadded'),
          count: unaddedCount,
          mode: 'unadded',
          colors: colors,
          accentColor: colors.accentCyan,
          highlightBadge: unaddedCount > 0,
          discovery: discovery,
        ),
        const SizedBox(width: 5),
        _buildFilterChip(
          label: language.t('scanner_filter_added'),
          count: addedCount,
          mode: 'added',
          colors: colors,
          accentColor: colors.accentEmerald,
          discovery: discovery,
        ),
        const SizedBox(width: 5),
        _buildFilterChip(
          label: language.t('scanner_filter_fast'),
          count: fastCount,
          mode: 'fast',
          colors: colors,
          accentColor: colors.accentAmber,
          discovery: discovery,
        ),
        const SizedBox(width: 10),

        // Search Input Box (Compact with history suggestions)
        SizedBox(
          width: 185,
          child: GlassSearchHistoryField(
            controller: _searchController,
            focusNode: _searchFocus,
            category: 'scanner',
            hintText: language.t('scanner_search_hint'),
            height: 30,
            fontSize: 11.5,
            hintFontSize: 10.5,
            minOverlayWidth: 260,
            borderRadius: 6,
            suffixBadge: discovery.searchQuery.trim().isNotEmpty
                ? Container(
                    margin: const EdgeInsets.only(right: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: colors.accentCyan.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '$filteredCount',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: colors.accentCyan,
                      ),
                    ),
                  )
                : null,
            onChanged: (val) => discovery.setSearchQuery(val),
            onSubmitted: (val) => discovery.setSearchQuery(val),
            onClear: () {
              _searchController.clear();
              discovery.setSearchQuery('');
            },
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
                discovery: discovery,
              ),
              _buildViewModeIcon(
                mode: 'grid',
                icon: Icons.grid_view_rounded,
                tooltip: language.t('scanner_view_grid'),
                colors: colors,
                discovery: discovery,
              ),
              _buildViewModeIcon(
                mode: 'list',
                icon: Icons.view_agenda_rounded,
                tooltip: language.t('scanner_view_list'),
                colors: colors,
                discovery: discovery,
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
        if (unaddedFilteredCount > 0 && onAddAllUnadded != null)
          GlassButton(
            label: language.t('scanner_btn_add_unadded', {
              'count': unaddedFilteredCount.toString(),
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
    required DiscoveryService discovery,
  }) {
    final isSelected = discovery.viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => discovery.setViewMode(mode),
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
    required DiscoveryService discovery,
    Color? accentColor,
    bool highlightBadge = false,
  }) {
    final isSelected = discovery.filterMode == mode;
    final activeColor = accentColor ?? colors.accentCyan;

    return InkWell(
      onTap: () {
        discovery.setFilterMode(mode);
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
    required DiscoveryService discovery,
    required List<ManagedDevice> unaddedFiltered,
    required bool isAllFilteredSelected,
  }) {
    switch (discovery.viewMode) {
      case 'grid':
        return _buildGridView(
          items: items,
          savedIps: savedIps,
          colors: colors,
          language: language,
          deviceService: deviceService,
          discovery: discovery,
        );
      case 'list':
        return _buildListView(
          items: items,
          savedIps: savedIps,
          colors: colors,
          language: language,
          deviceService: deviceService,
          discovery: discovery,
        );
      case 'table':
      default:
        return _buildTableView(
          items: items,
          savedIps: savedIps,
          colors: colors,
          language: language,
          deviceService: deviceService,
          discovery: discovery,
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
    required DiscoveryService discovery,
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
                          if (isAllFilteredSelected) {
                            discovery.removeSelectedIps(
                              unaddedFiltered.map((d) => d.ip),
                            );
                          } else {
                            discovery.selectAllIps(
                              unaddedFiltered.map((d) => d.ip),
                            );
                          }
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
              _buildSortHeader(
                title: '${language.t('scanner_col_device')} (${items.length})',
                columnKey: 'device',
                flex: 4,
                colors: colors,
                discovery: discovery,
              ),
              _buildSortHeader(
                title: language.t('scanner_col_ip'),
                columnKey: 'ip',
                flex: 3,
                colors: colors,
                discovery: discovery,
              ),
              _buildSortHeader(
                title: language.t('scanner_col_mac'),
                columnKey: 'mac',
                flex: 3,
                colors: colors,
                discovery: discovery,
              ),
              _buildSortHeader(
                title: language.t('scanner_col_ping'),
                columnKey: 'ping',
                width: 70,
                colors: colors,
                discovery: discovery,
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
              final isSelected = discovery.selectedIps.contains(dev.ip);
              final isResolving = discovery.isResolvingHost(dev.ip);

              return InkWell(
                onTap: isAlreadyAdded
                    ? null
                    : () => discovery.toggleSelectIp(dev.ip),
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
                                onChanged: isAlreadyAdded
                                    ? null
                                    : (_) => discovery.toggleSelectIp(dev.ip),
                              ),
                      ),

                      // Device Name & Hostname inline
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Icon(
                              MacOuiResolver.isNetworkDevice(dev.mac)
                                  ? Icons.router_rounded
                                  : Icons.computer_rounded,
                              size: 14,
                              color: isAlreadyAdded
                                  ? colors.accentEmerald
                                  : colors.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: isResolving
                                  ? Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            dev.name,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.accentAmber
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: colors.accentAmber
                                                  .withValues(alpha: 0.35),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 8,
                                                height: 8,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.3,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(colors.accentAmber),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                language.t(
                                                  'scanner_resolving_host',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: colors.accentAmber,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text.rich(
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
                                            )
                                          else if (dev.hostname.isEmpty ||
                                              dev.hostname == dev.ip)
                                            TextSpan(
                                              text:
                                                  ' (${language.t('scanner_no_hostname')})',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontStyle: FontStyle.italic,
                                                color: colors.textMuted
                                                    .withValues(alpha: 0.7),
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

                      // MAC Address & Vendor
                      Expanded(
                        flex: 3,
                        child: () {
                          final vendor =
                              MacOuiResolver.lookup(dev.mac) ??
                              (MacOuiResolver.isLocallyAdministered(dev.mac)
                                  ? 'Private MAC'
                                  : null);
                          return Row(
                            children: [
                              Flexible(
                                child: Text(
                                  dev.mac ?? '--',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10.5,
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (vendor != null) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accentCyan.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: colors.accentCyan.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    vendor,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: colors.accentCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }(),
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
    required DiscoveryService discovery,
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
        final isSelected = discovery.selectedIps.contains(dev.ip);
        final isResolving = discovery.isResolvingHost(dev.ip);

        return InkWell(
          onTap: isAlreadyAdded ? null : () => discovery.toggleSelectIp(dev.ip),
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
                    onChanged: isAlreadyAdded
                        ? null
                        : (_) => discovery.toggleSelectIp(dev.ip),
                  ),
                const SizedBox(width: 4),

                Icon(
                  MacOuiResolver.isNetworkDevice(dev.mac)
                      ? Icons.router_rounded
                      : Icons.computer_rounded,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              dev.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isResolving) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentAmber.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: colors.accentAmber.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 7,
                                    height: 7,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.1,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colors.accentAmber,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    language.t('scanner_resolving_host'),
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w500,
                                      color: colors.accentAmber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      () {
                        final vendor =
                            MacOuiResolver.lookup(dev.mac) ??
                            (MacOuiResolver.isLocallyAdministered(dev.mac)
                                ? 'Private MAC'
                                : null);
                        return Row(
                          children: [
                            Text(
                              dev.ip,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: colors.accentCyan,
                              ),
                            ),
                            if (vendor != null) ...[
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '• $vendor',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        );
                      }(),
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
    required DiscoveryService discovery,
  }) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.cardBorder),
      itemBuilder: (ctx, index) {
        final dev = items[index];
        final isAlreadyAdded = savedIps.contains(dev.ip);
        final isSelected = discovery.selectedIps.contains(dev.ip);
        final isResolving = discovery.isResolvingHost(dev.ip);

        return InkWell(
          onTap: isAlreadyAdded ? null : () => discovery.toggleSelectIp(dev.ip),
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
                      onChanged: isAlreadyAdded
                          ? null
                          : (_) => discovery.toggleSelectIp(dev.ip),
                    ),
                  ),

                // Computer Icon
                Icon(
                  MacOuiResolver.isNetworkDevice(dev.mac)
                      ? Icons.router_rounded
                      : Icons.computer_rounded,
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
                      if (isResolving)
                        Row(
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.accentAmber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              language.t('scanner_resolving_host'),
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: colors.accentAmber,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          (dev.hostname.isNotEmpty && dev.hostname != dev.ip)
                              ? dev.hostname
                              : language.t('scanner_no_hostname'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: colors.textMuted,
                            fontStyle:
                                (dev.hostname.isEmpty || dev.hostname == dev.ip)
                                ? FontStyle.italic
                                : FontStyle.normal,
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

                // MAC & Vendor
                Expanded(
                  flex: 2,
                  child: () {
                    final vendor =
                        MacOuiResolver.lookup(dev.mac) ??
                        (MacOuiResolver.isLocallyAdministered(dev.mac)
                            ? 'Private MAC'
                            : null);
                    return Row(
                      children: [
                        Flexible(
                          child: Text(
                            dev.mac ?? '--',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vendor != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentCyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: colors.accentCyan.withValues(
                                  alpha: 0.25,
                                ),
                                width: 0.7,
                              ),
                            ),
                            child: Text(
                              vendor,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: colors.accentCyan,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }(),
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

  Widget _buildEmptyFilterMatch(
    dynamic colors,
    LanguageProvider language,
    DiscoveryService discovery,
  ) {
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
              _searchController.clear();
              discovery.clearFilters();
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
    required DiscoveryService discovery,
    required List<ManagedDevice> allDiscovered,
    required Set<String> savedIps,
  }) async {
    final toAdd = allDiscovered
        .where(
          (d) =>
              discovery.selectedIps.contains(d.ip) && !savedIps.contains(d.ip),
        )
        .toList();

    if (toAdd.isEmpty) {
      discovery.deselectAllIps();
      return;
    }

    await deviceService.addDevices(toAdd);
    discovery.deselectAllIps();

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
    required DiscoveryService discovery,
    required List<ManagedDevice> items,
    required Set<String> savedIps,
  }) async {
    final toAdd = items.where((d) => !savedIps.contains(d.ip)).toList();
    if (toAdd.isEmpty) return;

    await deviceService.addDevices(toAdd);
    discovery.removeSelectedIps(toAdd.map((d) => d.ip));

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
