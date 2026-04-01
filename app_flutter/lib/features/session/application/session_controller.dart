import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listening/infrastructure/microphone_service.dart';
import '../../../shared/models/response_models.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/websocket_client.dart';

class SessionUiState {
  const SessionUiState({
    this.sessionId,
    this.websocketChannel,
    this.connectionState = 'idle',
    this.lastSummary,
    this.lastFollowUp,
    this.lastTranscript,
    this.isBusy = false,
    this.isRecording = false,
  });

  final String? sessionId;
  final String? websocketChannel;
  final String connectionState;
  final String? lastSummary;
  final String? lastFollowUp;
  final String? lastTranscript;
  final bool isBusy;
  final bool isRecording;

  SessionUiState copyWith({
    String? sessionId,
    String? websocketChannel,
    String? connectionState,
    String? lastSummary,
    String? lastFollowUp,
    String? lastTranscript,
    bool? isBusy,
    bool? isRecording,
  }) {
    return SessionUiState(
      sessionId: sessionId ?? this.sessionId,
      websocketChannel: websocketChannel ?? this.websocketChannel,
      connectionState: connectionState ?? this.connectionState,
      lastSummary: lastSummary ?? this.lastSummary,
      lastFollowUp: lastFollowUp ?? this.lastFollowUp,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      isBusy: isBusy ?? this.isBusy,
      isRecording: isRecording ?? this.isRecording,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final microphoneServiceProvider =
    Provider<MicrophoneService>((ref) => MicrophoneService());

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionUiState>((ref) {
  return SessionController(
    ref.read(apiClientProvider),
    ref.read(microphoneServiceProvider),
  );
});

class SessionController extends StateNotifier<SessionUiState> {
  SessionController(this._apiClient, this._microphoneService)
      : super(const SessionUiState());

  final ApiClient _apiClient;
  final MicrophoneService _microphoneService;
  AppWebSocketClient? _webSocketClient;
  StreamSubscription? _subscription;

  Future<SessionStartResponseModel> ensureSession({required bool secureMode}) async {
    if (state.sessionId != null && state.websocketChannel != null) {
      return SessionStartResponseModel(
        sessionId: state.sessionId!,
        status: 'ready',
        websocketChannel: state.websocketChannel!,
      );
    }

    final response = await _apiClient.startSession({
      'client': 'flutter_windows',
      'trigger_source': 'manual',
      'mode': secureMode ? 'secure' : 'general',
      'locale': 'ko-KR',
      'accessibility': {
        'large_text': true,
        'screen_reader_enabled': true,
      },
    });

    await _connectWebSocket(response.websocketChannel);
    state = state.copyWith(
      sessionId: response.sessionId,
      websocketChannel: response.websocketChannel,
      connectionState: 'connected',
    );
    return response;
  }

  Future<CommandResponseModel> submitTextCommand({
    required String text,
    required bool secureMode,
  }) async {
    final session = await ensureSession(secureMode: secureMode);
    state = state.copyWith(isBusy: true);
    final response = await _apiClient.submitTextCommand({
      'session_id': session.sessionId,
      'text': text,
      'mode': secureMode ? 'secure' : 'general',
    });
    state = state.copyWith(
      isBusy: false,
      lastTranscript: response.transcript,
      lastSummary: response.summary,
      lastFollowUp: response.followUp,
    );
    return response;
  }

  Future<CommandResponseModel?> toggleVoiceCapture({
    required bool secureMode,
  }) async {
    final session = await ensureSession(secureMode: secureMode);

    if (!state.isRecording) {
      await _microphoneService.start();
      state = state.copyWith(isRecording: true);
      return null;
    }

    final clip = await _microphoneService.stop();
    state = state.copyWith(isRecording: false);
    if (clip == null) {
      return null;
    }

    state = state.copyWith(isBusy: true);
    final response = await _apiClient.submitVoiceCommand(
      audioFile: File(clip.filePath),
      metadata: {
        'session_id': session.sessionId,
        'audio_format': 'wav',
        'sample_rate_hz': 16000,
        'channels': 1,
        'duration_ms': clip.durationMs,
        'language_hint': 'ko',
        'trigger_source': 'manual',
        'mode': secureMode ? 'secure' : 'general',
      },
    );
    state = state.copyWith(
      isBusy: false,
      lastTranscript: response.transcript,
      lastSummary: response.summary,
      lastFollowUp: response.followUp,
    );
    return response;
  }

  Future<void> triggerScreenRead({required bool secureMode}) async {
    final session = await ensureSession(secureMode: secureMode);
    state = state.copyWith(isBusy: true);
    final response = await _apiClient.readScreen({
      'session_id': session.sessionId,
      'foreground_window_only': true,
      'detail_level': 'summary',
    });
    state = state.copyWith(
      isBusy: false,
      lastSummary: response.summary,
      lastFollowUp: '다른 화면도 읽어드릴까요?',
    );
  }

  Future<void> _connectWebSocket(String url) async {
    await _subscription?.cancel();
    _webSocketClient = AppWebSocketClient(url);
    _subscription = _webSocketClient!.channel.stream.listen((event) {
      Map<String, dynamic>? data;
      if (event is String) {
        data = jsonDecode(event) as Map<String, dynamic>;
      } else if (event is Map) {
        data = Map<String, dynamic>.from(event);
      }
      if (data == null) {
        return;
      }
      final type = data['type'] as String? ?? '';
      if (type == 'status') {
        state = state.copyWith(
          connectionState: data['state'] as String? ?? state.connectionState,
          isBusy: (data['state'] as String?) == 'processing',
        );
      } else if (type == 'transcript') {
        state = state.copyWith(lastTranscript: data['transcript'] as String?);
      } else if (type == 'completed') {
        state = state.copyWith(
          isBusy: false,
          lastSummary: data['summary'] as String?,
          lastFollowUp: data['follow_up'] as String?,
        );
      } else if (type == 'secure_warning') {
        state = state.copyWith(
          isBusy: false,
          lastSummary: data['summary'] as String?,
          lastFollowUp: data['follow_up'] as String?,
        );
      } else if (type == 'background_event') {
        final eventName = data['event'] as String? ?? '';
        if (eventName == 'START_LISTENING') {
          state = state.copyWith(connectionState: 'wake_requested');
        }
      }
    }, onError: (_) {
      state = state.copyWith(connectionState: 'error', isBusy: false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _webSocketClient?.channel.sink.close();
    super.dispose();
  }
}
