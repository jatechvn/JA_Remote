import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../data/models/managed_device.dart';
import '../../services/device_service.dart';
import '../../services/power_service.dart';
import '../../services/tool_launcher_service.dart';
import 'port_scanner_dialog.dart';

/// Glass dialog displaying full device details, fast action buttons, and edit options.
void showDeviceDetailDialog(BuildContext context, ManagedDevice device) {
  final theme = context.read<ThemeProvider>();
  final colors = theme.colors;
  final language = context.read<LanguageProvider>();
  final deviceService = context.read<DeviceService>();
  final powerService = PowerService();
  final toolService = ToolLauncherService();

  final nameController = TextEditingController(text: device.name);
  final groupController = TextEditingController(text: device.group);
  final macController = TextEditingController(text: device.mac ?? '');
  final userController = TextEditingController(
    text: device.username ?? 'Administrator',
  );
  final passController = TextEditingController(text: device.password ?? '');
  final noteController = TextEditingController(text: device.note ?? '');

  showGlassDialog(
    context: context,
    colors: colors,
    title: language.t('dialog_detail_title', {'name': device.name}),
    icon: Icons.computer_rounded,
    content: StatefulBuilder(
      builder: (ctx, setState) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status banner
              Row(
                children: [
                  StatusPill(
                    label: device.online ? 'ONLINE' : 'OFFLINE',
                    dotColor: device.online
                        ? colors.accentEmerald
                        : colors.textMuted,
                    backgroundColor: device.online
                        ? colors.accentEmerald.withValues(alpha: 0.15)
                        : colors.cardBg,
                  ),
                  const SizedBox(width: 8),
                  if (device.pingMs != null)
                    LatencyBadge(latencyMs: device.pingMs!, colors: colors),
                  const Spacer(),
                  Text(
                    'IP: ${device.ip}',
                    style: TextStyle(
                      color: colors.accentCyan,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1-Click Action Buttons Row
              Text(
                language.t('dialog_quick_actions'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // RDP
                  _ActionButton(
                    label: 'RDP (mstsc)',
                    icon: Icons.desktop_windows_rounded,
                    color: colors.accentCyan,
                    colors: colors,
                    onTap: () {
                      toolService.launchRdp(device);
                      showAppToast(
                        context,
                        colors: colors,
                        message: 'RDP -> ${device.ip}...',
                        icon: Icons.desktop_windows_rounded,
                      );
                    },
                  ),
                  // Explorer C$
                  _ActionButton(
                    label: 'Explorer C\$',
                    icon: Icons.folder_shared_rounded,
                    color: colors.accentAmber,
                    colors: colors,
                    onTap: () {
                      toolService.launchShare(device);
                      showAppToast(
                        context,
                        colors: colors,
                        message: 'Explorer -> C\$...',
                        icon: Icons.folder_shared_rounded,
                      );
                    },
                  ),
                  // Computer Management
                  _ActionButton(
                    label: 'Quản trị (MMC)',
                    icon: Icons.settings_system_daydream_rounded,
                    color: colors.accentPurple,
                    colors: colors,
                    onTap: () {
                      toolService.launchComputerManagement(device);
                    },
                  ),
                  // Port Scanner
                  _ActionButton(
                    label: language.t('port_scanner_btn_open_dialog'),
                    icon: Icons.radar_rounded,
                    color: colors.accentCyan,
                    colors: colors,
                    onTap: () {
                      showPortScannerDialog(context, initialHost: device.ip);
                    },
                  ),
                  // Wake-on-LAN
                  _ActionButton(
                    label: language.t('dev_batch_wake'),
                    icon: Icons.bolt_rounded,
                    color: colors.accentEmerald,
                    colors: colors,
                    onTap: () async {
                      final ok = await powerService.wakeDevice(device);
                      if (context.mounted) {
                        showAppToast(
                          context,
                          colors: colors,
                          message: ok
                              ? language.t('dialog_wol_sent', {
                                  'name': device.name,
                                })
                              : language.t('dialog_wol_failed'),
                          icon: Icons.bolt_rounded,
                          accentColor: ok
                              ? colors.accentEmerald
                              : colors.accentRose,
                        );
                      }
                    },
                  ),
                  // Restart
                  _ActionButton(
                    label: language.t('dev_batch_restart'),
                    icon: Icons.restart_alt_rounded,
                    color: colors.accentRose,
                    colors: colors,
                    onTap: () async {
                      final confirm = await _showConfirmDialog(
                        context,
                        title: language.t('dialog_confirm_restart_title'),
                        message: language.t('dialog_confirm_restart_msg', {
                          'name': device.name,
                          'ip': device.ip,
                        }),
                      );
                      if (confirm == true) {
                        await powerService.restartDevice(device);
                        if (context.mounted) {
                          showAppToast(
                            context,
                            colors: colors,
                            message: language.t('dialog_sent_restart', {
                              'name': device.name,
                            }),
                            icon: Icons.restart_alt_rounded,
                          );
                        }
                      }
                    },
                  ),
                  // Shutdown
                  _ActionButton(
                    label: language.t('dev_batch_shutdown'),
                    icon: Icons.power_settings_new_rounded,
                    color: colors.accentRose,
                    colors: colors,
                    onTap: () async {
                      final confirm = await _showConfirmDialog(
                        context,
                        title: language.t('dialog_confirm_shutdown_title'),
                        message: language.t('dialog_confirm_shutdown_msg', {
                          'name': device.name,
                          'ip': device.ip,
                        }),
                      );
                      if (confirm == true) {
                        await powerService.shutdownDevice(device);
                        if (context.mounted) {
                          showAppToast(
                            context,
                            colors: colors,
                            message: language.t('dialog_sent_shutdown', {
                              'name': device.name,
                            }),
                            icon: Icons.power_settings_new_rounded,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Edit details fields
              Text(
                language.t('dialog_config_info'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                language.t('dialog_name_label'),
                nameController,
                colors,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                language.t('dialog_group_label'),
                groupController,
                colors,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                language.t('dialog_mac_label'),
                macController,
                colors,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                language.t('dialog_user_label'),
                userController,
                colors,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                language.t('dialog_pass_label'),
                passController,
                colors,
                obscureText: true,
              ),
              const SizedBox(height: 8),
              _buildTextField(
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
        label: language.t('dialog_delete'),
        icon: Icons.delete_outline_rounded,
        colors: colors,
        accentColor: colors.accentRose,
        onTap: () async {
          Navigator.pop(context);
          await deviceService.removeDevice(device.id);
          if (context.mounted) {
            showAppToast(
              context,
              colors: colors,
              message: language.t('dialog_deleted_toast', {
                'name': device.name,
              }),
              icon: Icons.delete_rounded,
              accentColor: colors.accentRose,
            );
          }
        },
      ),
      const Spacer(),
      GlassButton(
        label: language.t('dialog_close'),
        colors: colors,
        onTap: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      GlassButton(
        label: language.t('dialog_save'),
        icon: Icons.check_rounded,
        colors: colors,
        accentColor: colors.accentCyan,
        onTap: () async {
          final updated = device.copyWith(
            name: nameController.text.trim().isEmpty
                ? device.name
                : nameController.text.trim(),
            group: groupController.text.trim().isEmpty
                ? device.group
                : groupController.text.trim(),
            mac: macController.text.trim().isEmpty
                ? null
                : macController.text.trim(),
            username: userController.text.trim().isEmpty
                ? null
                : userController.text.trim(),
            password: passController.text.isEmpty ? null : passController.text,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
          await deviceService.updateDevice(updated);
          if (context.mounted) {
            Navigator.pop(context);
            showAppToast(
              context,
              colors: colors,
              message: language.t('dialog_saved_toast', {'name': updated.name}),
              icon: Icons.check_circle_rounded,
              accentColor: colors.accentEmerald,
            );
          }
        },
      ),
    ],
  );
}

Widget _buildTextField(
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

Future<bool?> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final theme = context.read<ThemeProvider>();
  final colors = theme.colors;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.scaffoldBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.cardBorder),
      ),
      title: Text(
        title,
        style: TextStyle(color: colors.textPrimary, fontSize: 16),
      ),
      content: Text(
        message,
        style: TextStyle(color: colors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Hủy bỏ', style: TextStyle(color: colors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accentRose,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final dynamic colors;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
