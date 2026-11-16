part of 'wol_inspector_dialog.dart';

extension _WolInspectorControlsExt on _WolInspectorDialogBodyState {
  Widget buildManagedControls(
    DeviceService deviceService,
    AppColors colors,
    LanguageProvider language,
  ) {
    return Row(
      children: [
        Expanded(child: buildCredentialRow(colors)),
        const SizedBox(width: 8),
        GlassButton(
          label: language.t('wol_btn_check'),
          icon: Icons.fact_check_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: _isRunning
              ? null
              : () => _runManagedBatch(
                  deviceService: deviceService,
                  colors: colors,
                  language: language,
                  applyFix: false,
                ),
        ),
        const SizedBox(width: 6),
        GlassButton(
          label: language.t('wol_btn_fix'),
          icon: Icons.auto_fix_high_rounded,
          colors: colors,
          accentColor: colors.accentEmerald,
          onTap: _isRunning
              ? null
              : () => _runManagedBatch(
                  deviceService: deviceService,
                  colors: colors,
                  language: language,
                  applyFix: true,
                ),
        ),
      ],
    );
  }

  Widget buildLocalControls(AppColors colors, LanguageProvider language) {
    return Row(
      children: [
        Expanded(
          child: Text(
            language.t('wol_local_desc'),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 10),
        GlassButton(
          label: language.t('wol_btn_check'),
          icon: Icons.refresh_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: _isRunning ? null : _runLocalCheck,
        ),
        const SizedBox(width: 6),
        GlassButton(
          label: language.t('wol_btn_fix_uac'),
          icon: Icons.admin_panel_settings_rounded,
          colors: colors,
          accentColor: colors.accentEmerald,
          onTap: _isRunning ? null : () => _runLocalFix(colors),
        ),
      ],
    );
  }

  Widget buildAdhocControls(
    DeviceService deviceService,
    AppColors colors,
    LanguageProvider language,
  ) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 170,
              child: TextField(
                controller: _adhocIpController,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  color: colors.textPrimary,
                ),
                decoration: compactInputDecoration(
                  'IP (vd: 172.21.175.29)',
                  colors,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _WolOsChip(
              label: 'Windows',
              selected: _adhocOs == 'Windows',
              colors: colors,
              onTap: () => _mutate(() => _adhocOs = 'Windows'),
            ),
            const SizedBox(width: 4),
            _WolOsChip(
              label: 'Linux',
              selected: _adhocOs == 'Linux',
              colors: colors,
              onTap: () => _mutate(() => _adhocOs = 'Linux'),
            ),
            if (_adhocOs == 'Linux') ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 66,
                child: TextField(
                  controller: _adhocPortController,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: colors.textPrimary,
                  ),
                  decoration: compactInputDecoration('Port', colors),
                ),
              ),
            ],
            const Spacer(),
            GlassButton(
              label: language.t('wol_btn_check'),
              icon: Icons.fact_check_rounded,
              colors: colors,
              accentColor: colors.accentCyan,
              onTap: _isRunning
                  ? null
                  : () => _runAdhoc(colors: colors, applyFix: false),
            ),
            const SizedBox(width: 6),
            GlassButton(
              label: language.t('wol_btn_fix'),
              icon: Icons.auto_fix_high_rounded,
              colors: colors,
              accentColor: colors.accentEmerald,
              onTap: _isRunning
                  ? null
                  : () => _runAdhoc(colors: colors, applyFix: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: buildCredentialRow(colors)),
            if (_reports.length == 1 &&
                _reports.first.ip == _adhocIpController.text.trim()) ...[
              const SizedBox(width: 8),
              GlassButton(
                label: language.t('wol_btn_save_device'),
                icon: Icons.save_alt_rounded,
                colors: colors,
                accentColor: colors.accentPurple,
                onTap: () => _syncWolMacToDevice(
                  context: context,
                  report: _reports.first,
                  deviceService: deviceService,
                  colors: colors,
                  username: _userController.text.trim(),
                  password: _passController.text,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget buildCredentialRow(AppColors colors) {
    return Row(
      children: [
        if (_savedCreds.isNotEmpty) ...[
          PopupMenuButton<SavedCredential>(
            tooltip: 'Chọn tài khoản đã lưu',
            icon: Icon(Icons.key_rounded, size: 18, color: colors.accentAmber),
            onSelected: (cred) {
              _mutate(() {
                _userController.text = cred.username;
                _passController.text = cred.password;
              });
            },
            itemBuilder: (_) => _savedCreds
                .map(
                  (c) => PopupMenuItem<SavedCredential>(
                    value: c,
                    child: Text(
                      c.label?.isNotEmpty == true
                          ? '${c.username} (${c.label})'
                          : c.username,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: TextField(
            controller: _userController,
            style: TextStyle(fontSize: 12, color: colors.textPrimary),
            decoration: compactInputDecoration('Username (tùy chọn)', colors),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _passController,
            obscureText: _obscurePass,
            style: TextStyle(fontSize: 12, color: colors.textPrimary),
            decoration: compactInputDecoration(
              'Password / sudo',
              colors,
              suffix: InkWell(
                onTap: () => _mutate(() => _obscurePass = !_obscurePass),
                child: Icon(
                  _obscurePass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 15,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration compactInputDecoration(
    String hint,
    AppColors colors, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11.5, color: colors.textMuted),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: colors.cardBg,
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 24),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: colors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: colors.cardBorder),
      ),
    );
  }

  Widget buildProgressOrFilterBar({
    required AppColors colors,
    required LanguageProvider language,
    required int readyCount,
    required int fixCount,
    required int errCount,
  }) {
    if (_isRunning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _progressText,
                  style: TextStyle(fontSize: 11.5, color: colors.accentCyan),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _service.cancel(),
                child: Text(
                  language.t('action_cancel'),
                  style: TextStyle(fontSize: 11.5, color: colors.accentRose),
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 5,
              backgroundColor: colors.cardBorder,
              color: colors.accentCyan,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _WolFilterPill(
          label: '${language.t('wol_filter_all')} (${_reports.length})',
          selected: _filterMode == 'all',
          color: colors.accentCyan,
          colors: colors,
          onTap: () => _mutate(() => _filterMode = 'all'),
        ),
        _WolFilterPill(
          label: '${language.t('wol_filter_fix')} ($fixCount)',
          selected: _filterMode == 'fix',
          color: colors.accentAmber,
          colors: colors,
          onTap: () => _mutate(() => _filterMode = 'fix'),
        ),
        _WolFilterPill(
          label: '${language.t('wol_filter_ready')} ($readyCount)',
          selected: _filterMode == 'ready',
          color: colors.accentEmerald,
          colors: colors,
          onTap: () => _mutate(() => _filterMode = 'ready'),
        ),
        _WolFilterPill(
          label: '${language.t('wol_filter_error')} ($errCount)',
          selected: _filterMode == 'error',
          color: colors.accentRose,
          colors: colors,
          onTap: () => _mutate(() => _filterMode = 'error'),
        ),
        GlassButton(
          label: language.t('wol_btn_copy_tsv'),
          icon: Icons.copy_rounded,
          colors: colors,
          accentColor: colors.accentCyan,
          onTap: () => _copyWolTsvReport(context, _reports, colors),
        ),
      ],
    );
  }
}

Future<void> _syncWolMacToDevice({
  required BuildContext context,
  required WolAuditReport report,
  required DeviceService deviceService,
  required AppColors colors,
  required String username,
  required String password,
}) async {
  final mac = report.detectedMac;
  if (mac == null || mac.isEmpty) return;
  ManagedDevice? match;
  for (final d in deviceService.devices) {
    if (d.id == report.deviceId || d.ip == report.ip) {
      match = d;
      break;
    }
  }
  if (match == null) {
    await deviceService.addDevice(
      ManagedDevice(
        id: 'dev_${DateTime.now().microsecondsSinceEpoch}',
        name: report.targetName,
        hostname: report.targetName,
        ip: report.ip,
        mac: mac,
        os: report.os,
        online: true,
        username: username.isNotEmpty ? username : null,
        password: password.isNotEmpty ? password : null,
        lastSeen: DateTime.now(),
      ),
    );
    if (context.mounted) {
      showAppToast(
        context,
        colors: colors,
        message: 'Đã lưu ${report.targetName} ($mac) vào Thiết bị!',
        icon: Icons.check_circle_rounded,
        accentColor: colors.accentEmerald,
      );
    }
    return;
  }

  await deviceService.updateDevice(
    match.copyWith(mac: mac, online: true, lastSeen: DateTime.now()),
  );
  if (context.mounted) {
    showAppToast(
      context,
      colors: colors,
      message: 'Đã đồng bộ MAC $mac cho ${match.name}!',
      icon: Icons.check_circle_rounded,
      accentColor: colors.accentEmerald,
    );
  }
}

Future<void> _testWolWake({
  required BuildContext context,
  required PowerService powerService,
  required WolAuditReport report,
  required DeviceService deviceService,
  required AppColors colors,
}) async {
  ManagedDevice? saved;
  for (final d in deviceService.devices) {
    if (d.id == report.deviceId || d.ip == report.ip) {
      saved = d;
      break;
    }
  }
  final mac = report.detectedMac?.isNotEmpty == true
      ? report.detectedMac
      : saved?.mac;
  final dev =
      (saved ??
              ManagedDevice(
                id: 'tmp_${report.ip}',
                name: report.targetName,
                hostname: report.targetName,
                ip: report.ip,
                os: report.os,
              ))
          .copyWith(mac: mac);
  final ok = await powerService.wakeDevice(dev);
  if (!context.mounted) return;
  showAppToast(
    context,
    colors: colors,
    message: ok
        ? 'Đã gửi Magic Packet tới ${report.targetName} (${mac ?? "--"})'
        : 'Không có địa chỉ MAC để gửi Magic Packet!',
    icon: Icons.bolt_rounded,
    accentColor: ok ? colors.accentEmerald : colors.accentRose,
  );
}

void _copyWolTsvReport(
  BuildContext context,
  List<WolAuditReport> reports,
  AppColors colors,
) {
  if (reports.isEmpty) return;
  final sb = StringBuffer()..writeln('HOST\tIP\tOS\tMAC\tSTATUS\tNIC\tLAYERS');
  for (final r in reports) {
    sb.writeln(r.toTsvRow());
  }
  Clipboard.setData(ClipboardData(text: sb.toString()));
  showAppToast(
    context,
    colors: colors,
    message: 'Đã sao chép báo cáo WoL (${reports.length} máy)!',
    icon: Icons.copy_rounded,
    accentColor: colors.accentCyan,
  );
}
