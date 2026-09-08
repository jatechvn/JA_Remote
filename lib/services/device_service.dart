import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../core/network/ping_engine.dart';
import '../data/models/managed_device.dart';
import '../data/repositories/device_repository.dart';
import '../core/utils/everything_search_matcher.dart';
import 'power_service.dart';

/// Central state manager for devices, filtering, selection, and periodic status polling.
class DeviceService extends ChangeNotifier {
  final DeviceRepository _repo = DeviceRepository();
  final PowerService _powerService = PowerService();

  List<ManagedDevice> _devices = [];
  final Set<String> _selectedIds = {};

  String _searchQuery = '';
  String _selectedGroup = 'All';
  String _statusFilter = 'All'; // 'All', 'Online', 'Offline'
  bool _isLoading = false;
  bool _isPolling = true;

  Timer? _pollingTimer;

  List<ManagedDevice> get devices => UnmodifiableListView(_devices);
  Set<String> get selectedIds => UnmodifiableSetView(_selectedIds);
  String get searchQuery => _searchQuery;
  String get selectedGroup => _selectedGroup;
  String get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  bool get isPolling => _isPolling;

  int get onlineCount => _devices.where((d) => d.online).length;
  int get totalCount => _devices.length;

  /// Returns list of all unique groups
  List<String> get availableGroups {
    final groups = _devices.map((d) => d.group).toSet().toList();
    groups.sort();
    return ['All', ...groups];
  }

  /// Filtered list of devices based on search, group, and status
  List<ManagedDevice> get filteredDevices {
    return _devices.where((d) {
      // Group filter
      if (_selectedGroup != 'All' && d.group != _selectedGroup) {
        return false;
      }
      // Status filter
      if (_statusFilter == 'Online' && !d.online) return false;
      if (_statusFilter == 'Offline' && d.online) return false;

      // Search query (multi-term Everything-style search: AND, OR |, NOT -/!)
      if (_searchQuery.isNotEmpty) {
        if (!EverythingSearchMatcher.matches(
          query: _searchQuery,
          targets: [d.name, d.ip, d.hostname, d.mac, d.group, d.note],
        )) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  DeviceService() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    _devices = await _repo.loadDevices();
    _isLoading = false;
    notifyListeners();

    // Perform initial fast ping on all devices
    await refreshAllStatus();

    // Start background ping polling every 10 seconds
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isPolling && _devices.isNotEmpty) {
        refreshAllStatus();
      }
    });
  }

  void togglePolling() {
    _isPolling = !_isPolling;
    notifyListeners();
  }

  /// Pings all registered devices to refresh online/offline & latency state
  Future<void> refreshAllStatus() async {
    final ips = _devices.map((d) => d.ip).toList();
    if (ips.isEmpty) return;

    final sub = PingEngine.pingBatch(ips, maxConcurrent: 10, timeoutMs: 350)
        .listen((res) {
          final index = _devices.indexWhere((d) => d.ip == res.ip);
          if (index >= 0) {
            final old = _devices[index];
            _devices[index] = old.copyWith(
              online: res.isOnline,
              pingMs: res.latencyMs,
              lastSeen: res.isOnline ? DateTime.now() : old.lastSeen,
            );
            notifyListeners();
          }
        });

    await sub.asFuture();
    await _repo.saveAll(_devices);
  }

  // --- Search & Filtering ---
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setGroup(String group) {
    _selectedGroup = group;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  // --- Multi-selection ---
  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    final currentFiltered = filteredDevices;
    _selectedIds.addAll(currentFiltered.map((d) => d.id));
    notifyListeners();
  }

  void selectOnlyOnline() {
    _selectedIds.clear();
    final onlines = filteredDevices.where((d) => d.online);
    _selectedIds.addAll(onlines.map((d) => d.id));
    notifyListeners();
  }

  void deselectAll() {
    _selectedIds.clear();
    notifyListeners();
  }

  List<ManagedDevice> get selectedDevices {
    return _devices.where((d) => _selectedIds.contains(d.id)).toList();
  }

  // --- Device Management (CRUD) ---
  Future<void> reloadDevices() async {
    _devices = await _repo.loadDevices();
    notifyListeners();
    await refreshAllStatus();
  }

  Future<void> addDevice(ManagedDevice device) async {
    await _repo.upsert(device);
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  Future<void> addDevices(List<ManagedDevice> newDevices) async {
    for (final dev in newDevices) {
      await _repo.upsert(dev);
    }
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  Future<void> updateDevice(ManagedDevice device) async {
    await _repo.upsert(device);
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    _selectedIds.remove(id);
    await _repo.delete(id);
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  Future<void> removeDevices(List<String> ids) async {
    _selectedIds.removeAll(ids);
    await _repo.deleteMultiple(ids);
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  Future<void> removeSelectedDevices() async {
    final toRemove = _selectedIds.toList();
    if (toRemove.isEmpty) return;
    await _repo.deleteMultiple(toRemove);
    _selectedIds.clear();
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  Future<void> batchUpdateGroup(String newGroup) async {
    final toUpdate = _selectedIds.toList();
    if (toUpdate.isEmpty) return;
    await _repo.updateGroupForMultiple(toUpdate, newGroup);
    _devices = await _repo.loadDevices();
    notifyListeners();
  }

  // --- Batch Power Actions ---
  Future<void> batchWakeSelected() async {
    for (final dev in selectedDevices) {
      if (dev.mac != null && dev.mac!.isNotEmpty) {
        await _powerService.wakeDevice(dev);
      }
    }
  }

  Future<void> batchRestartSelected() async {
    for (final dev in selectedDevices) {
      await _powerService.restartDevice(dev);
    }
  }

  Future<void> batchShutdownSelected() async {
    for (final dev in selectedDevices) {
      await _powerService.shutdownDevice(dev);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
