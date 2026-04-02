import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/colors.dart';
import '../features/home/presentation/widgets/action_panel.dart';
import '../features/home/presentation/widgets/ready_state.dart';
import '../features/home/presentation/widgets/status_card.dart';
import '../features/home/presentation/widgets/title_bar.dart';
import '../features/notifications/presentation/app_toast.dart';
import '../shared/models/settings_models.dart';
import '../shared/services/local_background_event_service.dart';
import '../shared/services/local_ui_state_service.dart';
import '../shared/services/taskbar_popup_service.dart';
import '../shared/utils/shortcut_utils.dart';
import 'demo_settings_modal.dart';

enum DemoScenario {
  youtube,
  naverMap,
  secureInput,
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({
    super.key,
    this.initialSettings,
    this.onSettingsChanged,
    this.onSettingsSaved,
  });

  final AppSettings? initialSettings;
  final ValueChanged<AppSettings>? onSettingsChanged;
  final ValueChanged<AppSettings>? onSettingsSaved;

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'demo_home_focus');

  late AppSettings _settings;
  String _micStatus = '대기';
  bool _isRecording = false;
  bool _isBusy = false;
  bool _showSettingsModal = false;
  String? _summary;
  String? _followUp;
  Timer? _backgroundEventTimer;
  bool _handlingBackgroundEvent = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings ?? AppSettings.defaults();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
    _backgroundEventTimer = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) => _pollBackgroundEvent(),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _backgroundEventTimer?.cancel();
    unawaited(LocalUiStateService.instance.setSettingsModalOpen(false));
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) {
      return false;
    }

    if (_showSettingsModal) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _closeSettings();
        return true;
      }
      if (ShortcutUtils.matches(event, _settings.shortcuts.listenToggle) ||
          ShortcutUtils.matches(event, _settings.shortcuts.screenRead) ||
          ShortcutUtils.matches(event, _settings.shortcuts.openSettings)) {
        return true;
      }
      return false;
    }

    if (!_settings.shortcuts.enabled) {
      return false;
    }

    if (ShortcutUtils.matches(event, _settings.shortcuts.listenToggle)) {
      unawaited(_simulateListen());
      return true;
    }

    if (ShortcutUtils.matches(event, _settings.shortcuts.screenRead)) {
      unawaited(_simulateScreenRead());
      return true;
    }

    if (ShortcutUtils.matches(event, _settings.shortcuts.openSettings)) {
      _openSettings();
      return true;
    }

    return false;
  }

  void _openSettings() {
    if (_showSettingsModal) {
      return;
    }
    setState(() => _showSettingsModal = true);
    unawaited(LocalUiStateService.instance.setSettingsModalOpen(true));
  }

  void _closeSettings() {
    if (!_showSettingsModal) {
      return;
    }
    setState(() => _showSettingsModal = false);
    unawaited(LocalUiStateService.instance.setSettingsModalOpen(false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _simulateListen() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _isRecording = true;
      _micStatus = '듣는 중';
      _summary = '음성을 듣고 있습니다. 잠시 후 자동으로 처리 단계로 넘어갑니다.';
      _followUp = null;
    });
    showAppToast(
      context,
      '음성을 듣고 있습니다. 말씀해주세요.',
      title: '음성 수신 중',
      state: TaskbarPopupState.listening,
      displaySettings: _settings.display,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) {
      return;
    }

    setState(() {
      _micStatus = '처리중';
      _isRecording = false;
      _summary = '명령을 분석하고 실행 계획을 준비하고 있습니다.';
    });
    showAppToast(
      context,
      '작업을 처리하고 있습니다.',
      title: '작업 처리 중',
      state: TaskbarPopupState.processing,
      displaySettings: _settings.display,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) {
      return;
    }

    final result = _scenarioResult(DemoScenario.youtube);
    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary = result.summary;
      _followUp = result.followUp;
    });

    showAppToast(
      context,
      '결과를 읽어드립니다.',
      title: '작업 완료',
      state: TaskbarPopupState.success,
      displaySettings: _settings.display,
    );
  }

  Future<void> _simulateScreenRead() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _micStatus = '처리중';
      _summary = '화면을 읽어드립니다.';
      _followUp = null;
    });
    showAppToast(
      context,
      '화면을 읽어드립니다.',
      title: '작업 처리 중',
      state: TaskbarPopupState.processing,
      displaySettings: _settings.display,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary =
          '현재 화면은 Navi: Voice Navigator 데모 화면입니다. 왼쪽에는 주요 기능 버튼이 있고 가운데에는 준비 상태와 결과 요약이 표시됩니다.';
      _followUp = '다른 화면도 읽어드릴까요?';
    });

    showAppToast(
      context,
      '화면을 읽어드립니다.',
      title: '작업 완료',
      state: TaskbarPopupState.success,
      displaySettings: _settings.display,
    );
  }

  Future<void> _handleTextCommand(String text) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _micStatus = '처리중';
      _summary = '텍스트 명령을 처리하고 있습니다.';
      _followUp = null;
    });
    showAppToast(
      context,
      '작업을 처리하고 있습니다.',
      title: '작업 처리 중',
      state: TaskbarPopupState.processing,
      displaySettings: _settings.display,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) {
      return;
    }

    final result = _buildDemoResponse(text);
    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary = result.summary;
      _followUp = result.followUp;
    });

    showAppToast(
      context,
      '결과를 읽어드립니다.',
      title: '작업 완료',
      state: TaskbarPopupState.success,
      displaySettings: _settings.display,
    );
  }

  Future<void> _pollBackgroundEvent() async {
    if (!mounted || _handlingBackgroundEvent) {
      return;
    }

    _handlingBackgroundEvent = true;
    try {
      final event = await LocalBackgroundEventService.instance.pollEvent();
      if (!mounted || event == null) {
        return;
      }

      switch (event) {
        case 'START_LISTENING':
          await _simulateListen();
          break;
        case 'START_SCREEN_READ':
          await _simulateScreenRead();
          break;
        case 'OPEN_SETTINGS':
          _openSettings();
          break;
      }
    } finally {
      _handlingBackgroundEvent = false;
    }
  }

  _ScenarioResult _buildDemoResponse(String text) {
    final normalized = text.toLowerCase();

    if (normalized.contains('youtube') || normalized.contains('유튜브')) {
      return _scenarioResult(DemoScenario.youtube);
    }
    if (normalized.contains('naver') ||
        normalized.contains('지도') ||
        normalized.contains('경로')) {
      return _scenarioResult(DemoScenario.naverMap);
    }
    if (normalized.contains('보안') ||
        normalized.contains('비밀번호') ||
        normalized.contains('otp') ||
        normalized.contains('password')) {
      return _scenarioResult(DemoScenario.secureInput);
    }

    return _scenarioResult(DemoScenario.youtube);
  }

  _ScenarioResult _scenarioResult(DemoScenario scenario) {
    switch (scenario) {
      case DemoScenario.youtube:
        return const _ScenarioResult(
          summary:
              '유튜브 검색 결과를 찾았습니다. 첫 번째 영상은 귀여운 고양이 놀이 모음입니다.',
          followUp: '첫 번째 영상을 재생할까요?',
        );
      case DemoScenario.naverMap:
        return const _ScenarioResult(
          summary:
              '서울역에서 한국폴리텍대학 인천캠퍼스까지 가는 지하철 경로를 찾았습니다. 환승 1회 기준 예상 소요 시간은 약 1시간 18분입니다.',
          followUp: '경로를 안내할까요?',
        );
      case DemoScenario.secureInput:
        return const _ScenarioResult(
          summary:
              '보안 입력 모드가 필요합니다. 비밀번호나 인증번호는 자동 입력하거나 음성으로 읽어드리지 않습니다.',
          followUp: '보안 입력 모드로 전환할까요?',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = _settings.display;
    final themedData = buildAppTheme(display: display);
    final mediaQuery = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(display.largeText ? 1.32 : 1.0),
    );
    final surfaceTheme = themedData.extension<AppSurfaceTheme>()!;

    return Theme(
      data: themedData,
      child: MediaQuery(
        data: mediaQuery,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            backgroundColor: surfaceTheme.surface,
            body: SafeArea(
              child: Stack(
                children: [
                  Container(
                    color: surfaceTheme.surface,
                    clipBehavior: Clip.none,
                      child: Column(
                        children: [
                          const AppTitleBar(),
                          Container(
                            height: 88,
                            decoration: BoxDecoration(
                              color: surfaceTheme.surface,
                              border: Border(
                                bottom: BorderSide(color: surfaceTheme.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: StatusCard(
                                    label: '마이크 상태',
                                    value: _micStatus,
                                    icon: Icons.mic_none_rounded,
                                    iconBackground: _micStatus == '대기'
                                        ? AppColors.surfaceMuted
                                        : _micStatus == '처리중'
                                            ? AppColors.accentSoft
                                            : AppColors.successSoft,
                                    iconColor: _micStatus == '대기'
                                        ? AppColors.iconMuted
                                        : _micStatus == '처리중'
                                            ? AppColors.accent
                                            : AppColors.success,
                                    showWave: true,
                                  ),
                                ),
                                Container(width: 1, color: surfaceTheme.border),
                                Expanded(
                                  child: StatusCard(
                                    label: '현재 모드',
                                    value: _settings.security.secureInputMode
                                        ? '보안 입력 모드'
                                        : '일반 모드',
                                    icon: _settings.security.secureInputMode
                                        ? Icons.lock_outline_rounded
                                        : Icons.volume_up_outlined,
                                    iconBackground: _settings.security.secureInputMode
                                        ? AppColors.warningSoft
                                        : AppColors.accentSoft,
                                    iconColor: _settings.security.secureInputMode
                                        ? AppColors.warning
                                        : AppColors.accent,
                                    showDot: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: surfaceTheme.surface,
                                      border: Border(
                                        right: BorderSide(color: surfaceTheme.border),
                                      ),
                                    ),
                                    child: ActionPanel(
                                      secureModeEnabled:
                                          _settings.security.secureInputMode,
                                      isRecording: _isRecording,
                                      listenShortcut: _settings.shortcuts.listenToggle,
                                      screenReadShortcut: _settings.shortcuts.screenRead,
                                      settingsShortcut: _settings.shortcuts.openSettings,
                                      onListenPressed: _simulateListen,
                                      onScreenReadPressed: _simulateScreenRead,
                                      onSettingsPressed: _openSettings,
                                      onToggleMode: (value) {
                                        setState(() {
                                          _settings = _settings.copyWith(
                                            security: _settings.security.copyWith(
                                              secureInputMode: value,
                                            ),
                                          );
                                        });
                                        widget.onSettingsChanged?.call(_settings);
                                        showAppToast(
                                          context,
                                          value
                                              ? '보안 입력 모드가 활성화되었습니다.'
                                              : '일반 모드로 전환되었습니다.',
                                          title: '모드 변경',
                                          state: value
                                              ? TaskbarPopupState.secure
                                              : TaskbarPopupState.success,
                                          displaySettings: _settings.display,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ReadyState(
                                    summary: _summary,
                                    followUp: _followUp,
                                    isBusy: _isBusy,
                                    onSubmitText: _handleTextCommand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ),
                  if (_showSettingsModal) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _closeSettings,
                          child: Container(color: const Color(0x66000000)),
                        ),
                      ),
                      Positioned.fill(
                        child: DemoSettingsModal(
                          initialSettings: _settings,
                          onClose: _closeSettings,
                          onChanged: (updated) {
                            setState(() => _settings = updated);
                            widget.onSettingsChanged?.call(updated);
                          },
                          onSaved: (updated) {
                            setState(() => _settings = updated);
                            widget.onSettingsChanged?.call(updated);
                            widget.onSettingsSaved?.call(updated);
                            _closeSettings();
                            showAppToast(
                              context,
                              '설정이 저장되었습니다.',
                              title: '작업 완료',
                              state: TaskbarPopupState.success,
                              displaySettings: _settings.display,
                            );
                          },
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioResult {
  const _ScenarioResult({
    required this.summary,
    required this.followUp,
  });

  final String summary;
  final String? followUp;
}
