import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class TextCommandComposer extends StatefulWidget {
  const TextCommandComposer({
    super.key,
    required this.onSubmit,
    required this.isBusy,
  });

  final ValueChanged<String> onSubmit;
  final bool isBusy;

  @override
  State<TextCommandComposer> createState() => _TextCommandComposerState();
}

class _TextCommandComposerState extends State<TextCommandComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.isBusy) {
      return;
    }
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: surfaceTheme.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: '메시지 입력을 통해서도 명령을 내릴 수 있습니다',
            filled: true,
            fillColor: surfaceTheme.contentBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: widget.isBusy ? null : _submit,
          child: Text(widget.isBusy ? '처리 중...' : '텍스트 명령 실행'),
        ),
      ],
    );
  }
}
