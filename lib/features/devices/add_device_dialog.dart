import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../data/models/managed_device.dart';
import '../../services/device_service.dart';
import '../../core/network/port_scan_service.dart';

void showAddDeviceDialog(BuildContext context) {
  final theme = context.read<ThemeProvider>();
  final colors = theme.colors;
  final language = context.read<LanguageProvider>();
  final deviceService = context.read<DeviceService>();
  final portScanService = PortScanService();

  final nameController = TextEditingController();
  final ipController = TextEditingController();
  final macController = TextEditingController();
  final groupController = TextEditingController(text: 'Factory');
  final userController = TextEditingController(text: 'Administrator');
  final passController = TextEditingController();
  final noteController = TextEditingController();

  bool isTesting = false;
  String? testResult;
  bool isTestSuccess = false;

  showGlassDialog(
    context: context,
    colors: colors,
    title: language.t('dialog_add_title'),
    icon: Icons.add_to_queue_rounded,
    content: StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInput(
                language.t('dialog_name_label'),
                nameController,
                colors,
              ),
              const SizedBox(height: 10),
              _buildInput(language.t('dialog_ip_label'), ipController, colors),
              const SizedBox(height: 8),

              // Test Connection row
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            final targetIp = ipController.text.trim();
                            if (targetIp.isEmpty) {
                              showAppToast(
                                context,
                                colors: colors,
                                message: language.t('dialog_ip_required'),
                                icon: Icons.warning_rounded,
                                accentColor: colors.accentAmber,
                              );
                              return;
                            }
                            setDialogState(() {
                              isTesting = true;
                              testResult = null;
                            });
                            try {
                              // Test WinRM (5985) and SSH (22)
                              final winrm = await portScanService
                                  .testSinglePort(
                                    targetIp,
                                    5985,
                                    timeout: const Duration(milliseconds: 1200),
                                  );
                              final ssh = await portScanService.testSinglePort(
                                targetIp,
                                22,
                                timeout: const Duration(milliseconds: 1200),
                              );

                              final ok = winrm.isOpen || ssh.isOpen;
                              setDialogState(() {
                                isTesting = false;
                                isTestSuccess = ok;
                                if (winrm.isOpen && ssh.isOpen) {
                                  testResult =
                                      'Online: WinRM (5985) & SSH (22) open';
                                } else if (winrm.isOpen) {
                                  testResult =
                                      'Online: WinRM (5985) open (${winrm.latencyMs}ms)';
                                } else if (ssh.isOpen) {
                                  testResult =
                                      'Online: SSH (22) open (${ssh.latencyMs}ms)';
                                } else {
                                  testResult = 'No response on port 5985/22';
                                }
                              });
                            } catch (e) {
                              setDialogState(() {
                                isTesting = false;
                                isTestSuccess = false;
                                testResult = 'Error: $e';
                              });
                            }
                          },
                    icon: isTesting
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.accentCyan,
                            ),
                          )
                        : Icon(
                            Icons.network_check_rounded,
                            size: 14,
                            color: colors.accentCyan,
                          ),
                    label: Text(
                      isTesting ? 'Testing...' : 'Test Connection',
                      style: TextStyle(fontSize: 11, color: colors.accentCyan),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: BorderSide(color: colors.cardBorder),
                    ),
                  ),
                  if (testResult != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        testResult!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isTestSuccess
                              ? colors.accentEmerald
                              : colors.accentRose,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _buildInput(
                language.t('dialog_mac_label'),
                macController,
                colors,
              ),
              const SizedBox(height: 10),
              _buildInput(
                language.t('dialog_group_label'),
                groupController,
                colors,
              ),
              const SizedBox(height: 10),
              _buildInput(
                language.t('dialog_user_label'),
                userController,
                colors,
              ),
              const SizedBox(height: 10),
              _buildInput(
                language.t('dialog_pass_label'),
                passController,
                colors,
                obscureText: true,
              ),
              const SizedBox(height: 10),
              _buildInput(
                language.t('dialog_note_label'),
                noteController,
                colors,
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      GlassButton(
        label: language.t('dialog_cancel'),
        colors: colors,
        onTap: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      GlassButton(
        label: language.t('dialog_add_btn'),
        icon: Icons.check_rounded,
        colors: colors,
        accentColor: colors.accentCyan,
        onTap: () async {
          final ip = ipController.text.trim();
          if (ip.isEmpty) {
            showAppToast(
              context,
              colors: colors,
              message: language.t('dialog_ip_required'),
              icon: Icons.warning_rounded,
              accentColor: colors.accentAmber,
            );
            return;
          }

          final name = nameController.text.trim().isEmpty
              ? 'PC-$ip'
              : nameController.text.trim();
          final dev = ManagedDevice(
            id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            hostname: name,
            ip: ip,
            mac: macController.text.trim().isEmpty
                ? null
                : macController.text.trim(),
            group: groupController.text.trim().isEmpty
                ? 'Factory'
                : groupController.text.trim(),
            username: userController.text.trim().isEmpty
                ? null
                : userController.text.trim(),
            password: passController.text.isEmpty ? null : passController.text,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
            online: isTestSuccess,
          );

          await deviceService.addDevice(dev);
          if (context.mounted) {
            Navigator.pop(context);
            showAppToast(
              context,
              colors: colors,
              message: language.t('dialog_added_toast', {'name': name}),
              icon: Icons.check_circle_rounded,
              accentColor: colors.accentEmerald,
            );
          }
        },
      ),
    ],
  );
}

Widget _buildInput(
  String label,
  TextEditingController controller,
  dynamic colors, {
  bool obscureText = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(fontSize: 13, color: colors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: colors.cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.cardBorder),
          ),
        ),
      ),
    ],
  );
}
