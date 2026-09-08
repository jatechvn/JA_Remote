import '../core/network/wake_on_lan.dart';
import '../core/network/network_utils.dart';
import '../core/process/process_runner.dart';
import '../data/models/managed_device.dart';
import '../data/repositories/log_repository.dart';

/// Service for remote power operations: Wake-on-LAN, Restart, and Shutdown.
class PowerService {
  final LogRepository _logRepo = LogRepository();

  /// Wakes a PC via Wake-on-LAN Magic Packet.
  Future<bool> wakeDevice(ManagedDevice device) async {
    final mac = device.mac;
    if (mac == null || mac.isEmpty) {
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'WOL',
        status: 'FAILED',
        message: 'Không có địa chỉ MAC để gửi Magic Packet.',
      );
      return false;
    }

    final broadcast = NetworkUtils.getBroadcastIp(device.ip);
    final ok = await WakeOnLan.wake(mac: mac, broadcastIp: broadcast);

    _logRepo.addLog(
      deviceName: device.name,
      deviceIp: device.ip,
      action: 'WOL',
      status: ok ? 'SUCCESS' : 'FAILED',
      message: ok
          ? 'Đã gửi Magic Packet tới MAC $mac qua broadcast $broadcast'
          : 'Lỗi gửi gói Magic Packet.',
    );

    return ok;
  }

  /// Restarts a remote device.
  Future<bool> restartDevice(ManagedDevice device) async {
    if (device.os.toLowerCase() == 'windows') {
      final res = await ProcessRunner.restartWindowsPc(device.ip);
      final ok = res.isSuccess;
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'RESTART',
        status: ok ? 'SUCCESS' : 'FAILED',
        message: ok
            ? 'Đã gửi lệnh khởi động lại máy thành công.'
            : 'Lỗi khởi động lại: ${res.stderr.isNotEmpty ? res.stderr : res.stdout}',
      );
      return ok;
    } else {
      // Unix / Linux via SSH / shutdown command
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'RESTART',
        status: 'INFO',
        message: 'Yêu cầu khởi động lại máy Linux qua SSH.',
      );
      return true;
    }
  }

  /// Shuts down a remote device.
  Future<bool> shutdownDevice(ManagedDevice device) async {
    if (device.os.toLowerCase() == 'windows') {
      final res = await ProcessRunner.shutdownWindowsPc(device.ip);
      final ok = res.isSuccess;
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'SHUTDOWN',
        status: ok ? 'SUCCESS' : 'FAILED',
        message: ok
            ? 'Đã gửi lệnh tắt máy thành công.'
            : 'Lỗi tắt máy: ${res.stderr.isNotEmpty ? res.stderr : res.stdout}',
      );
      return ok;
    } else {
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'SHUTDOWN',
        status: 'INFO',
        message: 'Yêu cầu tắt máy Linux qua SSH.',
      );
      return true;
    }
  }
}
