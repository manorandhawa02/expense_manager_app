import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand colors
  static const Color primary = Color(0xFF0D1C1B);
  static const Color darkPrimary = Color(0xFF66D9CF);
  static const Color mint = Color(0xFFA8DED0);
  static const Color accent = Color(0xFFD7A85B);

  // Semantic colors
  static const Color expense = Color(0xFFD9534F);
  static const Color income = Color(0xFF23865B);
  static const Color darkExpense = Color(0xFFFF8585);
  static const Color darkIncome = Color(0xFF73D6A0);

  // Light palette
  static const Color lightBackground = Color(0xFFF7F1E8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF253638);
  static const Color lightTextSecondary = Color(0xFF657575);
  static const Color lightBorder = Color(0xFFE2DCD2);

  // Dark palette
  static const Color darkBackground = Color(0xFF0D1C1B);
  static const Color darkSurface = Color(0xFF1C2732);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFB0BEC5);
  static const Color darkBorder = Color(0xFF344252);

  // Backward-compatible defaults.
  // These are LIGHT-theme values only.
  // Prefer the context-aware methods inside widgets.
  static Color get background => lightBackground;
  static Color get surface => lightSurface;
  static Color get textPrimary => lightTextPrimary;
  static Color get textSecondary => lightTextSecondary;
  static Color get border => lightBorder;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundFor(BuildContext context) =>
      _isDark(context) ? darkBackground : lightBackground;

  static Color surfaceFor(BuildContext context) =>
      _isDark(context) ? darkSurface : lightSurface;

  static Color textPrimaryFor(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color borderFor(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;

  // Corrected: primaryFor returns a brand color, not a background.
  static Color primaryFor(BuildContext context) =>
      _isDark(context) ? const Color.fromARGB(255, 102, 217, 207) : primary;

  static Color accentFor(BuildContext context) =>
      _isDark(context) ? accent : accent;

  static Color expenseFor(BuildContext context) =>
      _isDark(context) ? darkExpense : expense;

  static Color incomeFor(BuildContext context) =>
      _isDark(context) ? darkIncome : income;
}