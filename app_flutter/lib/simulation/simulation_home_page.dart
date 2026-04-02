import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/colors.dart';
import '../features/home/presentation/widgets/status_card.dart';
import '../features/home/presentation/widgets/title_bar.dart';
import '../features/notifications/presentation/app_toast.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/settings_modal.dart';
import '../shared/services/local_ui_state_service.dart';
import '../shared/services/taskbar_popup_service.dart';
import '../shared/utils/shortcut_utils.dart';
import 'services/simulation_runner_service.dart';

enum SimulationScenario { naverMap, memo, windowsTheme }

class SimulationHomePage extends ConsumerStatefulWidget {
  const SimulationHomePage({super.key});

  @override
  ConsumerState<SimulationHomePage> createState() => _SimulationHomePageState();
}

class _SimulationHomePageState extends ConsumerState<SimulationHomePage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'simulation_home_focus');
  final ScrollController _stepScrollController = ScrollController();

  bool _isRunning = false;
  bool _showSettingsModal = false;
  String _statusLabel = '대기';
  String _summary = '실행할 시나리오를 선택해주세요.';
  String _debugLog = '';
  List<Map<String, dynamic>> _steps = const [];
  SimulationScenario _selectedScenario = SimulationScenario.naverMap;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _stepScrollController.dispose();
    unawaited(LocalUiStateService.instance.setSettingsModalOpen(false));
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) {
      return false;
    }

    final shortcuts = ref.read(settingsControllerProvider).shortcuts;
    if (_showSettingsModal) {
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

    if (!shortcuts.enabled) {
      return false;
    }

    if (ShortcutUtils.matches(event, shortcuts.listenToggle)) {
      unawaited(_runScenario(_selectedScenario));
      return true;
    }

    if (ShortcutUtils.matches(event, shortcuts.screenRead)) {
      _copyLogs();
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

  Future<void> _copyLogs() async {
    if (_debugLog.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _debugLog));
    if (!mounted) {
      return;
    }
    final settings = ref.read(settingsControllerProvider);
    showAppToast(
      context,
      '실행 로그를 클립보드에 복사했습니다.',
      title: '작업 완료',
      state: TaskbarPopupState.success,
      displaySettings: settings.display,
    );
  }

  Future<void> _runScenario(SimulationScenario scenario) async {
    if (_isRunning) {
      return;
    }

    final settings = ref.read(settingsControllerProvider);
    final scenarioLabel = _scenarioLabel(scenario);
    setState(() {
      _selectedScenario = scenario;
      _isRunning = true;
      _statusLabel = '실행 중';
      _summary = _scenarioStartSummary(scenario);
      _debugLog = '';
      _steps = const [];
    });

    showAppToast(
      context,
      '$scenarioLabel 시나리오를 시작합니다.',
      title: '작업 처리 중',
      state: TaskbarPopupState.processing,
      displaySettings: settings.display,
    );

    final result = await _runSelectedScenario(
      scenario,
      onProgress: (event) {
        if (!mounted) {
          return;
        }
        setState(() {
          _statusLabel = '실행 중';
          _summary = event.detail;
          _steps = _upsertStep(_steps, event.toStepMap());
          _debugLog = [
            _debugLog.trimRight(),
            '[step ${event.step}] ${event.action}: ${event.detail}',
          ].where((line) => line.isNotEmpty).join('\n');
        });
        showDetailedPopup(
          context,
          title: '단계 ${event.step} 진행',
          message: event.detail,
          state: _popupStateFromName(event.popupState),
          displaySettings: settings.display,
          durationMs: 2600,
        );
        _scrollToBottom();
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isRunning = false;
      _statusLabel = result.success ? '완료' : '오류';
      _summary = result.summary;
      _steps = result.steps;
      final stdout = (result.raw['stdout'] as String?)?.trim();
      final stderr = (result.raw['stderr'] as String?)?.trim();
      _debugLog = <String>[
        _debugLog.trim(),
        if (stdout != null && stdout.isNotEmpty) stdout,
        if (stderr != null && stderr.isNotEmpty) stderr,
      ].where((line) => line.isNotEmpty).join('\n');
    });

    if (result.success) {
      showDetailedPopup(
        context,
        title: _buildSuccessPopupTitle(result),
        message: _buildSuccessPopupMessage(result),
        state: _successPopupState(result),
        displaySettings: settings.display,
        durationMs: 5200,
      );
    } else {
      showDetailedPopup(
        context,
        title: '애플리케이션 오류',
        message: result.error?.trim().isNotEmpty == true
            ? result.error!.trim()
            : result.summary,
        state: TaskbarPopupState.appError,
        displaySettings: settings.display,
        durationMs: 5200,
      );
    }
  }

  Future<SimulationRunnerResult> _runSelectedScenario(
    SimulationScenario scenario, {
    void Function(SimulationProgressEvent event)? onProgress,
  }) {
    switch (scenario) {
      case SimulationScenario.naverMap:
        return SimulationRunnerService.instance.runNaverMapScenario(
          onProgress: onProgress,
        );
      case SimulationScenario.memo:
        return SimulationRunnerService.instance.runMemoScenario(
          onProgress: onProgress,
        );
      case SimulationScenario.windowsTheme:
        return SimulationRunnerService.instance.runWindowsThemeScenario(
          onProgress: onProgress,
        );
    }
  }

  String _scenarioLabel(SimulationScenario scenario) {
    switch (scenario) {
      case SimulationScenario.naverMap:
        return '네이버 지도';
      case SimulationScenario.memo:
        return '메모장';
      case SimulationScenario.windowsTheme:
        return 'Windows 테마 변경';
    }
  }

  String _scenarioStatusLabel(SimulationScenario scenario) {
    switch (scenario) {
      case SimulationScenario.naverMap:
        return '네이버 지도 지하철 경로';
      case SimulationScenario.memo:
        return '메모장 일기 저장';
      case SimulationScenario.windowsTheme:
        return 'Windows 라이트 → 다크';
    }
  }

  String _scenarioStartSummary(SimulationScenario scenario) {
    switch (scenario) {
      case SimulationScenario.naverMap:
        return '네이버 지도에서 지하철 경로를 조회하는 중입니다.';
      case SimulationScenario.memo:
        return '메모장에 일기 내용을 입력하고 저장하는 중입니다.';
      case SimulationScenario.windowsTheme:
        return 'Windows 설정에서 화면 테마를 다크 모드로 변경하는 중입니다.';
    }
  }

  String _buildSuccessPopupTitle(SimulationRunnerResult result) {
    switch (result.raw['scenario']) {
      case 'memo_notepad':
        return '메모장 시나리오가 완료되었습니다.';
      case 'windows_theme_dark':
      case 'windows_theme_toggle':
        final targetMode = (result.raw['target_mode'] as String?)?.trim();
        if (targetMode == 'light') {
          return 'Windows 라이트 테마로 변경했습니다.';
        }
        return 'Windows 다크 테마로 변경했습니다.';
    }
    final count = result.raw['result_count'];
    if (count is int && count > 0) {
      return '$count건의 결과가 조회되었습니다.';
    }
    if (count is String && count.trim().isNotEmpty) {
      return '${count.trim()}건의 결과가 조회되었습니다.';
    }
    return '시나리오가 완료되었습니다.';
  }
  String _buildSuccessPopupMessage(SimulationRunnerResult result) {
    switch (result.raw['scenario']) {
      case 'memo_notepad':
        final fileName = (result.raw['file_name'] as String?)?.trim();
        if (fileName != null && fileName.isNotEmpty) {
          return '$fileName 이름으로 저장했습니다.';
        }
        return '메모장 파일 저장을 완료했습니다.';
      case 'windows_theme_dark':
      case 'windows_theme_toggle':
        final targetMode = (result.raw['target_mode'] as String?)?.trim();
        if (targetMode == 'light') {
          return 'Windows 화면 모드를 라이트 테마로 변경했습니다.';
        }
        return 'Windows 화면 모드를 다크 테마로 변경했습니다.';
    }
    final duration = (result.raw['duration_text'] as String?)?.trim();
    if (duration != null && duration.isNotEmpty) {
      return '$duration 소요되는 경로로 안내할까요?';
    }
    final routeSummary = (result.raw['route_summary'] as String?)?.trim() ?? '';
    final fallbackDuration = _extractDurationFromText(routeSummary);
    if (fallbackDuration != null && fallbackDuration.isNotEmpty) {
      return '$fallbackDuration 소요되는 경로로 안내할까요?';
    }
    return '결과를 읽어드립니다.';
  }
  TaskbarPopupState _successPopupState(SimulationRunnerResult result) {
    if (result.raw['scenario'] == 'windows_theme_dark' ||
        result.raw['scenario'] == 'windows_theme_toggle') {
      return TaskbarPopupState.themeDark;
    }
    return TaskbarPopupState.success;
  }
  String? _extractDurationFromText(String source) {
    if (source.isEmpty) {
      return null;
    }

    final normalized = source.replaceAll('\n', ' ');
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(normalized);
    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(normalized);

    if (hourMatch != null && minuteMatch != null) {
      return '${hourMatch.group(1)}시간 ${minuteMatch.group(1)}분';
    }
    if (hourMatch != null) {
      return '${hourMatch.group(1)}시간';
    }
    if (minuteMatch != null) {
      return '${minuteMatch.group(1)}분';
    }
    return null;
  }

  TaskbarPopupState _popupStateFromName(String name) {
    switch (name) {
      case 'listening':
        return TaskbarPopupState.listening;
      case 'success':
        return TaskbarPopupState.success;
      case 'retry':
        return TaskbarPopupState.retry;
      case 'warning':
        return TaskbarPopupState.warning;
      case 'error':
        return TaskbarPopupState.error;
      case 'appError':
        return TaskbarPopupState.appError;
      case 'secure':
        return TaskbarPopupState.secure;
      case 'themeDark':
        return TaskbarPopupState.themeDark;
      default:
        return TaskbarPopupState.processing;
    }
  }

  List<Map<String, dynamic>> _upsertStep(
    List<Map<String, dynamic>> current,
    Map<String, dynamic> next,
  ) {
    final items = [...current];
    final index = items.indexWhere((item) => item['step'] == next['step']);
    if (index == -1) {
      items.add(next);
    } else {
      items[index] = next;
    }
    return items;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stepScrollController.hasClients) {
        return;
      }
      _stepScrollController.animateTo(
        _stepScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildEmptyStepCard(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceTheme.border),
      ),
      child: Text(
        '아직 실행된 단계가 없습니다.',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          color: surfaceTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    final status = (step['status'] as String? ?? 'pending').toLowerCase();
    final isError = status == 'error';
    final accent = isError ? AppColors.error : AppColors.accent;
    final background =
        isError ? AppColors.errorSoft : surfaceTheme.contentBackground;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? const Color(0x66EF4444) : surfaceTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isError ? const Color(0xFFFFE4E6) : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              '${step['step'] ?? '-'}',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  (step['action'] as String? ?? 'step'),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  (step['detail'] as String? ?? '').trim(),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    height: 1.6,
                    color: surfaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        backgroundColor: surfaceTheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const AppTitleBar(),
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: surfaceTheme.surface,
                      border: Border(
                        top: BorderSide(color: surfaceTheme.border),
                        bottom: BorderSide(color: surfaceTheme.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatusCard(
                            label: '시뮬레이션 상태',
                            value: _statusLabel,
                            icon: Icons.auto_awesome_motion_rounded,
                            iconBackground: AppColors.successSoft,
                            iconColor: AppColors.success,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: surfaceTheme.border,
                        ),
                        Expanded(
                          child: StatusCard(
                            label: '현재 시나리오',
                            value: _scenarioStatusLabel(_selectedScenario),
                            icon: switch (_selectedScenario) {
                              SimulationScenario.naverMap =>
                                Icons.train_rounded,
                              SimulationScenario.memo => Icons.note_alt_rounded,
                              SimulationScenario.windowsTheme =>
                                Icons.dark_mode_rounded,
                            },
                            iconBackground: switch (_selectedScenario) {
                              SimulationScenario.naverMap =>
                                AppColors.accentSoft,
                              SimulationScenario.memo => AppColors.warningSoft,
                              SimulationScenario.windowsTheme =>
                                const Color(0xFFEDE9FE),
                            },
                            iconColor: switch (_selectedScenario) {
                              SimulationScenario.naverMap => AppColors.accent,
                              SimulationScenario.memo => AppColors.warning,
                              SimulationScenario.windowsTheme =>
                                const Color(0xFF7C3AED),
                            },
                            showDot: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 310,
                          color: surfaceTheme.surface,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '시뮬레이션 시나리오',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: surfaceTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SimulationActionButton(
                                icon: Icons.route_rounded,
                                title: '네이버 지도 시나리오',
                                description:
                                    '네이버 지도에서 지하철 경로를 조회하는 자동화 시나리오입니다.',
                                shortcut: ShortcutUtils.displayLabel(
                                  settings.shortcuts.listenToggle,
                                ),
                                onTap: () => _runScenario(
                                  SimulationScenario.naverMap,
                                ),
                                active: _selectedScenario ==
                                    SimulationScenario.naverMap,
                                running: _isRunning &&
                                    _selectedScenario ==
                                        SimulationScenario.naverMap,
                              ),
                              const SizedBox(height: 8),
                              _SimulationActionButton(
                                icon: Icons.note_alt_rounded,
                                title: '메모장 시나리오',
                                description:
                                    '메모장에 일기 내용을 입력하고 현재 날짜 이름으로 저장합니다.',
                                shortcut: '메모',
                                onTap: () => _runScenario(SimulationScenario.memo),
                                active:
                                    _selectedScenario == SimulationScenario.memo,
                                running: _isRunning &&
                                    _selectedScenario == SimulationScenario.memo,
                              ),
                              const SizedBox(height: 8),
                              _SimulationActionButton(
                                icon: Icons.dark_mode_rounded,
                                title: 'Windows 테마 변경',
                                description:
                                    'Windows 설정을 열고 화면 모드를 라이트에서 다크 테마로 변경합니다.',
                                shortcut: '테마',
                                onTap: () => _runScenario(
                                  SimulationScenario.windowsTheme,
                                ),
                                active: _selectedScenario ==
                                    SimulationScenario.windowsTheme,
                                running: _isRunning &&
                                    _selectedScenario ==
                                        SimulationScenario.windowsTheme,
                              ),
                              const SizedBox(height: 8),
                              _SimulationActionButton(
                                icon: Icons.copy_rounded,
                                title: '로그 복사',
                                description:
                                    '현재 실행 로그를 클립보드로 복사합니다.',
                                shortcut: ShortcutUtils.displayLabel(
                                  settings.shortcuts.screenRead,
                                ),
                                onTap: _copyLogs,
                              ),
                              const SizedBox(height: 8),
                              _SimulationActionButton(
                                icon: Icons.settings_rounded,
                                title: '설정',
                                description:
                                    '시뮬레이션과 앱 전반 설정을 확인합니다.',
                                shortcut: ShortcutUtils.displayLabel(
                                  settings.shortcuts.openSettings,
                                ),
                                onTap: _openSettings,
                              ),
                              const SizedBox(height: 16),
                              Divider(color: surfaceTheme.border),
                              const SizedBox(height: 16),
                              Text(
                                '안내',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: surfaceTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '네이버 지도, 메모장, Windows 테마 변경 시나리오는 각각 독립적으로 실행됩니다.',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  height: 1.6,
                                  color: surfaceTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: surfaceTheme.border,
                        ),
                        Expanded(
                          child: Container(
                            color: surfaceTheme.surface,
                            child: ListView(
                              controller: _stepScrollController,
                              padding: const EdgeInsets.all(24),
                              children: [
                                _SummaryCard(summary: _summary),
                                const SizedBox(height: 16),
                                _LogCard(log: _debugLog, onCopy: _copyLogs),
                                const SizedBox(height: 16),
                                Text(
                                  '실행 단계',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: surfaceTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_steps.isEmpty)
                                  _buildEmptyStepCard(context)
                                else
                                  ..._steps.map(_buildStepCard),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showSettingsModal)
                Positioned.fill(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.22),
                    child: InkWell(
                      onTap: _closeSettings,
                      child: Center(
                        child: InkWell(
                          onTap: () {},
                          child: SettingsModal(
                            onClose: _closeSettings,
                            onSaved: (_) => _closeSettings(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulationActionButton extends StatelessWidget {
  const _SimulationActionButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.shortcut,
    required this.onTap,
    this.active = false,
    this.running = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String shortcut;
  final VoidCallback onTap;
  final bool active;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        side: BorderSide(
          color: active ? const Color(0x662563EB) : surfaceTheme.border,
        ),
        backgroundColor: active ? AppColors.accentSoft : surfaceTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: surfaceTheme.contentBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: surfaceTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  running ? '현재 실행 중입니다.' : description,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    height: 1.4,
                    color: surfaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (shortcut != '미설정')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceTheme.contentBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: surfaceTheme.border),
              ),
              child: Text(
                shortcut,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: surfaceTheme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '실행 결과',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: surfaceTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            summary,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              height: 1.6,
              color: surfaceTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.onCopy,
  });

  final String log;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '로그',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: surfaceTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onCopy,
                child: const Text('복사'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64, maxHeight: 112),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: surfaceTheme.border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                log.trim().isEmpty ? '아직 기록된 로그가 없습니다.' : log.trim(),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  height: 1.5,
                  color: surfaceTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
