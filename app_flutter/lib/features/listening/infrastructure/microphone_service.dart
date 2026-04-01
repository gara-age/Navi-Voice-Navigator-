import 'dart:io';

class RecordedClip {
  const RecordedClip({
    required this.filePath,
    required this.durationMs,
  });

  final String filePath;
  final int durationMs;
}

class MicrophoneService {
  MicrophoneService();

  DateTime? _startedAt;
  String? _pendingPath;

  Future<void> start() async {
    _startedAt = DateTime.now();
    final directory = Directory.systemTemp;
    _pendingPath =
        '${directory.path}${Platform.pathSeparator}voice_navigator_input_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  Future<RecordedClip?> stop() async {
    final path = _pendingPath;
    if (path == null) {
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      await file.writeAsBytes(const <int>[]);
    }

    final startedAt = _startedAt ?? DateTime.now();
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    _pendingPath = null;
    _startedAt = null;
    return RecordedClip(filePath: path, durationMs: durationMs);
  }
}
