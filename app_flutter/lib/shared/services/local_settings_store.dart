import 'dart:convert';
import 'dart:io';

import '../models/settings_models.dart';

class LocalSettingsStore {
  LocalSettingsStore._();

  static final LocalSettingsStore instance = LocalSettingsStore._();

  Future<AppSettings> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return AppSettings.defaults();
    }

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
  }

  Future<File> _settingsFile() async {
    final rootPath = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (rootPath != null && rootPath.isNotEmpty) {
      return File('$rootPath${Platform.pathSeparator}runtime${Platform.pathSeparator}settings.json');
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
          Directory('${root.path}${Platform.pathSeparator}app_flutter').existsSync() &&
          Directory('${root.path}${Platform.pathSeparator}background_service').existsSync();
      if (hasProjectMarkers) {
        return File(
          '${root.path}${Platform.pathSeparator}runtime${Platform.pathSeparator}settings.json',
        );
      }

      final runtimeDir = Directory(
        '${root.path}${Platform.pathSeparator}runtime',
      );
      if (runtimeDir.existsSync()) {
        return File(
          '${runtimeDir.path}${Platform.pathSeparator}settings.json',
        );
      }
    }

    return File(
      '${Directory.current.path}${Platform.pathSeparator}runtime${Platform.pathSeparator}settings.json',
    );
  }
}
