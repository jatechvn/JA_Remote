import '../core/process/process_runner.dart';
import '../data/models/managed_device.dart';
import '../data/repositories/log_repository.dart';

/// Service for 1-click launching Windows admin tools (RDP, C$ Explorer, Computer Management).
class ToolLauncherService {
  final LogRepository _logRepo = LogRepository();

  /// Launches Windows Remote Desktop (MSTSC)
  Future<bool> launchRdp(ManagedDevice device) async {
    final ok = await ProcessRunner.launchRdp(device.ip);
    _logRepo.addLog(
      deviceName: device.name,
      deviceIp: device.ip,
      action: 'RDP',
      status: ok ? 'SUCCESS' : 'FAILED',
      message: ok
          ? 'Đã mở Remote Desktop tới ${device.ip}'
          : 'Không thể khởi động mstsc.exe',
    );
    return ok;
  }

  /// Launches Windows Explorer to administrative share (`\\<ip>\c$`)
  Future<bool> launchShare(ManagedDevice device, [String share = 'c\$']) async {
    final ok = await ProcessRunner.launchExplorerShare(device.ip, share);
    _logRepo.addLog(
      deviceName: device.name,
      deviceIp: device.ip,
      action: 'EXPLORER',
      status: ok ? 'SUCCESS' : 'FAILED',
      message: ok
          ? 'Đã mở Explorer tới \\\\${device.ip}\\$share'
          : 'Lỗi mở Explorer',
    );
    return ok;
  }

  /// Launches Computer Management MMC snap-in
  Future<bool> launchComputerManagement(ManagedDevice device) async {
    final ok = await ProcessRunner.launchComputerManagement(device.ip);
    _logRepo.addLog(
      deviceName: device.name,
      deviceIp: device.ip,
      action: 'COMPMGMT',
      status: ok ? 'SUCCESS' : 'FAILED',
      message: ok
          ? 'Đã mở Computer Management cho ${device.ip}'
          : 'Lỗi mở Computer Management',
    );
    return ok;
  }
}
