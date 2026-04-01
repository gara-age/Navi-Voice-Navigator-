class AppSettings {
  const AppSettings({
    required this.general,
    required this.shortcuts,
    required this.security,
    required this.display,
  });

  final GeneralSettings general;
  final ShortcutSettings shortcuts;
  final SecuritySettings security;
  final DisplaySettings display;

  factory AppSettings.defaults() {
    return const AppSettings(
      general: GeneralSettings(
        autoLanguageDetection: true,
        microphoneSensitivity: 0.72,
        ttsSpeed: 1.0,
        voiceType: 'ko-KR-Neural2-A',
        autoErrorLogUpload: false,
      ),
      shortcuts: ShortcutSettings(
        enabled: true,
        listenToggle: 'F2',
        screenRead: 'F3',
        openSettings: '',
      ),
      security: SecuritySettings(
        secureInputMode: false,
        autoLockTimeoutSeconds: 180,
        sensitiveDomainAlert: true,
      ),
      display: DisplaySettings(
        darkTheme: false,
        highContrast: false,
        largeText: false,
      ),
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final generalJson = Map<String, dynamic>.from(json['general'] as Map? ?? const {});
    final shortcutsJson = Map<String, dynamic>.from(json['shortcuts'] as Map? ?? const {});
    final securityJson = Map<String, dynamic>.from(json['security'] as Map? ?? const {});
    final displayJson = Map<String, dynamic>.from(json['display'] as Map? ?? const {});

    return AppSettings(
      general: GeneralSettings(
        autoLanguageDetection:
            generalJson['auto_language_detection'] as bool? ?? true,
        microphoneSensitivity:
            (generalJson['microphone_sensitivity'] as num?)?.toDouble() ?? 0.72,
        ttsSpeed: (generalJson['tts_speed'] as num?)?.toDouble() ?? 1.0,
        voiceType: generalJson['voice_type'] as String? ?? 'ko-KR-Neural2-A',
        autoErrorLogUpload: generalJson['auto_error_log_upload'] as bool? ?? false,
      ),
      shortcuts: ShortcutSettings(
        enabled: shortcutsJson['enabled'] as bool? ?? true,
        listenToggle: shortcutsJson['listen_toggle'] as String? ?? 'F2',
        screenRead: shortcutsJson['screen_read'] as String? ?? 'F3',
        openSettings: shortcutsJson['open_settings'] as String? ?? '',
      ),
      security: SecuritySettings(
        secureInputMode: securityJson['secure_input_mode'] as bool? ?? false,
        autoLockTimeoutSeconds:
            securityJson['auto_lock_timeout_seconds'] as int? ?? 180,
        sensitiveDomainAlert:
            securityJson['sensitive_domain_alert'] as bool? ?? true,
      ),
      display: DisplaySettings(
        darkTheme: displayJson['dark_theme'] as bool? ?? false,
        highContrast: displayJson['high_contrast'] as bool? ?? false,
        largeText: displayJson['large_text'] as bool? ?? false,
      ),
    );
  }

  AppSettings copyWith({
    GeneralSettings? general,
    ShortcutSettings? shortcuts,
    SecuritySettings? security,
    DisplaySettings? display,
  }) {
    return AppSettings(
      general: general ?? this.general,
      shortcuts: shortcuts ?? this.shortcuts,
      security: security ?? this.security,
      display: display ?? this.display,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'general': general.toJson(),
      'shortcuts': shortcuts.toJson(),
      'security': security.toJson(),
      'display': display.toJson(),
    };
  }
}

class GeneralSettings {
  const GeneralSettings({
    required this.autoLanguageDetection,
    required this.microphoneSensitivity,
    required this.ttsSpeed,
    required this.voiceType,
    required this.autoErrorLogUpload,
  });

  final bool autoLanguageDetection;
  final double microphoneSensitivity;
  final double ttsSpeed;
  final String voiceType;
  final bool autoErrorLogUpload;

  GeneralSettings copyWith({
    bool? autoLanguageDetection,
    double? microphoneSensitivity,
    double? ttsSpeed,
    String? voiceType,
    bool? autoErrorLogUpload,
  }) {
    return GeneralSettings(
      autoLanguageDetection:
          autoLanguageDetection ?? this.autoLanguageDetection,
      microphoneSensitivity:
          microphoneSensitivity ?? this.microphoneSensitivity,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      voiceType: voiceType ?? this.voiceType,
      autoErrorLogUpload: autoErrorLogUpload ?? this.autoErrorLogUpload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_language_detection': autoLanguageDetection,
      'microphone_sensitivity': microphoneSensitivity,
      'tts_speed': ttsSpeed,
      'voice_type': voiceType,
      'auto_error_log_upload': autoErrorLogUpload,
    };
  }
}

class ShortcutSettings {
  const ShortcutSettings({
    required this.enabled,
    required this.listenToggle,
    required this.screenRead,
    required this.openSettings,
  });

  final bool enabled;
  final String listenToggle;
  final String screenRead;
  final String openSettings;

  ShortcutSettings copyWith({
    bool? enabled,
    String? listenToggle,
    String? screenRead,
    String? openSettings,
  }) {
    return ShortcutSettings(
      enabled: enabled ?? this.enabled,
      listenToggle: listenToggle ?? this.listenToggle,
      screenRead: screenRead ?? this.screenRead,
      openSettings: openSettings ?? this.openSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'listen_toggle': listenToggle,
      'screen_read': screenRead,
      'open_settings': openSettings,
    };
  }
}

class SecuritySettings {
  const SecuritySettings({
    required this.secureInputMode,
    required this.autoLockTimeoutSeconds,
    required this.sensitiveDomainAlert,
  });

  final bool secureInputMode;
  final int autoLockTimeoutSeconds;
  final bool sensitiveDomainAlert;

  SecuritySettings copyWith({
    bool? secureInputMode,
    int? autoLockTimeoutSeconds,
    bool? sensitiveDomainAlert,
  }) {
    return SecuritySettings(
      secureInputMode: secureInputMode ?? this.secureInputMode,
      autoLockTimeoutSeconds: autoLockTimeoutSeconds ?? this.autoLockTimeoutSeconds,
      sensitiveDomainAlert: sensitiveDomainAlert ?? this.sensitiveDomainAlert,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secure_input_mode': secureInputMode,
      'auto_lock_timeout_seconds': autoLockTimeoutSeconds,
      'sensitive_domain_alert': sensitiveDomainAlert,
    };
  }
}

class DisplaySettings {
  const DisplaySettings({
    required this.darkTheme,
    required this.highContrast,
    required this.largeText,
  });

  final bool darkTheme;
  final bool highContrast;
  final bool largeText;

  DisplaySettings copyWith({
    bool? darkTheme,
    bool? highContrast,
    bool? largeText,
  }) {
    return DisplaySettings(
      darkTheme: darkTheme ?? this.darkTheme,
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dark_theme': darkTheme,
      'high_contrast': highContrast,
      'large_text': largeText,
    };
  }
}
