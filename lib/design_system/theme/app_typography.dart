import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Duas famílias, igual ao site: `Recife Text` nos títulos (serifada,
/// peso único 400, letter-spacing -0.02em — dá o tom "editorial/sério"),
/// `Messina Sans` no corpo/UI (400/600/700). Hierarquia é peso+tamanho de
/// fonte, não cor (Refactoring UI) — por isso quase tudo usa [AppColors.heading]
/// ou [AppColors.foreground], nunca uma cor de marca em texto corrido.
abstract final class AppTypography {
  static const titleFontFamily = 'Recife Text';
  static const bodyFontFamily = 'Messina Sans';

  static const _titleLetterSpacing = -0.02 * 16;

  static TextTheme get textTheme => TextTheme(
    displayLarge: _title(32, height: 1.15),
    displayMedium: _title(28, height: 1.18),
    displaySmall: _title(24, height: 1.2),
    headlineLarge: _title(24, height: 1.22),
    headlineMedium: _title(20, height: 1.25),
    headlineSmall: _title(18, height: 1.3),
    titleLarge: _title(16, height: 1.3),
    titleMedium: _body(15, height: 1.35, weight: FontWeight.w600),
    titleSmall: _body(13, height: 1.35, weight: FontWeight.w600),
    bodyLarge: _body(16, height: 1.5),
    bodyMedium: _body(14, height: 1.45),
    bodySmall: _body(13, height: 1.4, color: AppColors.foreground),
    labelLarge: _body(15, height: 1.2, weight: FontWeight.w600),
    labelMedium: _body(
      12,
      height: 1.3,
      weight: FontWeight.w600,
      color: AppColors.foreground,
    ),
    labelSmall: _body(
      11,
      height: 1.3,
      weight: FontWeight.w500,
      color: AppColors.foreground,
    ),
  );

  static TextStyle _title(double size, {required double height}) {
    return TextStyle(
      fontFamily: titleFontFamily,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w400,
      letterSpacing: _titleLetterSpacing * (size / 16),
      color: AppColors.heading,
    );
  }

  static TextStyle _body(
    double size, {
    required double height,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.foreground,
  }) {
    return TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color,
    );
  }

  /// Rótulo micro maiúsculo (categoria/status) — sem slot direto no
  /// `TextTheme`, usado explicitamente onde o site usaria `uppercase`.
  static const microLabel = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.foreground,
  );
}
