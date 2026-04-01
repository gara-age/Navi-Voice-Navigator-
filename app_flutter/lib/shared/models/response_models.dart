class SessionStartResponseModel {
  const SessionStartResponseModel({
    required this.sessionId,
    required this.status,
    required this.websocketChannel,
  });

  final String sessionId;
  final String status;
  final String websocketChannel;

  factory SessionStartResponseModel.fromJson(Map<String, dynamic> json) {
    return SessionStartResponseModel(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      websocketChannel: json['websocket_channel'] as String,
    );
  }
}

class CommandResponseModel {
  const CommandResponseModel({
    required this.sessionId,
    required this.status,
    required this.transcript,
    required this.summary,
    required this.resultsPreview,
    required this.tts,
    this.followUp,
  });

  final String sessionId;
  final String status;
  final String transcript;
  final String summary;
  final String? followUp;
  final List<Map<String, dynamic>> resultsPreview;
  final Map<String, dynamic> tts;

  factory CommandResponseModel.fromJson(Map<String, dynamic> json) {
    return CommandResponseModel(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      transcript: json['transcript'] as String,
      summary: json['summary'] as String,
      followUp: json['follow_up'] as String?,
      resultsPreview: (json['results_preview'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      tts: Map<String, dynamic>.from(json['tts'] as Map? ?? const {}),
    );
  }
}

class ScreenReadResponseModel {
  const ScreenReadResponseModel({
    required this.sessionId,
    required this.status,
    required this.summary,
  });

  final String sessionId;
  final String status;
  final String summary;

  factory ScreenReadResponseModel.fromJson(Map<String, dynamic> json) {
    return ScreenReadResponseModel(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      summary: json['summary'] as String,
    );
  }
}

class SettingsUpdateResponseModel {
  const SettingsUpdateResponseModel({
    required this.status,
    required this.appliedSettings,
  });

  final String status;
  final Map<String, dynamic> appliedSettings;

  factory SettingsUpdateResponseModel.fromJson(Map<String, dynamic> json) {
    return SettingsUpdateResponseModel(
      status: json['status'] as String,
      appliedSettings: Map<String, dynamic>.from(json['applied_settings'] as Map? ?? const {}),
    );
  }
}

class SettingsResponseModel {
  const SettingsResponseModel({
    required this.settings,
  });

  final Map<String, dynamic> settings;

  factory SettingsResponseModel.fromJson(Map<String, dynamic> json) {
    return SettingsResponseModel(
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
    );
  }
}
