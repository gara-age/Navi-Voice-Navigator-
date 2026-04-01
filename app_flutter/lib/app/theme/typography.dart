import 'package:flutter/material.dart';

TextTheme buildTextTheme(TextTheme base) {
  return base.copyWith(
    displaySmall: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );
}
