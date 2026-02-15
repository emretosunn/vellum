import 'package:flutter/material.dart';

/// InkToken uygulama renkleri.
abstract final class AppColors {
  // Primary
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42DB);
  static const Color secondary = Color(0xFF3F51B5);

  // Accent
  static const Color accent = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFFF9800);

  // Neutral
  static const Color scaffoldLight = Color(0xFFF5F5F7);
  static const Color scaffoldDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E2C);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFC107);

  // Text
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
}
