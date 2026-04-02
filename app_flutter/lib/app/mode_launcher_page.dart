import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../demo/demo_home_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/settings/application/settings_controller.dart';
import '../shared/models/settings_models.dart';
import '../simulation/simulation_home_page.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';

class ModeLauncherPage extends ConsumerStatefulWidget {
  const ModeLauncherPage({super.key});

  @override
  ConsumerState<ModeLauncherPage> createState() => _ModeLauncherPageState();
}

class _ModeLauncherPageState extends ConsumerState<ModeLauncherPage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'mode_launcher_focus');

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
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) {
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _openDemo();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f3) {
      _openConnected();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f4) {
      _openSimulation();
      return true;
    }

    return false;
  }

  void _openConnected() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HomePage(),
      ),
    );
  }

  void _openDemo() {
    final settings = ref.read(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoHomePage(
          initialSettings: settings,
          onSettingsChanged: controller.replaceAll,
          onSettingsSaved: (updated) {
            controller.replaceAll(updated);
            unawaited(controller.save());
          },
        ),
      ),
    );
  }

  void _openSimulation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SimulationHomePage(),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: surfaceTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Navi: Voice Navigator',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: surfaceTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '실행할 모드를 선택하세요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          color: surfaceTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _ModeLaunchCard(
                              title: '실제 모드',
                              subtitle: '로컬 서버와 연결된 실제 음성 명령 흐름을 확인하는 화면입니다.',
                              badge: '서비스',
                              hint: settings.shortcuts.screenRead.isEmpty
                                  ? 'F3'
                                  : settings.shortcuts.screenRead,
                              icon: Icons.link_rounded,
                              accentColor: AppColors.accent,
                              background: AppColors.accentSoft,
                              onTap: _openConnected,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _ModeLaunchCard(
                              title: '데모 모드',
                              subtitle: '백엔드 없이 시나리오 흐름을 확인하는 화면입니다.',
                              badge: '오프라인',
                              hint: settings.shortcuts.listenToggle.isEmpty
                                  ? 'F2'
                                  : settings.shortcuts.listenToggle,
                              icon: Icons.play_circle_outline_rounded,
                              accentColor: AppColors.warning,
                              background: AppColors.warningSoft,
                              onTap: _openDemo,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _ModeLaunchCard(
                              title: '시뮬레이션 모드',
                              subtitle: 'Playwright와 Windows 자동화를 사용해 실제 브라우저 시나리오를 실행합니다.',
                              badge: '자동화',
                              hint: 'F4',
                              icon: Icons.route_rounded,
                              accentColor: AppColors.success,
                              background: AppColors.successSoft,
                              onTap: _openSimulation,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _launcherMessage(settings),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          color: surfaceTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _launcherMessage(AppSettings settings) {
    if (settings.display.highContrast) {
      return '고대비 화면 설정이 적용되어 있습니다.';
    }
    if (settings.display.darkTheme) {
      return '다크 테마 설정이 적용되어 있습니다.';
    }
    if (settings.display.largeText) {
      return '큰 글씨 모드가 적용되어 있습니다.';
    }
    return '실제 모드, 데모 모드, 시뮬레이션 모드를 모두 여기서 테스트할 수 있습니다.';
  }
}

class _ModeLaunchCard extends StatelessWidget {
  const _ModeLaunchCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.background,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceTheme.contentBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: surfaceTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: surfaceTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                height: 1.6,
                color: surfaceTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  '바로 열기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18, color: accentColor),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: surfaceTheme.border),
                  ),
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: surfaceTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
