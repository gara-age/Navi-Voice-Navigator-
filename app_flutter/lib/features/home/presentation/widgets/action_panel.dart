import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../shared/utils/shortcut_utils.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({
    super.key,
    required this.secureModeEnabled,
    required this.isRecording,
    required this.listenShortcut,
    required this.screenReadShortcut,
    required this.settingsShortcut,
    required this.onListenPressed,
    required this.onScreenReadPressed,
    required this.onSettingsPressed,
    required this.onToggleMode,
  });

  final bool secureModeEnabled;
  final bool isRecording;
  final String listenShortcut;
  final String screenReadShortcut;
  final String settingsShortcut;
  final VoidCallback onListenPressed;
  final VoidCallback onScreenReadPressed;
  final VoidCallback onSettingsPressed;
  final ValueChanged<bool> onToggleMode;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      color: surfaceTheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                '주요 기능',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: surfaceTheme.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            _CommandButton(
              icon: Icons.mic_rounded,
              title: isRecording ? '듣는 중' : '음성 듣기',
              description: '음성 명령 인식을 시작합니다.',
              shortcut: ShortcutUtils.displayLabel(listenShortcut),
              isActive: isRecording,
              onPressed: onListenPressed,
            ),
            const SizedBox(height: 6),
            _CommandButton(
              icon: Icons.visibility_rounded,
              title: '현재 화면 읽기',
              description: '현재 화면 요약과 읽기를 시작합니다.',
              shortcut: ShortcutUtils.displayLabel(screenReadShortcut),
              onPressed: onScreenReadPressed,
            ),
            const SizedBox(height: 6),
            _CommandButton(
              icon: Icons.settings_rounded,
              title: '설정',
              description: '기본 설정, 단축키, 보안, 화면 모드',
              shortcut: ShortcutUtils.displayLabel(settingsShortcut),
              onPressed: onSettingsPressed,
            ),
            const SizedBox(height: 12),
            Divider(color: surfaceTheme.border, height: 1),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '모드 전환',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: surfaceTheme.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            _ModeOption(
              label: '일반 모드',
              description: '기본 자동화와 안내를 수행합니다.',
              selected: !secureModeEnabled,
              secure: false,
              onTap: () => onToggleMode(false),
            ),
            const SizedBox(height: 6),
            _ModeOption(
              label: '보안 입력 모드',
              description: '민감한 입력과 읽기를 더 엄격하게 제한합니다.',
              selected: secureModeEnabled,
              secure: true,
              onTap: () => onToggleMode(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.shortcut,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String shortcut;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        side: BorderSide(
          color: isActive ? const Color(0x5922A34A) : surfaceTheme.border,
        ),
        backgroundColor:
            isActive ? AppColors.successSoft : surfaceTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Pretendard'),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: surfaceTheme.contentBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: surfaceTheme.textMuted),
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
                  description,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.description,
    required this.selected,
    required this.secure,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final bool secure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (secure ? AppColors.warningSoft : AppColors.accentSoft)
              : surfaceTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? (secure ? const Color(0x66D97706) : const Color(0x662563EB))
                : surfaceTheme.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: selected
                    ? (secure ? AppColors.warning : AppColors.accent)
                    : surfaceTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: secure && selected
                          ? AppColors.warning
                          : surfaceTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: surfaceTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
