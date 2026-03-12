import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlack = Color(0xFF111111);
  static const Color backgroundWhite = Color(0xFFF0F1F3);
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF222222);
  static const Color textGrey = Color(0xFF757575);
  static const Color expenseRed = Color(0xFFE53935);
  static const Color incomeGreen = Color(0xFF43A047);

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundWhite,
      primaryColor: primaryBlack,
      fontFamily: 'Roboto', // Default modern font
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryBlack),
        titleTextStyle: TextStyle(
          color: primaryBlack,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryBlack,
        secondary: primaryBlack,
        background: backgroundWhite,
        surface: cardWhite,
      ),
      cardTheme: CardTheme(
        color: cardWhite,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlack,
        foregroundColor: Colors.white,
      ),
    );
  }
}
