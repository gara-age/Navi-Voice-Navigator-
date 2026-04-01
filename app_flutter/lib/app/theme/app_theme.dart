import 'package:flutter/material.dart';

import '../../shared/models/settings_models.dart';
import 'colors.dart';
import 'typography.dart';

ThemeData buildAppTheme({DisplaySettings? display}) {
  final activeDisplay = display ??
      const DisplaySettings(
        darkTheme: false,
        highContrast: false,
        largeText: false,
      );
  final brightness = activeDisplay.darkTheme ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'Pretendard',
  );

  final isDark = activeDisplay.darkTheme;
  final isHighContrast = activeDisplay.highContrast;
  final background = isHighContrast
      ? Colors.black
      : (isDark ? const Color(0xFF101214) : AppColors.background);
  final surface = isHighContrast
      ? const Color(0xFF000000)
      : (isDark ? const Color(0xFF181B20) : AppColors.surface);
  final scaffold = isHighContrast
      ? const Color(0xFF000000)
      : (isDark ? const Color(0xFF0D1117) : AppColors.shellBackground);
  final textPrimary = isHighContrast
      ? Colors.white
      : (isDark ? const Color(0xFFF3F4F6) : AppColors.textPrimary);
  final textMuted = isHighContrast
      ? const Color(0xFFE5E7EB)
      : (isDark ? const Color(0xFFCBD5E1) : AppColors.textMuted);
  final border = isHighContrast
      ? const Color(0xFFFFFFFF)
      : (isDark ? const Color(0xFF3A4250) : AppColors.border);
  final accent = isHighContrast
      ? const Color(0xFFFFFF00)
      : (isDark ? const Color(0xFF60A5FA) : AppColors.accent);

  final rawTextTheme = buildTextTheme(base.textTheme).apply(
    bodyColor: textPrimary,
    displayColor: textPrimary,
    fontFamily: 'Pretendard',
  );
  final textTheme =
      _scaleTextTheme(rawTextTheme, activeDisplay.largeText ? 1.14 : 1.0);

  return base.copyWith(
    scaffoldBackgroundColor: scaffold,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isHighContrast ? Colors.black : Colors.white,
      secondary: accent,
      onSecondary: isHighContrast ? Colors.black : Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    ),
    textTheme: textTheme,
    dividerColor: border,
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      hintStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: textMuted,
        fontSize: 13,
      ),
      labelStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: textMuted,
        fontSize: 13,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: isHighContrast ? Colors.black : Colors.white,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: activeDisplay.largeText ? 15 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: surface,
        side: BorderSide(color: border),
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: activeDisplay.largeText ? 15 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface,
      contentTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: textPrimary,
        fontSize: activeDisplay.largeText ? 14 : 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    extensions: <ThemeExtension<dynamic>>[
      AppSurfaceTheme(
        shellBackground: scaffold,
        contentBackground: background,
        surface: surface,
        textPrimary: textPrimary,
        textMuted: textMuted,
        border: border,
        accent: accent,
      ),
    ],
  );
}

TextTheme _scaleTextTheme(TextTheme theme, double factor) {
  if (factor == 1.0) {
    return theme;
  }

  TextStyle? scale(TextStyle? style) => style?.copyWith(
        fontSize: style.fontSize == null ? null : style.fontSize! * factor,
      );

  return theme.copyWith(
    displayLarge: scale(theme.displayLarge),
    displayMedium: scale(theme.displayMedium),
    displaySmall: scale(theme.displaySmall),
    headlineLarge: scale(theme.headlineLarge),
    headlineMedium: scale(theme.headlineMedium),
    headlineSmall: scale(theme.headlineSmall),
    titleLarge: scale(theme.titleLarge),
    titleMedium: scale(theme.titleMedium),
    titleSmall: scale(theme.titleSmall),
    bodyLarge: scale(theme.bodyLarge),
    bodyMedium: scale(theme.bodyMedium),
    bodySmall: scale(theme.bodySmall),
    labelLarge: scale(theme.labelLarge),
    labelMedium: scale(theme.labelMedium),
    labelSmall: scale(theme.labelSmall),
  );
}

@immutable
class AppSurfaceTheme extends ThemeExtension<AppSurfaceTheme> {
  const AppSurfaceTheme({
    required this.shellBackground,
    required this.contentBackground,
    required this.surface,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.accent,
  });

  final Color shellBackground;
  final Color contentBackground;
  final Color surface;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color accent;

  @override
  AppSurfaceTheme copyWith({
    Color? shellBackground,
    Color? contentBackground,
    Color? surface,
    Color? textPrimary,
    Color? textMuted,
    Color? border,
    Color? accent,
  }) {
    return AppSurfaceTheme(
      shellBackground: shellBackground ?? this.shellBackground,
      contentBackground: contentBackground ?? this.contentBackground,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppSurfaceTheme lerp(ThemeExtension<AppSurfaceTheme>? other, double t) {
    if (other is! AppSurfaceTheme) {
      return this;
    }
    return AppSurfaceTheme(
      shellBackground: Color.lerp(shellBackground, other.shellBackground, t)!,
      contentBackground:
          Color.lerp(contentBackground, other.contentBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
