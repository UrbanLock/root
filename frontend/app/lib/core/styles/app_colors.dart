import 'package:flutter/cupertino.dart';

class AppColors {
  const AppColors._();

  // Colori base per light mode
  static const Color _lightPrimary = Color(0xFF007AFF); // iOS Blue
  static const Color _lightBackground = CupertinoColors.white;
  static const Color _lightSurface = CupertinoColors.systemGrey6;
  static const Color _lightText = CupertinoColors.black;
  static const Color _lightTextSecondary = CupertinoColors.secondaryLabel;
  static const Color _lightCard = CupertinoColors.white;

  // Colori base per dark mode
  static const Color _darkPrimary = Color(0xFF0A84FF); // iOS Blue (più chiaro per dark)
  static const Color _darkBackground = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF1C1C1E);
  static const Color _darkText = CupertinoColors.white;
  static const Color _darkTextSecondary = Color(0xFFAEAEB2); // Grigio chiaro per dark mode (più leggibile)
  static const Color _darkCard = Color(0xFF2C2C2E);

  // Getter dinamici basati sul tema
  static Color primary(bool isDark) => isDark ? _darkPrimary : _lightPrimary;
  static Color background(bool isDark) =>
      isDark ? _darkBackground : _lightBackground;
  static Color surface(bool isDark) => isDark ? _darkSurface : _lightSurface;
  static Color text(bool isDark) => isDark ? _darkText : _lightText;
  static Color textSecondary(bool isDark) =>
      isDark ? _darkTextSecondary : _lightTextSecondary;
  static Color card(bool isDark) => isDark ? _darkCard : _lightCard;

  // Colori specifici per componenti
  static Color logoText(bool isDark) => text(isDark);
  static Color bottomBarBackground(bool isDark) => surface(isDark);
  static Color bottomBarActive(bool isDark) => primary(isDark);
  static Color bottomBarInactive(bool isDark) =>
      isDark ? CupertinoColors.inactiveGray : CupertinoColors.inactiveGray;
  static Color searchBackground(bool isDark) =>
      isDark ? _darkCard : CupertinoColors.white;
  
  // Colori per overlay e effetti
  static Color overlayLoading(bool isDark) =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  static Color overlayError(bool isDark) =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  static Color shadowColor(bool isDark) =>
      isDark ? const Color(0xFF000000) : const Color(0xFF3A3A3C);
  static Color iconBackground(bool isDark) =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  static Color borderSecondary(bool isDark) =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);
  static Color borderColor(bool isDark) =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);
}
