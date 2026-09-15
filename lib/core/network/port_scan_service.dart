import 'dart:async';
import 'dart:io';

/// Connection status of a scanned port.
enum PortStatus { open, closed, timeout }

/// Result of testing or scanning a single TCP port.
class PortScanResult {
  final String host;
  final int port;
  final PortStatus status;
  final int latencyMs;
  final String serviceName;
  final String description;

  const PortScanResult({
    required this.host,
    required this.port,
    required this.status,
    required this.latencyMs,
    required this.serviceName,
    required this.description,
  });

  bool get isOpen => status == PortStatus.open;
  bool get isClosed => status == PortStatus.closed;
  bool get isTimeout => status == PortStatus.timeout;
}

/// Token used to cooperatively cancel an in-progress scan.
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// High-performance TCP port testing and scanning service using native Dart sockets.
class PortScanService {
  /// Well-known IANA and common administrative / development TCP ports.
  static const Map<int, (String, String)> wellKnownPorts = {
    21: ('FTP', 'File Transfer Protocol'),
    22: ('SSH', 'Secure Shell Remote Login'),
    23: ('Telnet', 'Unencrypted Text Communications'),
    25: ('SMTP', 'Simple Mail Transfer Protocol'),
    53: ('DNS', 'Domain Name System'),
    80: ('HTTP', 'World Wide Web HyperText Server'),
    88: ('Kerberos', 'Kerberos Network Authentication'),
    110: ('POP3', 'Post Office Protocol v3'),
    135: ('MS-RPC', 'Microsoft RPC Endpoint Mapper'),
    139: ('NetBIOS', 'NetBIOS Session Service'),
    143: ('IMAP', 'Internet Message Access Protocol'),
    389: ('LDAP', 'Lightweight Directory Access Protocol'),
    443: ('HTTPS', 'HTTP over TLS/SSL Secure Web'),
    445: ('SMB', 'Microsoft File & Printer Sharing'),
    465: ('SMTPS', 'SMTP over SSL/TLS'),
    515: ('LPD', 'Line Printer Daemon'),
    587: ('Submission', 'SMTP Mail Message Submission'),
    631: ('IPP', 'Internet Printing Protocol (CUPS)'),
    636: ('LDAPS', 'LDAP over SSL'),
    993: ('IMAPS', 'IMAP over SSL/TLS'),
    995: ('POP3S', 'POP3 over SSL/TLS'),
    1433: ('MSSQL', 'Microsoft SQL Server Database'),
    1521: ('Oracle', 'Oracle Database Listener'),
    2049: ('NFS', 'Network File System'),
    2375: ('Docker', 'Docker REST API (Plain)'),
    2376: ('Docker-TLS', 'Docker REST API (TLS)'),
    3000: ('Node/Dev', 'Web Dev Server / Grafana'),
    3306: ('MySQL', 'MySQL / MariaDB Database'),
    3389: ('RDP', 'Microsoft Remote Desktop Protocol'),
    5000: ('Flask/UPnP', 'UPnP or Python Flask Service'),
    5432: ('PostgreSQL', 'PostgreSQL Relational Database'),
    5900: ('VNC', 'Virtual Network Computing Remote Desktop'),
    5985: ('WinRM-HTTP', 'Windows Remote Management (PowerShell HTTP)'),
    5986: ('WinRM-HTTPS', 'Windows Remote Management (PowerShell HTTPS)'),
    6379: ('Redis', 'Redis In-Memory Key-Value Store'),
    8000: ('HTTP-Alt', 'Alternative HTTP / Dev Server'),
    8080: ('HTTP-Proxy', 'HTTP Alternate / Apache Tomcat / Proxy'),
    8090: ('Web-Admin', 'Management Web Interface'),
    8443: ('HTTPS-Alt', 'Alternative Secure HTTPS'),
    8888: ('HTTP-Admin', 'Web Admin Console / Jupyter'),
    9000: ('Portainer/PHP', 'Portainer Container UI or PHP-FPM'),
    9090: ('Prometheus', 'Prometheus Metrics or Cockpit Admin'),
    27017: ('MongoDB', 'MongoDB NoSQL Database'),
  };

  /// Top common administrative, remote desktop, and service ports.
  static const List<int> commonPorts = [
    21,
    22,
    23,
    25,
    53,
    80,
    88,
    110,
    135,
    139,
    143,
    389,
    443,
    445,
    587,
    631,
    993,
    995,
    1433,
    1521,
    3306,
    3389,
    5432,
    5900,
    5985,
    5986,
    6379,
    8000,
    8080,
    8443,
    9090,
  ];

  /// Tests a single TCP port on a target host.
  Future<PortScanResult> testSinglePort(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    if (host.trim().isEmpty ||
        port < 1 ||
        port > 65535 ||
        timeout <= Duration.zero) {
      throw ArgumentError(
        'Host, port (1..65535) and positive timeout required',
      );
    }
    final sw = Stopwatch()..start();
    final service = wellKnownPorts[port] ?? ('Port $port', 'TCP Service');

    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      socket.destroy();
      return PortScanResult(
        host: host,
        port: port,
        status: PortStatus.open,
        latencyMs: sw.elapsedMilliseconds,
        serviceName: service.$1,
        description: service.$2,
      );
    } on SocketException catch (e) {
      sw.stop();
      // On Windows: 10061 = WSAECONNREFUSED (port closed, responded with RST)
      // On Linux/macOS: Connection refused error message
      final isRefused =
          e.osError?.errorCode == 10061 ||
          e.osError?.errorCode == 111 ||
          e.message.toLowerCase().contains('refused');

      return PortScanResult(
        host: host,
        port: port,
        status: isRefused ? PortStatus.closed : PortStatus.timeout,
        latencyMs: sw.elapsedMilliseconds,
        serviceName: service.$1,
        description: service.$2,
      );
    } catch (_) {
      sw.stop();
      return PortScanResult(
        host: host,
        port: port,
        status: PortStatus.timeout,
        latencyMs: sw.elapsedMilliseconds,
        serviceName: service.$1,
        description: service.$2,
      );
    }
  }

  /// Scans a collection of ports asynchronously with a concurrency pool,
  /// yielding each result as soon as it is evaluated.
  Stream<PortScanResult> scanPortsStream(
    String host,
    List<int> ports, {
    Duration timeout = const Duration(milliseconds: 600),
    int concurrency = 30,
    CancellationToken? cancelToken,
  }) async* {
    if (concurrency < 1 ||
        timeout <= Duration.zero ||
        host.trim().isEmpty ||
        ports.any((port) => port < 1 || port > 65535)) {
      throw ArgumentError('Invalid port scan parameters');
    }
    if (ports.isEmpty) return;

    var cancelled = false;
    final controller = StreamController<PortScanResult>(
      onCancel: () {
        cancelled = true;
      },
    );
    final queue = List<int>.from(ports);
    var nextIndex = 0;
    int activeWorkers = 0;

    void processNext() {
      if (cancelled ||
          cancelToken?.isCancelled == true ||
          nextIndex >= queue.length) {
        if (activeWorkers == 0 && !controller.isClosed) {
          controller.close();
        }
        return;
      }

      final port = queue[nextIndex++];
      activeWorkers++;

      testSinglePort(host, port, timeout: timeout)
          .then((result) {
            if (!cancelled &&
                cancelToken?.isCancelled != true &&
                !controller.isClosed) {
              controller.add(result);
            }
          })
          .catchError((_) {
            // Ignored, testSinglePort catches all errors
          })
          .whenComplete(() {
            activeWorkers--;
            processNext();
          });
    }

    final initialWorkers = ports.length < concurrency
        ? ports.length
        : concurrency;
    for (int i = 0; i < initialWorkers; i++) {
      processNext();
    }

    yield* controller.stream;
  }
}
