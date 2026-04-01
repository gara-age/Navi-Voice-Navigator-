import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    super.key,
    this.onOpenHelp,
  });

  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceTheme.surface,
        border: Border(bottom: BorderSide(color: surfaceTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
              decoration: BoxDecoration(
              color: surfaceTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mic_rounded, size: 20, color: Colors.white),
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
    );
  }
}
