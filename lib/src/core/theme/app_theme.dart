import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,
      background: AppColors.backgroundDark,
      onBackground: AppColors.textPrimaryDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDarkElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondaryDark,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,
      background: AppColors.backgroundLight,
      onBackground: AppColors.textPrimaryLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondaryLight,
      ),
      useMaterial3: true,
    );
  }
}
