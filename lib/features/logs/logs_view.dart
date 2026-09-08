import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../theme/language_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../data/repositories/log_repository.dart';

class LogsView extends StatefulWidget {
  const LogsView({super.key});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final _logRepo = LogRepository();
  String _filter = 'ALL';
  String _searchQuery = '';

  final _searchFocus = FocusNode();
  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final language = context.watch<LanguageProvider>();

    final allLogs = _logRepo.logs;
    final filtered = allLogs.where((log) {
      if (_filter == 'SUCCESS' && log.status != 'SUCCESS') return false;
      if (_filter == 'FAILED' && log.status != 'FAILED') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchDev = log.deviceName.toLowerCase().contains(q);
        final matchIp = log.deviceIp.contains(q);
        final matchAct = log.action.toLowerCase().contains(q);
        final matchMsg = log.message.toLowerCase().contains(q);
        return matchDev || matchIp || matchAct || matchMsg;
      }
      return true;
    }).toList();

    final timeFmt = DateFormat('HH:mm:ss');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.f5): () => setState(() {}),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Toolbar
            GlassCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Search input
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        focusNode: _searchFocus,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: language.t('logs_search_hint'),
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: colors.textMuted,
                          ),
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
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Filter pills: All, Success, Failed
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterPill(
                          'ALL',
                          language.t('logs_filter_all', {
                            'count': allLogs.length.toString(),
                          }),
                          colors,
                        ),
                        _buildFilterPill(
                          'SUCCESS',
                          language.t('logs_filter_success'),
                          colors,
                        ),
                        _buildFilterPill(
                          'FAILED',
                          language.t('logs_filter_failed'),
                          colors,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Refresh list button
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: colors.accentCyan),
                    tooltip: 'Refresh',
                    onPressed: () => setState(() {}),
                  ),
                  const SizedBox(width: 6),

                  // Clear logs button
                  GlassButton(
                    label: language.t('logs_btn_clear'),
                    icon: Icons.delete_sweep_rounded,
                    colors: colors,
                    accentColor: colors.accentRose,
                    onTap: () {
                      setState(() {
                        _logRepo.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Logs Table
            Expanded(
              child: GlassCard(
                colors: colors,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          bottom: BorderSide(color: colors.cardBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              language.t('logs_col_time'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              language.t('logs_col_action'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: Text(
                              language.t('logs_col_device'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              language.t('logs_col_result'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              language.t('logs_col_details'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // List of logs
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                language.t('logs_empty'),
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  Divider(height: 1, color: colors.cardBorder),
                              itemBuilder: (ctx, index) {
                                final log = filtered[index];
                                final isSuccess = log.status == 'SUCCESS';
                                final isFailed = log.status == 'FAILED';

                                final statusColor = isSuccess
                                    ? colors.accentEmerald
                                    : (isFailed
                                          ? colors.accentRose
                                          : colors.accentCyan);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      // Time
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          timeFmt.format(log.timestamp),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                      ),

                                      // Action
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          log.action,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colors.accentCyan,
                                          ),
                                        ),
                                      ),

                                      // Device
                                      SizedBox(
                                        width: 140,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log.deviceName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: colors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              log.deviceIp,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                                color: colors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Status
                                      SizedBox(
                                        width: 90,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              log.status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Message
                                      Expanded(
                                        child: Text(
                                          log.message,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String val, String label, dynamic colors) {
    final isSelected = _filter == val;
    return InkWell(
      onTap: () => setState(() => _filter = val),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accentCyan.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.accentCyan : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
