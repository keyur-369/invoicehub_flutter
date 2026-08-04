import 'package:flutter/material.dart';

/// Centralized color palette for the entire app.
/// Change values here and the whole app updates.
class AppColors {
  AppColors._();

  // ---- Brand ----
  static const Color primary = Color(0xFF3D5AFE); // indigo/blue accent
  static const Color primaryDark = Color(0xFF2A3EB1);
  static const Color secondary = Color(0xFF00BFA6); // teal accent

  // ---- Neutrals / surfaces ----
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0F1F6);
  static const Color border = Color(0xFFE7E9F1);

  // ---- Text ----
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ---- Status ----
  static const Color success = Color(0xFF2FBF71);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF3D5AFE);

  // ---- Nav item accents (used for module icons like Customers/Products/etc.) ----
  static const Color navHome = primary;
  static const Color navCustomers = Color(0xFFFF8A65);
  static const Color navProducts = Color(0xFF2FBF71);
  static const Color navHistory = Color(0xFF9575CD);
  static const Color navKhata = Color(0xFFE53935);
  static const Color navSettings = Color(0xFF6B7080);

  // ---- Khata / Ledger specific ----
  static const Color khataGave = Color(0xFFE53935); // Red (You Gave / Udhar)
  static const Color khataGot = Color(0xFF2E7D32);  // Green (You Got / Payment)

  // ---- Gradients ----
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---- Shadows ----
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 20,
    spreadRadius: 1,
    offset: const Offset(0, 6),
  );
}

/// App-wide ThemeData built on top of AppColors.
/// Use this in MaterialApp(theme: AppTheme.light()).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerColor: AppColors.border,
    );
  }
}
