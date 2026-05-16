import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color primaryBlue = Color(0xFF5B6EF7);
  static const Color accentGradientStart = Color(0xFF6C5CE7);
  static const Color accentGradientEnd = Color(0xFF5B8DF7);

  // Status colors
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF5252);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0D0D0F);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceCardDark = Color(0xFF16162A);
  static const Color surfaceCardBorderDark = Color(0xFF2A2A4A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0C8);
  static const Color textMutedDark = Color(0xFF8888A8);
  static const Color buttonDriverBgDark = Color(0xFF1E1E3A);

  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color surfaceCardBorderLight = Color(0xFFE1E2E9);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF5E5E7E);
  static const Color textMutedLight = Color(0xFF8888A8);
  static const Color buttonDriverBgLight = Color(0xFFE8E9F3);

  // Dynamic access helpers
  static Color getBackgroundColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? backgroundDark : backgroundLight;

  static Color getSurfaceCardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceCardDark : surfaceCardLight;

  static Color getBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceCardBorderDark : surfaceCardBorderLight;

  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;

  static Color getButtonDriverBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? buttonDriverBgDark : buttonDriverBgLight;

  // Static Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentGradientStart, accentGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundGradientDark = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1A3E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    colors: [Color(0xFFF5F6FA), Color(0xFFE8E9F3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTextStyles {
  static const String fontFamily = 'Roboto';

  static TextStyle heading1(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.getTextPrimary(context),
        height: 1.2,
      );

  static TextStyle bodyLarge(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.getTextSecondary(context),
        height: 1.5,
      );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.getTextSecondary(context),
        height: 1.5,
      );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMutedDark,
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryPurple,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurple,
        secondary: AppColors.primaryBlue,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
      ),
      fontFamily: AppTextStyles.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primaryPurple,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPurple,
        secondary: AppColors.primaryBlue,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
      ),
      fontFamily: AppTextStyles.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: TextStyle(color: AppColors.textPrimaryLight, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
