import 'dart:convert';
import 'dart:io';

class LocalUiStateService {
  LocalUiStateService._();

  static final LocalUiStateService instance = LocalUiStateService._();

  Future<void> setSettingsModalOpen(bool isOpen) async {
    await _writeState({
      'settings_modal_open': isOpen,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setAppFocused(bool isFocused) async {
    await _writeState({
      'app_focused': isFocused,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _writeState(Map<String, dynamic> patch) async {
    final file = await _resolveStateFile();
    if (file == null) {
      return;
    }

    try {
      final current = await _readState(file);
      current.addAll(patch);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(current),
      );
    } catch (_) {
      // Ignore local state write failures.
    }
  }

  Future<Map<String, dynamic>> _readState(File file) async {
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    try {
      final raw = await file.readAsString();
      return Map<String, dynamic>.from(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<File?> _resolveStateFile() async {
    final envRoot = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      return File(
        '$envRoot${Platform.pathSeparator}runtime${Platform.pathSeparator}ui_state.json',
      );
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
          '${runtimeDir.path}${Platform.pathSeparator}ui_state.json',
        );
      }
    }

    return null;
  }
}
