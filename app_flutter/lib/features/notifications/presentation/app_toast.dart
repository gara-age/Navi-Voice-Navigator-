import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/models/settings_models.dart';
import '../../../shared/services/taskbar_popup_service.dart';

void showAppToast(
  BuildContext context,
  String message, {
  String title = 'Navi: Voice Navigator',
  TaskbarPopupState? state,
  DisplaySettings? displaySettings,
  int durationMs = 5000,
}) {
  unawaited(
    _showTaskbarPopupOrFallback(
      context,
      title: title,
      message: message,
      state: state ?? _inferPopupState(title, message),
      displaySettings: displaySettings,
      durationMs: durationMs,
    ),
  );
}

void showDetailedPopup(
  BuildContext context, {
  required String title,
  required String message,
  TaskbarPopupState? state,
  DisplaySettings? displaySettings,
  int durationMs = 5000,
}) {
  unawaited(
    _showTaskbarPopupOrFallback(
      context,
      title: title,
      message: message,
      state: state ?? _inferPopupState(title, message),
      displaySettings: displaySettings,
      durationMs: durationMs,
    ),
  );
}

Future<void> _showTaskbarPopupOrFallback(
  BuildContext context, {
  required String title,
  required String message,
  required TaskbarPopupState state,
  DisplaySettings? displaySettings,
  required int durationMs,
}) async {
  final theme = Theme.of(context);
  final surfaceTheme = theme.extension<AppSurfaceTheme>();
  final themeMode = displaySettings == null
      ? _resolveThemeMode(theme, surfaceTheme)
      : _resolveThemeModeFromDisplay(displaySettings);
  final largeText = displaySettings?.largeText ??
      (MediaQuery.of(context).textScaler.scale(14) / 14 > 1.08);
  final normalizedMessage = _normalizePopupMessage(title, message);

  final shown = await TaskbarPopupService.instance.show(
    title: title,
    message: normalizedMessage,
    durationMs: durationMs,
    state: state,
    themeMode: themeMode,
    largeText: largeText,
  );

  if (!shown && !Platform.isWindows && context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$title\n$normalizedMessage'),
          duration: Duration(milliseconds: durationMs),
        ),
      );
  }
}

TaskbarPopupThemeMode _resolveThemeModeFromDisplay(DisplaySettings display) {
  if (display.highContrast) {
    return TaskbarPopupThemeMode.contrast;
  }
  if (display.darkTheme) {
    return TaskbarPopupThemeMode.dark;
  }
  return TaskbarPopupThemeMode.light;
}

TaskbarPopupThemeMode _resolveThemeMode(
  ThemeData theme,
  AppSurfaceTheme? surfaceTheme,
) {
  final accent = surfaceTheme?.accent ?? theme.colorScheme.primary;
  final surface = surfaceTheme?.surface ?? theme.colorScheme.surface;

  final isHighContrast =
      accent.toARGB32() == const Color(0xFFFFFF00).toARGB32();
  if (isHighContrast) {
    return TaskbarPopupThemeMode.contrast;
  }

  final isDark =
      theme.brightness == Brightness.dark || surface.computeLuminance() < 0.18;
  return isDark ? TaskbarPopupThemeMode.dark : TaskbarPopupThemeMode.light;
}

String _normalizePopupMessage(String title, String message) {
  final source = _normalize('$title $message');

  if (source.contains('화면 읽기') || source.contains('screen read')) {
    return '화면을 읽어드립니다.';
  }

  if (_looksLikeStructuredResult(message) ||
      source.contains('결과 요약') ||
      source.contains('후속 질문') ||
      source.contains('응답 결과') ||
      source.contains('시나리오')) {
    return '결과를 읽어드립니다.';
  }

  return message.trim();
}

bool _looksLikeStructuredResult(String message) {
  final normalized = _normalize(message);
  return message.contains('\n') ||
      normalized.contains('인식 문장') ||
      normalized.contains('결과 요약') ||
      normalized.contains('후속 질문') ||
      normalized.contains('summary') ||
      normalized.contains('follow up');
}

TaskbarPopupState _inferPopupState(String title, String message) {
  final source = _normalize('$title $message');

  if (source.contains('다크 테마') || source.contains('dark theme')) {
    return TaskbarPopupState.themeDark;
  }
  if (source.contains('고대비') || source.contains('high contrast')) {
    return TaskbarPopupState.themeContrast;
  }
  if (source.contains('큰 글씨') || source.contains('large text')) {
    return TaskbarPopupState.themeLargeText;
  }
  if (source.contains('보안') || source.contains('secure')) {
    return TaskbarPopupState.secure;
  }
  if (source.contains('어플리케이션 오류') ||
      source.contains('애플리케이션 오류') ||
      source.contains('application error')) {
    return TaskbarPopupState.appError;
  }
  if (source.contains('명령 인식 실패') ||
      source.contains('인식 실패') ||
      source.contains('failure')) {
    return TaskbarPopupState.error;
  }
  if (source.contains('서버 응답 지연') ||
      source.contains('응답 지연') ||
      source.contains('timeout')) {
    return TaskbarPopupState.warning;
  }
  if (source.contains('재시도') || source.contains('retry')) {
    return TaskbarPopupState.retry;
  }
  if (source.contains('처리 중') ||
      source.contains('작업 처리') ||
      source.contains('processing')) {
    return TaskbarPopupState.processing;
  }
  if (source.contains('음성 수신') ||
      source.contains('듣는 중') ||
      source.contains('listening') ||
      source.contains('listen')) {
    return TaskbarPopupState.listening;
  }
  if (source.contains('작업 완료') ||
      source.contains('성공') ||
      source.contains('완료') ||
      source.contains('결과를 읽어드립니다') ||
      source.contains('result') ||
      source.contains('summary') ||
      source.contains('scenario') ||
      _looksLikeStructuredResult(message)) {
    return TaskbarPopupState.success;
  }

  return TaskbarPopupState.info;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll(':', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
