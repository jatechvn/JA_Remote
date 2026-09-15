import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/port_scan_service.dart';

class CountingScanner extends PortScanService {
  int started = 0;
  @override
  Future<PortScanResult> testSinglePort(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    started++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return PortScanResult(
      host: host,
      port: port,
      status: PortStatus.closed,
      latencyMs: 5,
      serviceName: '',
      description: '',
    );
  }
}

void main() {
  test(
    'subscription cancellation stops queued probes without a token',
    () async {
      final scanner = CountingScanner();
      await scanner
          .scanPortsStream(
            'localhost',
            List.generate(20, (i) => i + 1),
            concurrency: 1,
          )
          .take(1)
          .drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(scanner.started, lessThan(20));
    },
  );
  test('zero concurrency fails instead of hanging', () async {
    await expectLater(
      PortScanService()
          .scanPortsStream('localhost', [80], concurrency: 0)
          .toList()
          .timeout(const Duration(milliseconds: 100)),
      throwsArgumentError,
    );
  });
  late PortScanService service;
  ServerSocket? testServer;
  int openPort = 0;

  setUp(() async {
    service = PortScanService();
    testServer = await ServerSocket.bind('127.0.0.1', 0);
    openPort = testServer!.port;
  });

  tearDown(() async {
    await testServer?.close();
  });

  test('testSinglePort detects open local port and measures latency', () async {
    final result = await service.testSinglePort('127.0.0.1', openPort);

    expect(result.host, equals('127.0.0.1'));
    expect(result.port, equals(openPort));
    expect(result.isOpen, isTrue);
    expect(result.status, equals(PortStatus.open));
    expect(result.latencyMs, greaterThanOrEqualTo(0));
  });

  test('testSinglePort recognizes closed port on loopback', () async {
    // Find an unused port by briefly binding and closing
    final temp = await ServerSocket.bind('127.0.0.1', 0);
    final unusedPort = temp.port;
    await temp.close();

    final result = await service.testSinglePort('127.0.0.1', unusedPort);

    expect(result.isOpen, isFalse);
    expect(result.status, anyOf(PortStatus.closed, PortStatus.timeout));
  });

  test(
    'wellKnownPorts lookup returns correct metadata for standard services',
    () {
      expect(PortScanService.wellKnownPorts[22]?.$1, equals('SSH'));
      expect(PortScanService.wellKnownPorts[3389]?.$1, equals('RDP'));
      expect(PortScanService.wellKnownPorts[5985]?.$1, equals('WinRM-HTTP'));
      expect(PortScanService.wellKnownPorts[445]?.$1, equals('SMB'));
      expect(PortScanService.wellKnownPorts[80]?.$1, equals('HTTP'));
      expect(PortScanService.wellKnownPorts[443]?.$1, equals('HTTPS'));
    },
  );

  test('scanPortsStream scans multiple ports and yields open port', () async {
    final ports = [openPort, 59901, 59902];
    final results = <PortScanResult>[];

    await for (final res in service.scanPortsStream(
      '127.0.0.1',
      ports,
      timeout: const Duration(milliseconds: 300),
    )) {
      results.add(res);
    }

    expect(results.length, equals(3));
    final openResults = results.where((r) => r.port == openPort);
    expect(openResults.length, equals(1));
    expect(openResults.first.isOpen, isTrue);
  });

  test('CancellationToken halts scan stream early', () async {
    final token = CancellationToken();
    final ports = List.generate(50, (i) => 58000 + i);
    final results = <PortScanResult>[];

    // Cancel after reading first 2 items
    await for (final res in service.scanPortsStream(
      '127.0.0.1',
      ports,
      timeout: const Duration(milliseconds: 200),
      cancelToken: token,
      concurrency: 5,
    )) {
      results.add(res);
      if (results.length >= 2) {
        token.cancel();
      }
    }

    expect(results.length, lessThan(50));
  });
}
