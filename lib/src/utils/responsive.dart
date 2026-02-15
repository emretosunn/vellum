import 'package:flutter/material.dart';

/// Responsive breakpoint sabitleri ve yardımcı fonksiyonlar.
abstract final class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Ekran boyutuna göre layout tipi.
enum ScreenLayout { mobile, tablet, desktop }

/// Mevcut ekran boyutuna göre [ScreenLayout] döndürür.
ScreenLayout getScreenLayout(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.mobile) return ScreenLayout.mobile;
  if (width < Breakpoints.desktop) return ScreenLayout.tablet;
  return ScreenLayout.desktop;
}

/// Responsive değer döndürmek için extension.
extension ResponsiveContext on BuildContext {
  bool get isMobile =>
      MediaQuery.sizeOf(this).width < Breakpoints.mobile;

  bool get isTablet =>
      MediaQuery.sizeOf(this).width >= Breakpoints.mobile &&
      MediaQuery.sizeOf(this).width < Breakpoints.desktop;

  bool get isDesktop =>
      MediaQuery.sizeOf(this).width >= Breakpoints.desktop;

  /// Mobile / Desktop / Tablet'e göre değer döndürür.
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= Breakpoints.desktop) return desktop ?? tablet ?? mobile;
    if (width >= Breakpoints.mobile) return tablet ?? mobile;
    return mobile;
  }
}
