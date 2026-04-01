import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/settings_models.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/local_settings_store.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._apiClient) : super(AppSettings.defaults());

  final ApiClient _apiClient;

  void replaceAll(AppSettings settings) {
    state = settings;
  }

  void setSecureMode(bool enabled) {
    state = state.copyWith(
      security: state.security.copyWith(secureInputMode: enabled),
    );
  }

  void setAutoLanguageDetection(bool enabled) {
    state = state.copyWith(
      general: state.general.copyWith(autoLanguageDetection: enabled),
    );
  }

  void setMicrophoneSensitivity(double value) {
    state = state.copyWith(
      general: state.general.copyWith(microphoneSensitivity: value),
    );
  }

  void setTtsSpeed(double value) {
    state = state.copyWith(
      general: state.general.copyWith(ttsSpeed: value),
    );
  }

  void setVoiceType(String value) {
    state = state.copyWith(
      general: state.general.copyWith(voiceType: value),
    );
  }

  void setAutoErrorLogUpload(bool enabled) {
    state = state.copyWith(
      general: state.general.copyWith(autoErrorLogUpload: enabled),
    );
  }

  void setShortcutEnabled(bool enabled) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(enabled: enabled),
    );
  }

  void setListenToggleShortcut(String value) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(listenToggle: value),
    );
  }

  void setScreenReadShortcut(String value) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(screenRead: value),
    );
  }

  void setOpenSettingsShortcut(String value) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(openSettings: value),
    );
  }

  void setAutoLockTimeout(int seconds) {
    state = state.copyWith(
      security: state.security.copyWith(autoLockTimeoutSeconds: seconds),
    );
  }

  void setSensitiveDomainAlert(bool enabled) {
    state = state.copyWith(
      security: state.security.copyWith(sensitiveDomainAlert: enabled),
    );
  }

  void setDarkTheme(bool enabled) {
    state = state.copyWith(
      display: state.display.copyWith(
        darkTheme: enabled,
        highContrast: enabled ? false : state.display.highContrast,
      ),
    );
  }

  void setHighContrast(bool enabled) {
    state = state.copyWith(
      display: state.display.copyWith(
        highContrast: enabled,
        darkTheme: enabled ? false : state.display.darkTheme,
      ),
    );
  }

  void setLargeText(bool enabled) {
    state = state.copyWith(
      display: state.display.copyWith(largeText: enabled),
    );
  }

  Future<void> load() async {
    state = await LocalSettingsStore.instance.load();

    try {
      final response = await _apiClient.getCurrentSettings();
      if (response.settings.isEmpty) {
        return;
      }
      state = AppSettings.fromJson(response.settings);
      await LocalSettingsStore.instance.save(state);
    } catch (_) {
      // Keep local settings when the local server is not available.
    }
  }

  Future<bool> save() async {
    await LocalSettingsStore.instance.save(state);

    try {
      final response = await _apiClient.updateSettings({
        'settings': state.toJson(),
      });
      return response.status == 'saved';
    } catch (_) {
      return true;
    }
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ApiClient());
});
