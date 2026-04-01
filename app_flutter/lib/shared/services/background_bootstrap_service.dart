import 'dart:io';

class BackgroundBootstrapService {
  BackgroundBootstrapService._();

  static final BackgroundBootstrapService instance =
      BackgroundBootstrapService._();

  bool _started = false;

  Future<void> ensureStarted() async {
    if (_started || !Platform.isWindows) {
      return;
    }
    _started = true;

    try {
      if (await _isBackgroundRunning()) {
        return;
      }

      final root = _resolveProjectRoot();
      if (root == null) {
        return;
      }

      final aliasedExe = File(
        '$root${Platform.pathSeparator}.venv-background${Platform.pathSeparator}Scripts${Platform.pathSeparator}Navi Background.exe',
      );
      final packagedExe = File(
        '$root${Platform.pathSeparator}dist${Platform.pathSeparator}background${Platform.pathSeparator}Navi Background.exe',
      );
      final pythonwExe = File(
        '$root${Platform.pathSeparator}.venv-background${Platform.pathSeparator}Scripts${Platform.pathSeparator}pythonw.exe',
      );
      final mainScript =
          '$root${Platform.pathSeparator}background_service${Platform.pathSeparator}src${Platform.pathSeparator}main.py';

      if (await packagedExe.exists()) {
        try {
          await Process.start(
            packagedExe.path,
            const [],
            workingDirectory: root,
            runInShell: false,
          );
          return;
        } catch (_) {}
      }

      if (await aliasedExe.exists()) {
        try {
          await Process.start(
            aliasedExe.path,
            [mainScript],
            workingDirectory: root,
            runInShell: false,
          );
          return;
        } catch (_) {}
      }

      if (await pythonwExe.exists()) {
        try {
          await Process.start(
            pythonwExe.path,
            [mainScript],
            workingDirectory: root,
            runInShell: false,
          );
          return;
        } catch (_) {}
      }

      await Process.start(
        'powershell',
        [
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          '$root${Platform.pathSeparator}scripts${Platform.pathSeparator}run_background.ps1',
        ],
        workingDirectory: root,
        runInShell: false,
      );
    } catch (_) {}
  }

  Future<bool> _isBackgroundRunning() async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FO', 'CSV', '/NH'],
        runInShell: false,
      );
      final stdout = (result.stdout ?? '').toString().toLowerCase();
      return stdout.contains('navi background.exe');
    } catch (_) {
      return false;
    }
  }

  String? _resolveProjectRoot() {
    final rootPath = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (rootPath != null && rootPath.isNotEmpty) {
      return rootPath;
    }

    final roots = <Directory>[];

    void addAncestors(Directory directory) {
      var current = directory;
      for (var i = 0; i < 8; i++) {
        roots.add(current);
        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }

    addAncestors(Directory.current);
    addAncestors(File(Platform.resolvedExecutable).parent);

    for (final root in roots) {
      final hasProjectMarkers =
          Directory('${root.path}${Platform.pathSeparator}app_flutter')
              .existsSync() &&
          Directory('${root.path}${Platform.pathSeparator}background_service')
              .existsSync();
      if (hasProjectMarkers) {
        return root.path;
      }
    }

    return null;
  }
}
