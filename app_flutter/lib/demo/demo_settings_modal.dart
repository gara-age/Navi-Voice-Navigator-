import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_theme.dart';
import '../shared/models/settings_models.dart';
import '../shared/utils/shortcut_utils.dart';

class DemoSettingsModal extends StatefulWidget {
  const DemoSettingsModal({
    super.key,
    required this.initialSettings,
    required this.onClose,
    required this.onSaved,
    this.onChanged,
  });

  final AppSettings initialSettings;
  final VoidCallback onClose;
  final ValueChanged<AppSettings> onSaved;
  final ValueChanged<AppSettings>? onChanged;

  @override
  State<DemoSettingsModal> createState() => _DemoSettingsModalState();
}

class _DemoSettingsModalState extends State<DemoSettingsModal> {
  static const _tabs = ['기본 설정', '단축키', '보안', '화면 설정'];

  final FocusNode _focusNode = FocusNode(debugLabel: 'demo_settings_modal_focus');
  late AppSettings _settings;
  int _selectedTab = 0;
  String? _capturingField;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_capturingField != null) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _capturingField = null);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        _setShortcut(_capturingField!, '');
        setState(() => _capturingField = null);
        return KeyEventResult.handled;
      }

      final shortcut = ShortcutUtils.captureFromEvent(event);
      if (shortcut == null || shortcut.isEmpty) {
        return KeyEventResult.handled;
      }

      _setShortcut(_capturingField!, shortcut);
      setState(() => _capturingField = null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _update(AppSettings next) {
    setState(() => _settings = next);
    widget.onChanged?.call(next);
  }

  void _setShortcut(String field, String value) {
    final normalized = ShortcutUtils.normalize(value);
    var shortcuts = _settings.shortcuts;

    if (normalized.isNotEmpty) {
      if (field != 'listen' &&
          ShortcutUtils.normalize(shortcuts.listenToggle) == normalized) {
        shortcuts = shortcuts.copyWith(listenToggle: '');
      }
      if (field != 'screen' &&
          ShortcutUtils.normalize(shortcuts.screenRead) == normalized) {
        shortcuts = shortcuts.copyWith(screenRead: '');
      }
      if (field != 'settings' &&
          ShortcutUtils.normalize(shortcuts.openSettings) == normalized) {
        shortcuts = shortcuts.copyWith(openSettings: '');
      }
    }

    switch (field) {
      case 'listen':
        shortcuts = shortcuts.copyWith(listenToggle: normalized);
        break;
      case 'screen':
        shortcuts = shortcuts.copyWith(screenRead: normalized);
        break;
      case 'settings':
        shortcuts = shortcuts.copyWith(openSettings: normalized);
        break;
    }

    _update(_settings.copyWith(shortcuts: shortcuts));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Container(
          width: 780,
          height: 620,
          decoration: BoxDecoration(
            color: surfaceTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: surfaceTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              _ModalHeader(
                title: '설정',
                subtitle: '데모 모드 설정과 화면 표시 옵션을 조정합니다.',
                onClose: widget.onClose,
              ),
              Divider(height: 1, color: surfaceTheme.border),
              Expanded(
                child: Row(
                  children: [
                    _Sidebar(
                      items: _tabs,
                      selectedTab: _selectedTab,
                      onSelect: (value) => setState(() => _selectedTab = value),
                    ),
                    Container(width: 1, color: surfaceTheme.border),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: surfaceTheme.contentBackground,
                  border: Border(top: BorderSide(color: surfaceTheme.border)),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Text(
                      _capturingField == null
                          ? '변경 내용은 저장 전에도 바로 데모 화면에 반영됩니다.'
                          : '원하는 키를 누르세요. Delete는 해제, Esc는 취소입니다.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: surfaceTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    _ModalButton(
                      label: '취소',
                      primary: false,
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 10),
                    _ModalButton(
                      label: '저장',
                      primary: true,
                      onTap: () => widget.onSaved(_settings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('기본 설정'),
            _ToggleCard(
              title: '자동 언어 감지',
              description: '데모 음성 명령의 언어 감지 상태를 표시합니다.',
              value: _settings.general.autoLanguageDetection,
              onChanged: (value) => _update(
                _settings.copyWith(
                  general: _settings.general.copyWith(
                    autoLanguageDetection: value,
                  ),
                ),
              ),
            ),
            _SliderCard(
              title: '마이크 감도',
              description: '데모 시나리오의 음성 반응 강도를 조절합니다.',
              value: _settings.general.microphoneSensitivity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) => _update(
                _settings.copyWith(
                  general: _settings.general.copyWith(
                    microphoneSensitivity: value,
                  ),
                ),
              ),
            ),
            _SliderCard(
              title: '읽어주는 음성 속도',
              description: '데모 응답의 음성 속도 표시값을 조절합니다.',
              value: _settings.general.ttsSpeed,
              min: 0.5,
              max: 2.0,
              onChanged: (value) => _update(
                _settings.copyWith(
                  general: _settings.general.copyWith(ttsSpeed: value),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('단축키'),
            _ToggleCard(
              title: '단축키 사용',
              description: '데모 모드 단축키 입력을 활성화합니다.',
              value: _settings.shortcuts.enabled,
              onChanged: (value) => _update(
                _settings.copyWith(
                  shortcuts: _settings.shortcuts.copyWith(enabled: value),
                ),
              ),
            ),
            _ShortcutCard(
              title: '듣기 시작 / 중지',
              description: '음성 듣기 상태를 시작하거나 종료합니다.',
              value: _settings.shortcuts.listenToggle,
              isCapturing: _capturingField == 'listen',
              onCapture: () => setState(() => _capturingField = 'listen'),
              onClear: () => _setShortcut('listen', ''),
            ),
            _ShortcutCard(
              title: '현재 화면 읽기',
              description: '현재 화면 요약과 읽기를 시작합니다.',
              value: _settings.shortcuts.screenRead,
              isCapturing: _capturingField == 'screen',
              onCapture: () => setState(() => _capturingField = 'screen'),
              onClear: () => _setShortcut('screen', ''),
            ),
            _ShortcutCard(
              title: '설정 열기',
              description: '설정 모달을 바로 엽니다.',
              value: _settings.shortcuts.openSettings,
              isCapturing: _capturingField == 'settings',
              onCapture: () => setState(() => _capturingField = 'settings'),
              onClear: () => _setShortcut('settings', ''),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('보안'),
            _ToggleCard(
              title: '보안 입력 모드',
              description: '민감한 입력 시나리오에서 보호 안내를 강화합니다.',
              value: _settings.security.secureInputMode,
              onChanged: (value) => _update(
                _settings.copyWith(
                  security: _settings.security.copyWith(
                    secureInputMode: value,
                  ),
                ),
              ),
            ),
            _ChoiceCard<int>(
              title: '자동 잠금 시간',
              description: '데모 안내의 자동 잠금 시간을 선택합니다.',
              value: _settings.security.autoLockTimeoutSeconds,
              options: const [
                _ChoiceItem(label: '1분', value: 60),
                _ChoiceItem(label: '3분', value: 180),
                _ChoiceItem(label: '5분', value: 300),
              ],
              onChanged: (value) => _update(
                _settings.copyWith(
                  security: _settings.security.copyWith(
                    autoLockTimeoutSeconds: value,
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('화면 설정'),
            _DisplayPreview(settings: _settings),
            const SizedBox(height: 12),
            _ToggleCard(
              title: '다크 테마',
              description: '어두운 배경 중심의 화면으로 전환합니다.',
              value: _settings.display.darkTheme,
              onChanged: (value) => _update(
                _settings.copyWith(
                  display: _settings.display.copyWith(
                    darkTheme: value,
                    highContrast: value ? false : _settings.display.highContrast,
                  ),
                ),
              ),
            ),
            _ToggleCard(
              title: '고대비',
              description: '명도 대비를 높여 화면 경계를 더 또렷하게 표시합니다.',
              value: _settings.display.highContrast,
              onChanged: (value) => _update(
                _settings.copyWith(
                  display: _settings.display.copyWith(
                    highContrast: value,
                    darkTheme: value ? false : _settings.display.darkTheme,
                  ),
                ),
              ),
            ),
            _ToggleCard(
              title: '큰 글씨',
              description: '텍스트 크기를 더 크게 표시합니다.',
              value: _settings.display.largeText,
              onChanged: (value) => _update(
                _settings.copyWith(
                  display: _settings.display.copyWith(largeText: value),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: surfaceTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: surfaceTheme.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: surfaceTheme.contentBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: surfaceTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedTab,
    required this.onSelect,
  });

  final List<String> items;
  final int selectedTab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      width: 184,
      color: surfaceTheme.contentBackground,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _SidebarItem(
              label: items[index],
              selected: selectedTab == index,
              onTap: () => onSelect(index),
            ),
            if (index != items.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFBFDBFE) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: surfaceTheme.textPrimary,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceTheme.border),
      ),
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
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              height: 1.55,
              color: surfaceTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DisplayPreview extends StatelessWidget {
  const _DisplayPreview({
    required this.settings,
  });

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: surfaceTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: surfaceTheme.border),
            ),
            child: Icon(
              settings.display.highContrast
                  ? Icons.contrast_rounded
                  : settings.display.darkTheme
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
              color: surfaceTheme.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 미리보기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: settings.display.largeText ? 17 : 14,
                    fontWeight: FontWeight.w700,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.display.highContrast
                      ? '고대비 모드가 적용됩니다.'
                      : settings.display.darkTheme
                          ? '다크 테마가 적용됩니다.'
                          : '기본 밝은 테마가 적용됩니다.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: settings.display.largeText ? 14 : 12,
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

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: title,
      description: description,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 74,
          height: 38,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.description,
    required this.value,
    required this.isCapturing,
    required this.onCapture,
    required this.onClear,
  });

  final String title;
  final String description;
  final String value;
  final bool isCapturing;
  final VoidCallback onCapture;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;
    final displayValue =
        isCapturing ? '입력 대기 중...' : ShortcutUtils.displayLabel(value);

    return _CardShell(
      title: title,
      description: description,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onCapture,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCapturing
                        ? surfaceTheme.accent
                        : surfaceTheme.border,
                  ),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCapturing
                        ? surfaceTheme.accent
                        : surfaceTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _InlineButton(
            label: '변경',
            primary: true,
            onTap: onCapture,
          ),
          const SizedBox(width: 8),
          _InlineButton(
            label: '해제',
            primary: false,
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return _CardShell(
      title: title,
      description: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.clamp(200.0, 420.0).toDouble();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null || !renderBox.hasSize) {
                    return;
                  }
                  final local = renderBox.globalToLocal(details.globalPosition);
                  final next = (local.dx / width).clamp(0.0, 1.0);
                  onChanged(min + (max - min) * next);
                },
                child: Container(
                  width: width,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: width * normalized,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceItem<T> {
  const _ChoiceItem({
    required this.label,
    required this.value,
  });

  final String label;
  final T value;
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String description;
  final T value;
  final List<_ChoiceItem<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: title,
      description: description,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final selected = option.value == value;
          return GestureDetector(
            onTap: () => onChanged(option.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                ),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF374151),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InlineButton extends StatelessWidget {
  const _InlineButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: primary ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _ModalButton extends StatelessWidget {
  const _ModalButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: primary ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFD1D5DB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }
}
