import 'dart:io';

enum TaskbarPopupState {
  listening,
  processing,
  success,
  retry,
  warning,
  error,
  appError,
  secure,
  themeDark,
  themeContrast,
  themeLargeText,
  info,
}

enum TaskbarPopupThemeMode {
  light,
  dark,
  contrast,
}

class TaskbarPopupService {
  TaskbarPopupService._();

  static final TaskbarPopupService instance = TaskbarPopupService._();

  Future<bool> show({
    required String title,
    required String message,
    int durationMs = 5000,
    TaskbarPopupState state = TaskbarPopupState.info,
    TaskbarPopupThemeMode themeMode = TaskbarPopupThemeMode.light,
    bool largeText = false,
  }) async {
    if (!Platform.isWindows) {
      return false;
    }

    final scriptPath = _findScriptPath();
    if (scriptPath == null) {
      return false;
    }

    const powershell = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
    final executable = File(powershell).existsSync() ? powershell : 'powershell';

    try {
      await Process.start(
        executable,
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
          '-Title',
          title,
          '-Message',
          message,
          '-DurationMs',
          durationMs.toString(),
          '-State',
          state.name,
          '-ThemeMode',
          themeMode.name,
          '-LargeText',
          largeText ? '1' : '0',
        ],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _findScriptPath() {
    final envRoot = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      final fromEnv = '$envRoot${Platform.pathSeparator}scripts${Platform.pathSeparator}show_taskbar_popup.ps1';
      if (File(fromEnv).existsSync()) {
        return fromEnv;
      }
    }

    final separator = Platform.pathSeparator;
    final roots = <String>{};

    void addAncestors(String startPath) {
      var dir = Directory(startPath);
      for (var i = 0; i < 8; i++) {
        roots.add(dir.path);
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
    }

    addAncestors(Directory.current.path);
    addAncestors(File(Platform.resolvedExecutable).parent.path);

    for (final root in roots) {
      final candidate = '$root${separator}scripts${separator}show_taskbar_popup.ps1';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }
}
