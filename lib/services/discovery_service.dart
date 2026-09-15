import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/network/network_utils.dart';
import '../core/network/ping_engine.dart';
import '../core/network/host_resolver.dart';
import '../core/network/arp_resolver.dart';
import '../core/network/mac_oui_resolver.dart';
import '../data/models/managed_device.dart';

/// LAN Network Discovery Service that scans CIDR ranges and streams discovered devices.
class DiscoveryService extends ChangeNotifier {
  bool _isScanning = false;
  double _progress = 0.0;
  int _scannedCount = 0;
  int _totalCount = 0;
  String _currentSubnet = '192.168.1.0/24';
  final List<ManagedDevice> _discoveredDevices = [];
  List<NetworkInterfaceDetails> _availableAdapters = [];

  // Persistent UI filter, sort, and view state across tab transitions
  String _searchQuery = '';
  String _filterMode = 'all'; // 'all', 'unadded', 'added', 'fast'
  String _sortColumn = 'ip'; // 'device', 'ip', 'mac', 'ping'
  bool _sortAscending = true;
  String _viewMode = 'table'; // 'table', 'grid', 'list'
  bool _showAdapters = false;
  final Set<String> _selectedIps = {};

  StreamSubscription? _scanSub;
  int _scanRevision = 0;
  int _adapterRevision = 0;
  bool _disposed = false;
  bool _subnetChosen = false;
  Timer? _progressNotification;
  final Duration progressNotificationInterval;

  // Coalesce bursty ping/hostname updates without delaying the underlying data.
  void _notifyProgress() {
    if (_disposed) return;
    if (progressNotificationInterval == Duration.zero) {
      notifyListeners();
      return;
    }
    _progressNotification ??= Timer(progressNotificationInterval, () {
      _progressNotification = null;
      if (!_disposed) notifyListeners();
    });
  }

  void _notifyCompletion() {
    _progressNotification?.cancel();
    _progressNotification = null;
    if (!_disposed) notifyListeners();
  }

  final Future<Set<String>> Function() _getLocalIps;
  final Future<Map<String, String>> Function() _getArpTable;
  final Future<String> Function(String) _resolveHost;
  final Stream<PingResult> Function(List<String>, int, int) _ping;

  final Set<String> _resolvingHostIps = {};

  bool _isCurrentScan(int revision) =>
      !_disposed && _isScanning && revision == _scanRevision;

  bool get isScanning => _isScanning;
  double get progress => _progress;
  int get scannedCount => _scannedCount;
  int get totalCount => _totalCount;
  String get currentSubnet => _currentSubnet;
  List<ManagedDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  List<NetworkInterfaceDetails> get availableAdapters =>
      List.unmodifiable(_availableAdapters);
  bool isResolvingHost(String ip) => _resolvingHostIps.contains(ip);
  Set<String> get resolvingHostIps => Set.unmodifiable(_resolvingHostIps);

  // Getters for persistent UI states
  String get searchQuery => _searchQuery;
  String get filterMode => _filterMode;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;
  String get viewMode => _viewMode;
  bool get showAdapters => _showAdapters;
  Set<String> get selectedIps => Set.unmodifiable(_selectedIps);

  DiscoveryService({
    this.progressNotificationInterval = const Duration(milliseconds: 50),
    bool initialize = true,
    Future<Set<String>> Function()? getLocalIps,
    Future<Map<String, String>> Function()? getArpTable,
    Future<String> Function(String)? resolveHost,
    Stream<PingResult> Function(List<String>, int, int)? ping,
  }) : _getLocalIps = getLocalIps ?? NetworkUtils.getHostDeviceIps,
       _getArpTable = getArpTable ?? ArpResolver.getArpTable,
       _resolveHost = resolveHost ?? HostResolver.resolve,
       _ping =
           ping ??
           ((ips, concurrency, timeout) => PingEngine.pingBatch(
             ips,
             maxConcurrent: concurrency,
             timeoutMs: timeout,
           )) {
    if (initialize) _initDefaultSubnet();
  }

  Future<void> _initDefaultSubnet() async {
    await refreshAdapters();
    if (_disposed) return;
    final subnet = await NetworkUtils.getDefaultLocalSubnet();
    if (_disposed || _subnetChosen) return;
    _currentSubnet = subnet;
    notifyListeners();
  }

  /// Reloads available network adapters from system
  Future<void> refreshAdapters() async {
    if (_disposed) return;
    final revision = ++_adapterRevision;
    final adapters = await NetworkUtils.getAvailableAdapters();
    if (_disposed || revision != _adapterRevision) return;
    _availableAdapters = adapters;
    notifyListeners();
  }

  void setSubnet(String subnet) {
    if (_disposed) return;
    _subnetChosen = true;
    _currentSubnet = subnet.trim();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_disposed || _searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterMode(String mode) {
    if (_disposed || _filterMode == mode) return;
    _filterMode = mode;
    notifyListeners();
  }

  void setSort(String column, {bool? ascending}) {
    if (_disposed) return;
    if (_sortColumn == column && ascending == null) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = ascending ?? true;
    }
    notifyListeners();
  }

  void setViewMode(String mode) {
    if (_disposed || _viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  void toggleShowAdapters() {
    if (_disposed) return;
    _showAdapters = !_showAdapters;
    notifyListeners();
  }

  void setShowAdapters(bool show) {
    if (_disposed || _showAdapters == show) return;
    _showAdapters = show;
    notifyListeners();
  }

  void toggleSelectIp(String ip) {
    if (_disposed) return;
    if (_selectedIps.contains(ip)) {
      _selectedIps.remove(ip);
    } else {
      _selectedIps.add(ip);
    }
    notifyListeners();
  }

  void selectAllIps(Iterable<String> ips) {
    if (_disposed) return;
    _selectedIps.addAll(ips);
    notifyListeners();
  }

  void deselectAllIps() {
    if (_disposed || _selectedIps.isEmpty) return;
    _selectedIps.clear();
    notifyListeners();
  }

  void removeSelectedIps(Iterable<String> ips) {
    if (_disposed) return;
    _selectedIps.removeAll(ips);
    notifyListeners();
  }

  void clearFilters() {
    if (_disposed) return;
    _searchQuery = '';
    _filterMode = 'all';
    notifyListeners();
  }

  static bool _isValidUnicastMac(String? mac) {
    final clean = MacOuiResolver.cleanMac(mac);
    return clean != null &&
        clean != '000000000000' &&
        (int.parse(clean.substring(0, 2), radix: 16) & 1) == 0;
  }

  static int _compareIps(String ipA, String ipB) =>
      NetworkUtils.compareIps(ipA, ipB);

  Future<void> _dispatchHostResolution({
    required String ip,
    required int revision,
    required String localHostname,
  }) {
    _resolvingHostIps.add(ip);
    return _resolveHost(ip)
        .then((hostname) {
          if (_disposed || revision != _scanRevision) return;
          if (hostname.isNotEmpty && hostname != ip) {
            if (hostname.toLowerCase() == localHostname) {
              _discoveredDevices.removeWhere((d) => d.ip == ip);
              _notifyProgress();
              return;
            }

            final idx = _discoveredDevices.indexWhere((d) => d.ip == ip);
            if (idx != -1) {
              final old = _discoveredDevices[idx];
              _discoveredDevices[idx] = old.copyWith(
                hostname: hostname,
                name: hostname.split('.')[0],
              );
            }
          } else {
            final idx = _discoveredDevices.indexWhere((d) => d.ip == ip);
            if (idx != -1) {
              final old = _discoveredDevices[idx];
              final updatedName = MacOuiResolver.resolveFriendlyTitle(
                ip: ip,
                mac: old.mac,
                hostname: hostname,
              );
              if (old.name != updatedName) {
                _discoveredDevices[idx] = old.copyWith(name: updatedName);
              }
            }
          }
        })
        .catchError((_) {})
        .whenComplete(() {
          if (_disposed || revision != _scanRevision) return;
          _resolvingHostIps.remove(ip);
          _notifyProgress();
        });
  }

  void _reconcileWithArp({
    required Map<String, String> latestArp,
    required Set<String> targetIps,
    required Set<String> localIps,
    required String localHostname,
    required int revision,
    required List<Future<void>> pendingResolutions,
  }) {
    if (!_isCurrentScan(revision)) return;

    bool changed = false;

    // 1. Fill missing MAC and vendor names for already-discovered devices
    for (var i = 0; i < _discoveredDevices.length; i++) {
      final d = _discoveredDevices[i];
      if (d.mac == null && latestArp.containsKey(d.ip)) {
        final newMac = latestArp[d.ip];
        if (_isValidUnicastMac(newMac)) {
          final newName = (d.hostname.isEmpty || d.hostname == d.ip)
              ? MacOuiResolver.resolveFriendlyTitle(
                  ip: d.ip,
                  mac: newMac,
                  hostname: d.hostname,
                )
              : d.name;
          _discoveredDevices[i] = d.copyWith(
            mac: newMac,
            name: newName,
            os: MacOuiResolver.isNetworkDevice(newMac) ? 'Other' : d.os,
          );
          changed = true;
        }
      }
    }

    // 2. Discover devices present in ARP table but missed by ping (due to cold ARP drop or Windows Firewall ICMP block)
    final existingIps = _discoveredDevices.map((d) => d.ip).toSet();

    for (final entry in latestArp.entries) {
      final ip = entry.key;
      final mac = entry.value;

      if (!targetIps.contains(ip)) continue;
      if (localIps.contains(ip)) continue;
      if (existingIps.contains(ip)) continue;
      if (!_isValidUnicastMac(mac)) continue;

      existingIps.add(ip);
      changed = true;

      final initialName = MacOuiResolver.resolveFriendlyTitle(
        ip: ip,
        mac: mac,
        hostname: ip,
      );

      final dev = ManagedDevice(
        id: 'discovered_${ip.replaceAll('.', '_')}',
        name: initialName,
        hostname: ip,
        ip: ip,
        mac: mac,
        // An ARP cache entry is a candidate, not a measured ICMP reply.
        online: false,
        os: MacOuiResolver.isNetworkDevice(mac) ? 'Other' : 'Windows',
        group: 'Discovered',
        lastSeen: DateTime.now(),
      );

      _discoveredDevices.add(dev);
      pendingResolutions.add(
        _dispatchHostResolution(
          ip: ip,
          revision: revision,
          localHostname: localHostname,
        ),
      );
    }

    if (changed) {
      _notifyProgress();
    }
  }

  /// Starts scanning the specified subnet (e.g. 172.21.168.0/24)
  Future<void> startScan({
    String? subnet,
    int concurrency = 20,
    int timeoutMs = 400,
  }) async {
    if (_disposed || _isScanning) return;
    if (concurrency < 1 || timeoutMs < 1) {
      throw ArgumentError('Concurrency and timeout must be positive');
    }

    final targetSubnet = subnet ?? _currentSubnet;
    final ips = NetworkUtils.expandSubnet(targetSubnet);
    if (ips.isEmpty) return;
    final targetIpSet = ips.toSet();

    final revision = ++_scanRevision;
    _isScanning = true;
    _progress = 0.0;
    _scannedCount = 0;
    _totalCount = ips.length;
    _discoveredDevices.clear();
    _resolvingHostIps.clear();
    _selectedIps.clear();
    notifyListeners();

    late Set<String> localIps;
    late Map<String, String> arpTable;
    final localHostname = Platform.localHostname.toLowerCase();
    try {
      final preparation = await Future.wait<Object>([
        _getLocalIps(),
        _getArpTable(),
      ], eagerError: true);
      if (!_isCurrentScan(revision)) return;
      localIps = preparation[0] as Set<String>;
      arpTable = preparation[1] as Map<String, String>;
    } catch (_) {
      if (_isCurrentScan(revision)) {
        _isScanning = false;
        notifyListeners();
      }
      rethrow;
    }

    final pendingResolutions = <Future<void>>[];

    // Reconcile existing ARP entries immediately so known devices appear without delay
    _reconcileWithArp(
      latestArp: arpTable,
      targetIps: targetIpSet,
      localIps: localIps,
      localHostname: localHostname,
      revision: revision,
      pendingResolutions: pendingResolutions,
    );

    final effectiveConcurrency = (ips.length > 512 && concurrency == 20)
        ? 28
        : concurrency;
    final effectiveTimeout = (ips.length > 512 && timeoutMs == 400)
        ? 400
        : timeoutMs;

    _scanSub = _ping(ips, effectiveConcurrency, effectiveTimeout).listen(
      (result) {
        if (!_isCurrentScan(revision)) return;
        _scannedCount++;
        // During ping sweep, progress scales from 0% up to 92%
        _progress = (_scannedCount / _totalCount) * 0.92;

        if (result.isOnline) {
          final ip = result.ip;

          // Automatically exclude the current host machine (by local IP)
          if (localIps.contains(ip)) {
            _notifyProgress();
            return;
          }

          final existingIdx = _discoveredDevices.indexWhere((d) => d.ip == ip);
          if (existingIdx != -1) {
            // Already discovered via ARP reconciliation, update real latency
            final old = _discoveredDevices[existingIdx];
            _discoveredDevices[existingIdx] = old.copyWith(
              pingMs: result.latencyMs,
              online: true,
              lastSeen: DateTime.now(),
            );
            _notifyProgress();
            return;
          }

          final mac = arpTable[ip];
          final initialName = MacOuiResolver.resolveFriendlyTitle(
            ip: ip,
            mac: mac,
            hostname: ip,
          );

          // Add device IMMEDIATELY so the user sees it in real time
          final dev = ManagedDevice(
            id: 'discovered_${ip.replaceAll('.', '_')}',
            name: initialName,
            hostname: ip,
            ip: ip,
            mac: mac,
            online: true,
            pingMs: result.latencyMs,
            os: MacOuiResolver.isNetworkDevice(mac) ? 'Other' : 'Windows',
            group: 'Discovered',
            lastSeen: DateTime.now(),
          );

          _discoveredDevices.add(dev);
          pendingResolutions.add(
            _dispatchHostResolution(
              ip: ip,
              revision: revision,
              localHostname: localHostname,
            ),
          );
        }

        // Periodic ARP reconciliation every 128 items for real-time responsiveness
        if (_scannedCount % 128 == 0) {
          _getArpTable()
              .then((arp) {
                if (!_isCurrentScan(revision)) return;
                _reconcileWithArp(
                  latestArp: arp,
                  targetIps: targetIpSet,
                  localIps: localIps,
                  localHostname: localHostname,
                  revision: revision,
                  pendingResolutions: pendingResolutions,
                );
              })
              .catchError((_) {});
        }

        _notifyProgress();
      },
      onDone: () async {
        if (!_isCurrentScan(revision)) return;

        // Comprehensive ARP reconciliation at completion to catch all devices
        try {
          final latestArp = await _getArpTable();
          if (!_isCurrentScan(revision)) return;
          _reconcileWithArp(
            latestArp: latestArp,
            targetIps: targetIpSet,
            localIps: localIps,
            localHostname: localHostname,
            revision: revision,
            pendingResolutions: pendingResolutions,
          );
        } catch (_) {}

        // Wait for all in-flight hostname resolutions with a safe timeout
        if (pendingResolutions.isNotEmpty) {
          await Future.wait(
            pendingResolutions,
          ).timeout(const Duration(seconds: 3), onTimeout: () => []);
        }
        if (!_isCurrentScan(revision)) return;

        // Final ARP pass to resolve any late-arriving MACs
        try {
          final finalArp = await _getArpTable();
          if (!_isCurrentScan(revision)) return;
          _reconcileWithArp(
            latestArp: finalArp,
            targetIps: targetIpSet,
            localIps: localIps,
            localHostname: localHostname,
            revision: revision,
            pendingResolutions: pendingResolutions,
          );
        } catch (_) {}

        // Sort discovered devices numerically by IP
        _discoveredDevices.sort((a, b) => _compareIps(a.ip, b.ip));

        if (!_isCurrentScan(revision)) return;
        _isScanning = false;
        _progress = 1.0;
        _scannedCount = _totalCount;
        _notifyCompletion();
      },
      onError: (_) {
        if (!_isCurrentScan(revision)) return;
        _scanRevision++;
        _isScanning = false;
        _resolvingHostIps.clear();
        _notifyCompletion();
      },
      cancelOnError: true,
    );
  }

  /// Cancels any active network scan.
  void stopScan() {
    _scanRevision++;
    _scanSub?.cancel();
    _scanSub = null;
    _isScanning = false;
    _resolvingHostIps.clear();
    _notifyCompletion();
  }

  @override
  void dispose() {
    _disposed = true;
    stopScan();
    super.dispose();
  }
}
