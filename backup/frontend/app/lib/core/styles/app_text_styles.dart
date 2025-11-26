import 'package:flutter/cupertino.dart';
import 'package:app/core/styles/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle logo(bool isDark) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.logoText(isDark),
      );

  static TextStyle body(bool isDark) => TextStyle(
        fontSize: 16,
        color: AppColors.text(isDark),
      );

  static TextStyle bodySecondary(bool isDark) => TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary(isDark),
      );

  static TextStyle title(bool isDark) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.text(isDark),
      );

  static TextStyle subtitle(bool isDark) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary(isDark),
      );
}
