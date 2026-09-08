import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../data/models/managed_device.dart';
import '../../services/device_service.dart';

void showAddDeviceDialog(BuildContext context) {
  final theme = context.read<ThemeProvider>();
  final colors = theme.colors;
  final language = context.read<LanguageProvider>();
  final deviceService = context.read<DeviceService>();

  final nameController = TextEditingController();
  final ipController = TextEditingController();
  final macController = TextEditingController();
  final groupController = TextEditingController(text: 'Factory');
  final noteController = TextEditingController();

  showGlassDialog(
    context: context,
    colors: colors,
    title: language.t('dialog_add_title'),
    icon: Icons.add_to_queue_rounded,
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInput(language.t('dialog_name_label'), nameController, colors),
          const SizedBox(height: 10),
          _buildInput(language.t('dialog_ip_label'), ipController, colors),
          const SizedBox(height: 10),
          _buildInput(language.t('dialog_mac_label'), macController, colors),
          const SizedBox(height: 10),
          _buildInput(
            language.t('dialog_group_label'),
            groupController,
            colors,
          ),
          const SizedBox(height: 10),
          _buildInput(language.t('dialog_note_label'), noteController, colors),
        ],
      ),
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
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
            online: false,
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
  dynamic colors,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
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
