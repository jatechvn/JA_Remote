import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/network_utils.dart';
import '../core/network/ping_engine.dart';
import '../core/network/host_resolver.dart';
import '../core/network/arp_resolver.dart';
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

  StreamSubscription? _scanSub;

  bool get isScanning => _isScanning;
  double get progress => _progress;
  int get scannedCount => _scannedCount;
  int get totalCount => _totalCount;
  String get currentSubnet => _currentSubnet;
  List<ManagedDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  List<NetworkInterfaceDetails> get availableAdapters =>
      List.unmodifiable(_availableAdapters);

  DiscoveryService() {
    _initDefaultSubnet();
  }

  Future<void> _initDefaultSubnet() async {
    await refreshAdapters();
    _currentSubnet = await NetworkUtils.getDefaultLocalSubnet();
    notifyListeners();
  }

  /// Reloads available network adapters from system
  Future<void> refreshAdapters() async {
    _availableAdapters = await NetworkUtils.getAvailableAdapters();
    notifyListeners();
  }

  void setSubnet(String subnet) {
    _currentSubnet = subnet.trim();
    notifyListeners();
  }

  /// Starts scanning the specified subnet (e.g. 172.21.168.0/24)
  Future<void> startScan({
    String? subnet,
    int concurrency = 20,
    int timeoutMs = 400,
  }) async {
    if (_isScanning) return;

    final targetSubnet = subnet ?? _currentSubnet;
    final ips = NetworkUtils.expandSubnet(targetSubnet);
    if (ips.isEmpty) return;

    _isScanning = true;
    _progress = 0.0;
    _scannedCount = 0;
    _totalCount = ips.length;
    _discoveredDevices.clear();
    notifyListeners();

    // Pre-fetch ARP table in bulk to map MAC addresses fast
    final arpTable = await ArpResolver.getArpTable();

    _scanSub =
        PingEngine.pingBatch(
          ips,
          maxConcurrent: concurrency,
          timeoutMs: timeoutMs,
        ).listen(
          (result) async {
            _scannedCount++;
            _progress = _scannedCount / _totalCount;

            if (result.isOnline) {
              final ip = result.ip;
              final mac = arpTable[ip];
              final hostname = await HostResolver.resolve(ip);
              final devName = hostname != ip
                  ? hostname.split('.')[0]
                  : 'PC-$ip';

              final dev = ManagedDevice(
                id: 'discovered_${ip.replaceAll('.', '_')}',
                name: devName,
                hostname: hostname,
                ip: ip,
                mac: mac,
                online: true,
                pingMs: result.latencyMs,
                os: 'Windows',
                group: 'Discovered',
                lastSeen: DateTime.now(),
              );

              _discoveredDevices.add(dev);
            }

            notifyListeners();
          },
          onDone: () {
            _isScanning = false;
            _progress = 1.0;
            notifyListeners();
          },
          onError: (_) {
            _isScanning = false;
            notifyListeners();
          },
          cancelOnError: false,
        );
  }

  /// Cancels any active network scan.
  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    _isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}
