import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'text_command_composer.dart';

class ReadyState extends StatelessWidget {
  const ReadyState({
    super.key,
    this.summary,
    this.followUp,
    required this.onSubmitText,
    required this.isBusy,
  });

  final String? summary;
  final String? followUp;
  final ValueChanged<String> onSubmitText;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      color: surfaceTheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: surfaceTheme.contentBackground,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: surfaceTheme.border),
                        ),
                        child: Icon(
                          isBusy
                              ? Icons.hourglass_top_rounded
                              : Icons.mic_none_rounded,
                          size: 48,
                          color: isBusy
                              ? surfaceTheme.accent
                              : surfaceTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Navi: Voice Navigator',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: surfaceTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isBusy
                            ? '명령을 처리하고 있습니다. 잠시만 기다려 주세요.'
                            : '준비 완료. 왼쪽의 기능을 선택하여 시작하세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          height: 1.7,
                          color: surfaceTheme.textMuted,
                        ),
                      ),
                      if (summary != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceTheme.contentBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: surfaceTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '결과 요약',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: surfaceTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                summary!,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: surfaceTheme.textPrimary,
                                  height: 1.6,
                                ),
                              ),
                              if (followUp != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  followUp!,
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    color: surfaceTheme.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      TextCommandComposer(
                        onSubmit: onSubmitText,
                        isBusy: isBusy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
