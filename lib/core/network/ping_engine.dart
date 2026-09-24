import 'dart:async';
import 'dart:io';

/// Ping result representation.
class PingResult {
  final String ip;
  final bool isOnline;
  final int? latencyMs;
  final String? error;

  const PingResult({
    required this.ip,
    required this.isOnline,
    this.latencyMs,
    this.error,
  });

  @override
  String toString() =>
      'PingResult($ip: ${isOnline ? 'ONLINE (${latencyMs}ms)' : 'OFFLINE'})';
}

/// High-performance Ping Engine optimized for Windows LAN discovery.
class PingEngine {
  /// Pings a single IP with specified timeout in milliseconds (default: 400ms for LAN).
  static Future<PingResult> ping(String ip, {int timeoutMs = 400}) async {
    if (Platform.isWindows) {
      return _pingWindows(ip, timeoutMs);
    } else {
      return _pingUnix(ip, timeoutMs);
    }
  }

  /// Fast Windows ping using native ping.exe
  static Future<PingResult> _pingWindows(String ip, int timeoutMs) async {
    try {
      final res = await Process.run('ping', [
        '-n',
        '1',
        '-w',
        timeoutMs.toString(),
        ip,
      ], runInShell: false);

      final out = res.stdout.toString();
      if (res.exitCode == 0 && out.contains('TTL=')) {
        // Parse latency: "time=2ms" or "time<1ms"
        final match = RegExp(
          r'time[=<](\d+)ms',
          caseSensitive: false,
        ).firstMatch(out);
        int latency = 1;
        if (match != null) {
          latency = int.tryParse(match.group(1)!) ?? 1;
        }
        return PingResult(ip: ip, isOnline: true, latencyMs: latency);
      }
      // If ICMP ping failed (e.g. firewall blocked ICMP Echo Request),
      // try TCP socket fallback to common office LAN & admin ports
      return pingTcp(ip, timeoutMs: timeoutMs);
    } catch (e) {
      // Fallback socket ping check if process execution fails
      return pingTcp(ip, timeoutMs: timeoutMs);
    }
  }

  /// Unix / Linux / macOS ping fallback
  static Future<PingResult> _pingUnix(String ip, int timeoutMs) async {
    try {
      final timeoutSec = (timeoutMs / 1000).ceil().clamp(1, 5).toString();
      final res = await Process.run('ping', ['-c', '1', '-W', timeoutSec, ip]);
      if (res.exitCode == 0) {
        final match = RegExp(
          r'time=(\d+(?:\.\d+)?) ms',
        ).firstMatch(res.stdout.toString());
        int latency = 1;
        if (match != null) {
          latency = double.tryParse(match.group(1)!)?.round() ?? 1;
        }
        return PingResult(ip: ip, isOnline: true, latencyMs: latency);
      }
      return pingTcp(ip, timeoutMs: timeoutMs);
    } catch (e) {
      return pingTcp(ip, timeoutMs: timeoutMs);
    }
  }

  /// TCP handshake fallback on common office LAN & management ports:
  /// 6475 (JA LAN Messenger), 5985 (WinRM), 445 (SMB), 135 (RPC), 3389 (RDP), 22 (SSH), 80 (HTTP)
  static Future<PingResult> pingTcp(
    String ip, {
    int timeoutMs = 400,
    Future<Socket> Function(String ip, int port, Duration timeout)? connect,
  }) async {
    if (timeoutMs < 1) throw ArgumentError('Timeout must be positive');
    final open =
        connect ??
        (String host, int port, Duration timeout) =>
            Socket.connect(host, port, timeout: timeout);
    const ports = [6475, 5985, 445, 135, 3389, 22, 80];
    final socketTimeout = Duration(milliseconds: timeoutMs.clamp(100, 250));

    try {
      final futures = ports.map((port) async {
        final stopwatch = Stopwatch()..start();
        try {
          final socket = await open(ip, port, socketTimeout);
          stopwatch.stop();
          socket.destroy();
          return stopwatch.elapsedMilliseconds.clamp(1, 9999);
        } catch (_) {
          return null;
        }
      });
      final results = await Future.wait(futures);
      // Drain all attempts to preserve the batch concurrency limit and close
      // every socket; latency is the fastest successful handshake only.
      final latencies = results.whereType<int>().toList()..sort();
      if (latencies.isNotEmpty) {
        return PingResult(ip: ip, isOnline: true, latencyMs: latencies.first);
      }
    } catch (_) {}
    return PingResult(ip: ip, isOnline: false);
  }

  /// Pings a batch of IPs with concurrency limiter.
  static Stream<PingResult> pingBatch(
    List<String> ips, {
    int maxConcurrent = 16,
    int timeoutMs = 400,
    Future<PingResult> Function(String, int)? probe,
  }) {
    if (maxConcurrent < 1 || timeoutMs < 1) {
      throw ArgumentError('Concurrency and timeout must be positive');
    }
    final targets = List<String>.of(ips);
    final runProbe = probe ?? (ip, timeout) => ping(ip, timeoutMs: timeout);
    late StreamController<PingResult> controller;
    var nextIndex = 0;
    var cancelled = false;
    int activeCount = 0;

    void next() {
      if (cancelled || controller.isPaused) return;
      if (nextIndex == targets.length && activeCount == 0) {
        if (!controller.isClosed) controller.close();
        return;
      }
      while (activeCount < maxConcurrent && nextIndex < targets.length) {
        final ip = targets[nextIndex++];
        activeCount++;
        Future.sync(() => runProbe(ip, timeoutMs))
            .then(
              (res) {
                if (!cancelled) controller.add(res);
              },
              onError: (Object error) {
                if (!cancelled) {
                  controller.add(
                    PingResult(
                      ip: ip,
                      isOnline: false,
                      error: error.toString(),
                    ),
                  );
                }
              },
            )
            .whenComplete(() {
              activeCount--;
              next();
            });
      }
    }

    controller = StreamController<PingResult>(
      onListen: next,
      onResume: next,
      onCancel: () {
        cancelled = true;
      },
    );
    return controller.stream;
  }
}
