import 'dart:convert';
import 'dart:io';

class LocalBackgroundEventService {
  LocalBackgroundEventService._();

  static final LocalBackgroundEventService instance =
      LocalBackgroundEventService._();

  Future<String?> pollEvent() async {
    final file = await _resolveEventFile();
    if (file == null || !file.existsSync()) {
      return null;
    }

    try {
      final raw = await file.readAsString();
      await file.delete();
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      return payload['event'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _resolveEventFile() async {
    final envRoot = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      final file = File(
        '$envRoot${Platform.pathSeparator}runtime${Platform.pathSeparator}background_event.json',
      );
      return file;
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
      final runtimeDir = Directory(
        '${root.path}${Platform.pathSeparator}runtime',
      );
      if (runtimeDir.existsSync()) {
        return File(
          '${runtimeDir.path}${Platform.pathSeparator}background_event.json',
        );
      }
    }
    return null;
  }
}
