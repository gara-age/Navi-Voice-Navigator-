import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../shared/services/local_background_event_service.dart';
import '../../../../shared/services/local_ui_state_service.dart';
import '../../../../shared/services/taskbar_popup_service.dart';
import '../../../../shared/utils/shortcut_utils.dart';
import '../../listening/application/listening_controller.dart';
import '../../notifications/presentation/app_toast.dart';
import '../../session/application/session_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_modal.dart';
import 'widgets/action_panel.dart';
import 'widgets/ready_state.dart';
import 'widgets/status_card.dart';
import 'widgets/title_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'home_page_focus');
  bool _showSettingsModal = false;
  Timer? _backgroundEventTimer;
  bool _handlingBackgroundEvent = false;

  @override
  void initState() {
    super.initState();
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
      final shortcuts = ref.read(settingsControllerProvider).shortcuts;
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _closeSettings();
        return true;
      }
      if (ShortcutUtils.matches(event, shortcuts.listenToggle) ||
          ShortcutUtils.matches(event, shortcuts.screenRead) ||
          ShortcutUtils.matches(event, shortcuts.openSettings)) {
        return true;
      }
      return false;
    }

    final shortcuts = ref.read(settingsControllerProvider).shortcuts;
    if (!shortcuts.enabled) {
      return false;
    }
    if (ShortcutUtils.matches(event, shortcuts.listenToggle)) {
      unawaited(_triggerListen());
      return true;
    }

    if (ShortcutUtils.matches(event, shortcuts.screenRead)) {
      unawaited(_triggerScreenRead());
      return true;
    }

    if (ShortcutUtils.matches(event, shortcuts.openSettings)) {
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

  Future<void> _triggerListen() async {
    final sessionState = ref.read(sessionControllerProvider);
    final settings = ref.read(settingsControllerProvider);
    final sessionController = ref.read(sessionControllerProvider.notifier);
    final listeningController = ref.read(listeningControllerProvider.notifier);

    if (!sessionState.isRecording) {
      listeningController.startListening();
      await sessionController.toggleVoiceCapture(
        secureMode: settings.security.secureInputMode,
      );
      if (mounted) {
        showAppToast(
          context,
          '음성을 듣고 있습니다. 말씀해주세요.',
          title: '음성 수신 중',
          state: TaskbarPopupState.listening,
          displaySettings: settings.display,
        );
      }
      return;
    }

    listeningController.setProcessing();
    if (mounted) {
      showAppToast(
        context,
        '작업을 처리하고 있습니다.',
        title: '작업 처리 중',
        state: TaskbarPopupState.processing,
        displaySettings: settings.display,
      );
    }

    final response = await sessionController.toggleVoiceCapture(
      secureMode: settings.security.secureInputMode,
    );
    listeningController.reset();

    if (response != null && mounted) {
      showAppToast(
        context,
        '결과를 읽어드립니다.',
        title: '작업 완료',
        state: TaskbarPopupState.success,
        displaySettings: settings.display,
      );
    }
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
          await _triggerListen();
          break;
        case 'START_SCREEN_READ':
          await _triggerScreenRead();
          break;
        case 'OPEN_SETTINGS':
          _openSettings();
          break;
      }
    } finally {
      _handlingBackgroundEvent = false;
    }
  }

  Future<void> _triggerScreenRead() async {
    final settings = ref.read(settingsControllerProvider);
    ref.read(listeningControllerProvider.notifier).setProcessing();
    showAppToast(
      context,
      '화면을 읽어드립니다.',
      title: '작업 처리 중',
      state: TaskbarPopupState.processing,
      displaySettings: settings.display,
    );

    await ref.read(sessionControllerProvider.notifier).triggerScreenRead(
          secureMode: settings.security.secureInputMode,
        );

    final sessionState = ref.read(sessionControllerProvider);
    ref.read(listeningControllerProvider.notifier).reset();
    if (mounted && sessionState.lastSummary != null) {
      showAppToast(
        context,
        '화면을 읽어드립니다.',
        title: '작업 완료',
        state: TaskbarPopupState.success,
        displaySettings: settings.display,
      );
    }
  }

  String _micLabel(ListeningState listeningState) {
    switch (listeningState.status) {
      case ListeningStatus.idle:
        return '대기';
      case ListeningStatus.listening:
        return '듣는 중';
      case ListeningStatus.processing:
        return '처리중';
    }
  }

  @override
  Widget build(BuildContext context) {
    final listeningState = ref.watch(listeningControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final display = settings.display;
    final themedData = buildAppTheme(display: display);
    final mediaQuery = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(display.largeText ? 1.32 : 1.0),
    );
    final surfaceTheme = themedData.extension<AppSurfaceTheme>()!;
    final micLabel = _micLabel(listeningState);

    return Theme(
      data: themedData,
      child: MediaQuery(
        data: mediaQuery,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceTheme.contentBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 60,
                            offset: Offset(0, 20),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
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
                                    value: micLabel,
                                    icon: Icons.mic_none_rounded,
                                    iconBackground: micLabel == '대기'
                                        ? AppColors.surfaceMuted
                                        : micLabel == '처리중'
                                            ? AppColors.accentSoft
                                            : AppColors.successSoft,
                                    iconColor: micLabel == '대기'
                                        ? AppColors.iconMuted
                                        : micLabel == '처리중'
                                            ? AppColors.accent
                                            : AppColors.success,
                                    showWave: true,
                                  ),
                                ),
                                Container(width: 1, color: surfaceTheme.border),
                                Expanded(
                                  child: StatusCard(
                                    label: '현재 모드',
                                    value: settings.security.secureInputMode
                                        ? '보안 입력 모드'
                                        : '일반 모드',
                                    icon: settings.security.secureInputMode
                                        ? Icons.lock_outline_rounded
                                        : Icons.volume_up_outlined,
                                    iconBackground: settings.security.secureInputMode
                                        ? AppColors.warningSoft
                                        : AppColors.accentSoft,
                                    iconColor: settings.security.secureInputMode
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
                                          settings.security.secureInputMode,
                                      isRecording: sessionState.isRecording,
                                      listenShortcut: settings.shortcuts.listenToggle,
                                      screenReadShortcut: settings.shortcuts.screenRead,
                                      settingsShortcut: settings.shortcuts.openSettings,
                                      onListenPressed: () => unawaited(_triggerListen()),
                                      onScreenReadPressed:
                                          () => unawaited(_triggerScreenRead()),
                                      onSettingsPressed: _openSettings,
                                      onToggleMode: (value) {
                                        ref
                                            .read(settingsControllerProvider.notifier)
                                            .setSecureMode(value);
                                        showAppToast(
                                          context,
                                          value
                                              ? '보안 입력 모드가 활성화되었습니다.'
                                              : '일반 모드로 전환되었습니다.',
                                          title: '모드 변경',
                                          state: value
                                              ? TaskbarPopupState.secure
                                              : TaskbarPopupState.success,
                                          displaySettings: settings.display,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ReadyState(
                                    summary: sessionState.lastSummary,
                                    followUp: sessionState.lastFollowUp,
                                    isBusy: sessionState.isBusy,
                                    onSubmitText: (text) async {
                                      ref
                                          .read(listeningControllerProvider.notifier)
                                          .setProcessing();
                                      showAppToast(
                                        context,
                                        '작업을 처리하고 있습니다.',
                                        title: '작업 처리 중',
                                        state: TaskbarPopupState.processing,
                                        displaySettings: settings.display,
                                      );
                                      await ref
                                          .read(sessionControllerProvider.notifier)
                                          .submitTextCommand(
                                            text: text,
                                            secureMode:
                                                settings.security.secureInputMode,
                                          );
                                      ref
                                          .read(listeningControllerProvider.notifier)
                                          .reset();
                                      if (!context.mounted) {
                                        return;
                                      }
                                      showAppToast(
                                        context,
                                        '결과를 읽어드립니다.',
                                        title: '작업 완료',
                                        state: TaskbarPopupState.success,
                                        displaySettings: settings.display,
                                      );
                                    },
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
                        child: SettingsModal(
                          onClose: _closeSettings,
                          onSaved: (saved) {
                            _closeSettings();
                            if (saved) {
                              showAppToast(
                                context,
                                '설정이 저장되었습니다.',
                                title: '작업 완료',
                                state: TaskbarPopupState.success,
                                displaySettings: settings.display,
                              );
                            }
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
      ),
    );
  }
}
