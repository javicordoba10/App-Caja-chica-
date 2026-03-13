import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Surgical V17/V10 Specs)
  static const Color primaryDark = Color(0xFF7A2C0A);   // V10 Gradient Top
  static const Color primaryOrange = Color(0xFFBA4817); // V10 Gradient Bottom
  static const Color secondaryOrange = Color(0xFFE58D07); // For button gradients
  static const Color primaryYellow = Color(0xFFE5A102); // Institutional Yellow
  
  static const Color backgroundWhite = Color(0xFFF8F9FA); 
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF222222);
  static const Color textGrey = Color(0xFFA0A5B1);
  static const Color sidebarDark = Color(0xFF1E1611); 
  static const Color cardShadow = Color(0x0F000000);
  
  static const Color expenseRed = Color(0xFFE53935);
  static const Color incomeGreen = Color(0xFF43A047);

  static LinearGradient get headerGradient => const LinearGradient(
    colors: [
      primaryDark, 
      Color(0xFF8B3612), // Subtle mid-tone for depth
      primaryOrange
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get buttonGradient => const LinearGradient(
    colors: [
      Color(0xFFE65100), // Lighter, more vibrant orange start
      primaryYellow,     // Ends in #E5A102
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundWhite,
      primaryColor: primaryOrange,
      textTheme: GoogleFonts.montserratTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: GoogleFonts.montserrat(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: primaryYellow,
        surface: cardWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shadowColor: cardShadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textGrey, fontSize: 14),
      ),
    );
  }

  static BoxDecoration orangeCardDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [primaryOrange, primaryOrange.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: primaryOrange.withOpacity(0.3),
        blurRadius: 15,
        offset: const Offset(0, 8),
      )
    ],
  );

  static BoxDecoration whiteCardDecoration = BoxDecoration(
    color: cardWhite,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(
        color: cardShadow,
        blurRadius: 10,
        offset: Offset(0, 4),
      )
    ],
  );
}
