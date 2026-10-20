
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF075E63);
  static const Color mint = Color(0xFFA8DED0);
  static const Color accent = Color(0xFFD7A85B);

  static const Color expense = Color(0xFFD9534F);
  static const Color income = Color(0xFF23865B);

  static const Color lightBackground = Color(0xFFF7F1E8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF253638);
  static const Color lightTextSecondary = Color(0xFF758180);
  static const Color lightBorder = Color(0xFFE5E0D7);

  static const Color darkBackground = Color(0xFF101820);
  static const Color darkSurface = Color(0xFF1C2732);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFB0BEC5);
  static const Color darkBorder = Color(0xFF344252);

  static Color get background => _current(Brightness.light, lightBackground);
  static Color get surface => _current(Brightness.light, lightSurface);
  static Color get textPrimary => _current(Brightness.light, lightTextPrimary);
  static Color get textSecondary => _current(Brightness.light, lightTextSecondary);
  static Color get border => _current(Brightness.light, lightBorder);

  static Color _current(Brightness brightness, Color color) => color;

  static Color backgroundFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : lightBackground;

  static Color surfaceFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : lightSurface;

  static Color textPrimaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  static Color borderFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorder
          : lightBorder;

  static Color? primaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : lightBackground;
}
