import 'dart:io';
import '../process/process_runner.dart';

/// Lightweight helper to open native Windows Open/Save file dialogs without extra heavy plugins.
class FileDialogHelper {
  /// Opens a native Windows Save File dialog and returns the selected path, or null if cancelled.
  static Future<String?> pickSaveFile({
    String defaultFileName = 'ja_remote_config.json',
    String title = 'Xuất file cấu hình JSON',
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return null;

    final safeTitle = title.replaceAll("'", "''");
    final safeFileName = defaultFileName.replaceAll("'", "''");
    final safeInitial =
        (initialDirectory != null && initialDirectory.trim().isNotEmpty)
        ? initialDirectory.trim().replaceAll("'", "''")
        : '';

    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms
\$d = New-Object System.Windows.Forms.SaveFileDialog
\$d.Title = '$safeTitle'
\$d.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
\$d.FileName = '$safeFileName'
\$initialDir = '$safeInitial'
if (\$initialDir -and (Test-Path \$initialDir)) {
    \$d.InitialDirectory = \$initialDir
} else {
    \$d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
}
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
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return null;

    final safeTitle = title.replaceAll("'", "''");
    final safeInitial =
        (initialDirectory != null && initialDirectory.trim().isNotEmpty)
        ? initialDirectory.trim().replaceAll("'", "''")
        : '';

    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms
\$d = New-Object System.Windows.Forms.OpenFileDialog
\$d.Title = '$safeTitle'
\$d.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
\$initialDir = '$safeInitial'
if (\$initialDir -and (Test-Path \$initialDir)) {
    \$d.InitialDirectory = \$initialDir
} else {
    \$d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
}
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

  /// Opens a native Windows Open File dialog with customizable filter and title.
  static Future<String?> pickAnyFile({
    String filter = 'All Files (*.*)|*.*',
    String title = 'Chọn file để truyền',
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return null;

    final safeTitle = title.replaceAll("'", "''");
    final safeFilter = filter.replaceAll("'", "''");
    final safeInitial =
        (initialDirectory != null && initialDirectory.trim().isNotEmpty)
        ? initialDirectory.trim().replaceAll("'", "''")
        : '';

    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms
\$d = New-Object System.Windows.Forms.OpenFileDialog
\$d.Title = '$safeTitle'
\$d.Filter = '$safeFilter'
\$initialDir = '$safeInitial'
if (\$initialDir -and (Test-Path \$initialDir)) {
    \$d.InitialDirectory = \$initialDir
} else {
    \$d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
}
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

  /// Opens a modern Windows Explorer Folder Picker dialog (with address bar, breadcrumb navigation,
  /// Quick Access, and direct path pasting) and returns the selected folder path, or null if cancelled.
  static Future<String?> pickDirectory({
    String title = 'Chọn thư mục để truyền',
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return null;

    final safeTitle = title.replaceAll("'", "''");
    final safeInitial =
        (initialDirectory != null && initialDirectory.trim().isNotEmpty)
        ? initialDirectory.trim().replaceAll("'", "''")
        : '';

    final script =
        '''
\$title = '$safeTitle'
\$initialDir = '$safeInitial'

try {
    \$Assembly = [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    \$dialog = New-Object System.Windows.Forms.OpenFileDialog
    \$dialog.AddExtension = \$false
    \$dialog.CheckFileExists = \$false
    \$dialog.DereferenceLinks = \$true
    \$dialog.Filter = 'Folders|`n'
    \$dialog.Multiselect = \$false
    \$dialog.Title = \$title
    if (\$initialDir -and (Test-Path \$initialDir)) {
        \$dialog.InitialDirectory = \$initialDir
    } else {
        \$dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    }

    \$type = \$dialog.GetType()
    \$nativeInterface = \$Assembly.GetType('System.Windows.Forms.FileDialogNative+IFileDialog')
    \$bindingFlags = [System.Reflection.BindingFlags]'NonPublic,Public,Static,Instance'
    \$vistaDialog = \$type.GetMethod('CreateVistaDialog', \$bindingFlags).Invoke(\$dialog, \$null)
    \$null = \$type.GetMethod('OnBeforeVistaDialog', \$bindingFlags).Invoke(\$dialog, \$vistaDialog)
    \$pickFolders = \$Assembly.GetType('System.Windows.Forms.FileDialogNative+FOS').GetField('FOS_PICKFOLDERS').GetValue(\$null)
    \$options = \$type.GetMethod('get_Options', \$bindingFlags).Invoke(\$dialog, \$null) -bor \$pickFolders
    \$null = \$nativeInterface.GetMethod('SetOptions', \$bindingFlags).Invoke(\$vistaDialog, \$options)
    \$showResult = \$nativeInterface.GetMethod('Show', \$bindingFlags).Invoke(\$vistaDialog, [IntPtr]::Zero)
    if (\$showResult -eq 0) {
        \$resultItem = \$nativeInterface.GetMethod('GetResult', \$bindingFlags).Invoke(\$vistaDialog, \$null)
        \$sigdnType = \$Assembly.GetType('System.Windows.Forms.FileDialogNative+SIGDN')
        \$sigdnVal = [Enum]::Parse(\$sigdnType, 'SIGDN_FILESYSPATH')
        \$invParams = [object[]]@(\$sigdnVal, \$null)
        \$shellItemType = \$Assembly.GetType('System.Windows.Forms.FileDialogNative+IShellItem')
        \$null = \$shellItemType.GetMethod('GetDisplayName', \$bindingFlags).Invoke(\$resultItem, \$invParams)
        if (\$invParams[1]) {
            Write-Output \$invParams[1]
        }
    }
} catch {
    # Fallback to standard FolderBrowserDialog if reflection fails
    Add-Type -AssemblyName System.Windows.Forms
    \$fallback = New-Object System.Windows.Forms.FolderBrowserDialog
    \$fallback.Description = \$title
    \$fallback.ShowNewFolderButton = \$true
    if (\$initialDir -and (Test-Path \$initialDir)) {
        \$fallback.SelectedPath = \$initialDir
    } else {
        \$fallback.SelectedPath = [Environment]::GetFolderPath('Desktop')
    }
    if (\$fallback.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Output \$fallback.SelectedPath
    }
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
