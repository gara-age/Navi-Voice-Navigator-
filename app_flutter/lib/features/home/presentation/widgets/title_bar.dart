import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    super.key,
    this.onOpenHelp,
  });

  final VoidCallback? onOpenHelp;

  static const MethodChannel _windowControlsChannel =
      MethodChannel('navi/window_controls');

  Future<void> _startWindowDrag() async {
    try {
      await _windowControlsChannel.invokeMethod<void>('startWindowDrag');
    } catch (_) {}
  }

  Future<void> _minimizeWindow() async {
    try {
      await _windowControlsChannel.invokeMethod<void>('minimizeWindow');
    } catch (_) {}
  }

  Future<void> _toggleMaximizeWindow() async {
    try {
      await _windowControlsChannel.invokeMethod<void>('toggleMaximizeWindow');
    } catch (_) {}
  }

  Future<void> _closeWindow() async {
    try {
      await _windowControlsChannel.invokeMethod<void>('closeWindow');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _startWindowDrag(),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: surfaceTheme.surface,
          border: Border(bottom: BorderSide(color: surfaceTheme.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => _startWindowDrag(),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surfaceTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Navi: Voice Navigator',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: surfaceTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'AI Voice Assistant for PC Accessibility',
                            style: TextStyle(
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
            ),
            const SizedBox(width: 12),
            _WindowControlButton(
              tooltip: '최소화',
              icon: Icons.remove_rounded,
              onPressed: _minimizeWindow,
            ),
            const SizedBox(width: 8),
            _WindowControlButton(
              tooltip: '최대화 또는 복원',
              icon: Icons.crop_square_rounded,
              onPressed: _toggleMaximizeWindow,
            ),
            const SizedBox(width: 8),
            _WindowControlButton(
              tooltip: '닫기',
              icon: Icons.close_rounded,
              isDestructive: true,
              onPressed: _closeWindow,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  const _WindowControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDestructive
                  ? const Color(0x14FF4D4F)
                  : surfaceTheme.contentBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDestructive
                    ? const Color(0x33FF4D4F)
                    : surfaceTheme.border,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDestructive
                  ? const Color(0xFFD9363E)
                  : surfaceTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
