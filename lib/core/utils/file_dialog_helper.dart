import 'dart:io';
import '../process/process_runner.dart';

/// Lightweight helper to open native Windows Open/Save file dialogs without extra heavy plugins.
class FileDialogHelper {
  /// Opens a native Windows Save File dialog and returns the selected path, or null if cancelled.
  static Future<String?> pickSaveFile({
    String defaultFileName = 'ja_remote_config.json',
    String title = 'Xuất file cấu hình JSON',
  }) async {
    if (!Platform.isWindows) return null;

    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms
\$d = New-Object System.Windows.Forms.SaveFileDialog
\$d.Title = '$title'
\$d.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
\$d.FileName = '$defaultFileName'
\$d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
if (\$d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$d.FileName
}
''';

    try {
      final encoded = ProcessRunner.toEncodedCommand(script);
      final res = await Process.run('powershell.exe', [
        '-Sta',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        encoded,
      ]);
      final out = res.stdout.toString().trim();
      return out.isNotEmpty ? out : null;
    } catch (_) {
      return null;
    }
  }

  /// Opens a native Windows Open File dialog and returns the selected path, or null if cancelled.
  static Future<String?> pickOpenFile({
    String title = 'Chọn file cấu hình JSON để nhập',
  }) async {
    if (!Platform.isWindows) return null;

    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms
\$d = New-Object System.Windows.Forms.OpenFileDialog
\$d.Title = '$title'
\$d.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
\$d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
if (\$d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$d.FileName
}
''';

    try {
      final encoded = ProcessRunner.toEncodedCommand(script);
      final res = await Process.run('powershell.exe', [
        '-Sta',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        encoded,
      ]);
      final out = res.stdout.toString().trim();
      return out.isNotEmpty ? out : null;
    } catch (_) {
      return null;
    }
  }
}
