part of 'dashboard_shell.dart';

class _SettingsMacOuiTab extends StatefulWidget {
  final AppColors colors;
  final LanguageProvider language;

  const _SettingsMacOuiTab({required this.colors, required this.language});

  @override
  State<_SettingsMacOuiTab> createState() => _SettingsMacOuiTabState();
}

class _SettingsMacOuiTabState extends State<_SettingsMacOuiTab> {
  final _prefixController = TextEditingController();
  final _vendorController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _prefixController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final prefix = _prefixController.text.trim();
    final vendor = _vendorController.text.trim();

    final cleanedOui = MacOuiResolver.cleanOUI(prefix);
    if (cleanedOui == null) {
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_invalid_prefix'),
        icon: Icons.warning_rounded,
        accentColor: widget.colors.accentAmber,
      );
      return;
    }

    if (vendor.isEmpty) {
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_vendor_required'),
        icon: Icons.warning_rounded,
        accentColor: widget.colors.accentAmber,
      );
      return;
    }

    setState(() => _isLoading = true);
    await MacOuiResolver.setCustomMapping(cleanedOui, vendor);
    _prefixController.clear();
    _vendorController.clear();
    if (mounted) {
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_toast_saved', {
          'oui': cleanedOui,
          'vendor': vendor,
        }),
        icon: Icons.check_circle_rounded,
        accentColor: widget.colors.accentEmerald,
      );
    }
  }

  Future<void> _handleDelete(String oui) async {
    setState(() => _isLoading = true);
    await MacOuiResolver.removeCustomMapping(oui);
    if (mounted) {
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_toast_deleted', {'oui': oui}),
        icon: Icons.delete_outline_rounded,
        accentColor: widget.colors.accentRose,
      );
    }
  }

  Future<void> _handleReload() async {
    setState(() => _isLoading = true);
    final count = await MacOuiResolver.loadCustomMappings();
    if (mounted) {
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_toast_reloaded', {
          'count': count.toString(),
        }),
        icon: Icons.refresh_rounded,
        accentColor: widget.colors.accentCyan,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final lang = widget.language;
    final customEntries = MacOuiResolver.customMap.entries.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header & Actions Bento Card
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(14),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.memory_rounded,
                        color: colors.accentCyan,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.t('oui_header_title'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lang.t('oui_header_desc'),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      icon: Icons.description_outlined,
                      label: lang.t('oui_btn_open_file'),
                      color: colors.accentCyan,
                      onTap: () => MacOuiResolver.openConfigFile(),
                    ),
                    _buildActionButton(
                      icon: Icons.folder_open_rounded,
                      label: lang.t('oui_btn_open_folder'),
                      color: colors.accentEmerald,
                      onTap: () => MacOuiResolver.openConfigFolder(),
                    ),
                    _buildActionButton(
                      icon: Icons.refresh_rounded,
                      label: lang.t('oui_btn_reload'),
                      color: colors.accentAmber,
                      onTap: _handleReload,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Add New OUI Mapping Card
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(14),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('oui_input_prefix_label'),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _prefixController,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w600,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: lang.t('oui_input_prefix_hint'),
                          hintStyle: TextStyle(
                            color: colors.textMuted.withValues(alpha: 0.6),
                            fontSize: 11.5,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          filled: true,
                          fillColor: colors.subCardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.accentCyan),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _vendorController,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: lang.t('oui_input_vendor_hint'),
                          hintStyle: TextStyle(
                            color: colors.textMuted.withValues(alpha: 0.6),
                            fontSize: 11.5,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          filled: true,
                          fillColor: colors.subCardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.accentCyan),
                          ),
                        ),
                        onSubmitted: (_) => _handleSave(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlowingActionButton(
                      height: 36,
                      colors: colors,
                      icon: Icons.add_rounded,
                      label: lang.t('oui_btn_save'),
                      onPressed: _isLoading ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Custom Entries List Card
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(14),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.t('oui_custom_list_title', {
                        'count': customEntries.length.toString(),
                      }),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      lang.t('oui_status_summary', {
                        'custom': customEntries.length.toString(),
                        'builtin': MacOuiResolver.totalBuiltInCount.toString(),
                      }),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (customEntries.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.subCardBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.subCardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        lang.t('oui_empty_custom', {
                          'count': MacOuiResolver.totalBuiltInCount.toString(),
                        }),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = customEntries[index];
                      final formattedOui =
                          '${item.key.substring(0, 2)}:${item.key.substring(2, 4)}:${item.key.substring(4, 6)}';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.subCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.subCardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentCyan.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: colors.accentCyan.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                formattedOui,
                                style: TextStyle(
                                  color: colors.accentCyan,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.value,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: colors.accentRose,
                              ),
                              tooltip: 'Delete',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => _handleDelete(item.key),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = widget.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
