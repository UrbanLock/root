import 'package:flutter/cupertino.dart';

/// Utility per valori responsive basati su dimensioni dello schermo
class ResponsiveUtils {
  const ResponsiveUtils._();

  /// Calcola una dimensione responsive basata sulla larghezza dello schermo
  static double responsiveSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    // Base su iPhone (375px) - scala proporzionalmente
    final scale = width / 375.0;
    return baseSize * scale.clamp(0.8, 1.5); // Limita la scala tra 0.8x e 1.5x
  }

  /// Calcola una dimensione responsive basata sull'altezza dello schermo
  static double responsiveHeight(BuildContext context, double baseSize) {
    final height = MediaQuery.of(context).size.height;
    // Base su iPhone (812px) - scala proporzionalmente
    final scale = height / 812.0;
    return baseSize * scale.clamp(0.8, 1.5); // Limita la scala tra 0.8x e 1.5x
  }

  /// Calcola padding responsive
  static EdgeInsets responsivePadding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    if (all != null) {
      final size = responsiveSize(context, all);
      return EdgeInsets.all(size);
    }
    
    return EdgeInsets.only(
      left: left != null ? responsiveSize(context, left) : (horizontal ?? 0),
      right: right != null ? responsiveSize(context, right) : (horizontal ?? 0),
      top: top != null ? responsiveHeight(context, top) : (vertical ?? 0),
      bottom: bottom != null ? responsiveHeight(context, bottom) : (vertical ?? 0),
    );
  }

  /// Calcola dimensione font responsive
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return responsiveSize(context, baseSize) * textScaleFactor.clamp(0.8, 1.2);
  }

  /// Verifica se il dispositivo è un tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600;
  }

  /// Verifica se il dispositivo è piccolo (iPhone SE, ecc.)
  static bool isSmallDevice(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 375;
  }

  /// Ottiene il padding orizzontale standard
  static double getStandardHorizontalPadding(BuildContext context) {
    return isTablet(context) ? 24.0 : 16.0;
  }

  /// Ottiene l'altezza dell'header responsive
  static double getHeaderHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    // Calcola come 8% dello schermo, con min/max
    final headerHeight = (screenHeight * 0.08).clamp(56.0, 80.0);
    return headerHeight + safeAreaTop;
  }
}


