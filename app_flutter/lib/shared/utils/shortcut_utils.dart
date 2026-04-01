import 'package:flutter/services.dart';

class ShortcutUtils {
  static String normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parts = trimmed
        .split('+')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }

    final modifiers = <String>[];
    String key = '';

    for (final rawPart in parts) {
      final lower = rawPart.toLowerCase();
      switch (lower) {
        case 'ctrl':
        case 'control':
          if (!modifiers.contains('Ctrl')) {
            modifiers.add('Ctrl');
          }
          break;
        case 'shift':
          if (!modifiers.contains('Shift')) {
            modifiers.add('Shift');
          }
          break;
        case 'alt':
          if (!modifiers.contains('Alt')) {
            modifiers.add('Alt');
          }
          break;
        case 'win':
        case 'windows':
        case 'meta':
          if (!modifiers.contains('Win')) {
            modifiers.add('Win');
          }
          break;
        default:
          key = _normalizeKeyLabel(rawPart);
      }
    }

    if (key.isEmpty) {
      return '';
    }

    return [...modifiers, key].join('+');
  }

  static String displayLabel(String value) {
    final normalized = normalize(value);
    return normalized.isEmpty ? '미설정' : normalized;
  }

  static bool matches(KeyEvent event, String shortcut) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final normalized = normalize(shortcut);
    if (normalized.isEmpty) {
      return false;
    }

    final parts = normalized.split('+');
    final expectedKey = parts.last;
    final expectedModifiers = parts.take(parts.length - 1).toSet();

    final actualKey = _logicalKeyToLabel(event.logicalKey);
    if (actualKey.isEmpty || actualKey != expectedKey) {
      return false;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final actualModifiers = <String>{};
    if (_isPressed(pressed, {
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
    })) {
      actualModifiers.add('Ctrl');
    }
    if (_isPressed(pressed, {
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    })) {
      actualModifiers.add('Shift');
    }
    if (_isPressed(pressed, {
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
    })) {
      actualModifiers.add('Alt');
    }
    if (_isPressed(pressed, {
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    })) {
      actualModifiers.add('Win');
    }

    return actualModifiers.containsAll(expectedModifiers) &&
        expectedModifiers.containsAll(actualModifiers);
  }

  static String? captureFromEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return null;
    }

    final keyLabel = _logicalKeyToLabel(event.logicalKey);
    if (keyLabel.isEmpty) {
      return null;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final parts = <String>[];
    if (_isPressed(pressed, {
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
    })) {
      parts.add('Ctrl');
    }
    if (_isPressed(pressed, {
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    })) {
      parts.add('Shift');
    }
    if (_isPressed(pressed, {
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
    })) {
      parts.add('Alt');
    }
    if (_isPressed(pressed, {
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    })) {
      parts.add('Win');
    }
    parts.add(keyLabel);

    return parts.join('+');
  }

  static bool _isPressed(
    Set<LogicalKeyboardKey> pressed,
    Set<LogicalKeyboardKey> candidates,
  ) {
    return pressed.any(candidates.contains);
  }

  static String _normalizeKeyLabel(String rawPart) {
    final lower = rawPart.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }

    if (RegExp(r'^f\d{1,2}$').hasMatch(lower)) {
      return lower.toUpperCase();
    }
    if (lower.length == 1) {
      return lower.toUpperCase();
    }

    switch (lower) {
      case 'space':
        return 'Space';
      case 'enter':
        return 'Enter';
      case 'tab':
        return 'Tab';
      case 'esc':
      case 'escape':
        return 'Esc';
      default:
        return rawPart.trim();
    }
  }

  static String _logicalKeyToLabel(LogicalKeyboardKey key) {
    if (_isModifierOnly(key)) {
      return '';
    }

    final keyLabel = key.keyLabel.trim();
    if (keyLabel.isNotEmpty) {
      if (keyLabel.length == 1) {
        return keyLabel.toUpperCase();
      }
      final lower = keyLabel.toLowerCase();
      if (lower.startsWith('f') && int.tryParse(lower.substring(1)) != null) {
        return lower.toUpperCase();
      }
      switch (lower) {
        case ' ':
          return 'Space';
        case 'escape':
          return 'Esc';
        case 'enter':
          return 'Enter';
        case 'tab':
          return 'Tab';
        default:
          return keyLabel;
      }
    }

    final debugName = key.debugName?.toLowerCase() ?? '';
    if (debugName.startsWith('f') &&
        int.tryParse(debugName.substring(1)) != null) {
      return debugName.toUpperCase();
    }

    switch (debugName) {
      case 'space':
        return 'Space';
      case 'escape':
        return 'Esc';
      case 'enter':
        return 'Enter';
      case 'tab':
        return 'Tab';
      default:
        return '';
    }
  }

  static bool _isModifierOnly(LogicalKeyboardKey key) {
    return <LogicalKeyboardKey>{
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    }.contains(key);
  }
}
