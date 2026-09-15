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
      return PingResult(ip: ip, isOnline: false);
    } catch (e) {
      // Fallback socket ping check if process execution fails
      return _pingSocketFallback(ip, timeoutMs);
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
      return PingResult(ip: ip, isOnline: false);
    } catch (e) {
      return _pingSocketFallback(ip, timeoutMs);
    }
  }

  /// TCP handshake fallback on common ports (135 RPC, 445 SMB, 22 SSH, 80 HTTP, 3389 RDP)
  static Future<PingResult> _pingSocketFallback(
    String ip,
    int timeoutMs,
  ) async {
    final stopwatch = Stopwatch()..start();
    final ports = [135, 445, 3389, 22, 80];
    for (final port in ports) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(
            milliseconds: (timeoutMs / ports.length).round().clamp(50, 200),
          ),
        );
        stopwatch.stop();
        socket.destroy();
        return PingResult(
          ip: ip,
          isOnline: true,
          latencyMs: stopwatch.elapsedMilliseconds.clamp(1, 9999),
        );
      } catch (_) {}
    }
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
