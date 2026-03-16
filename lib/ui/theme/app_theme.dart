import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Agropecuaria Las Marías)
  static const Color primaryOrange = Color(0xFFBA4817); // Naranja Corporativo
  static const Color primaryYellow = Color(0xFFE5A102); // Amarillo Institucional
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);
  
  static const Color backgroundWhite = Color(0xFFF8F9FA); 
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF757575);
  static const Color cardShadow = Color(0x0A000000);
  
  static const Color expenseRed = Color(0xFFD32F2F);
  static const Color incomeGreen = Color(0xFF388E3C);

  static LinearGradient get headerGradient => const LinearGradient(
    colors: [
      pureBlack,
      Color(0xFF1A1A1A),
      Color(0xFF2C2C2C),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get buttonGradient => const LinearGradient(
    colors: [
      primaryOrange,
      primaryYellow,
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundWhite,
      primaryColor: primaryOrange,
      textTheme: GoogleFonts.montserratTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: pureBlack),
        titleTextStyle: GoogleFonts.montserrat(
          color: pureBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        secondary: primaryYellow,
        surface: cardWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryOrange,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static BoxDecoration orangeCardDecoration = BoxDecoration(
    gradient: buttonGradient,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: primaryOrange.withOpacity(0.2),
        blurRadius: 12,
        offset: const Offset(0, 6),
      )
    ],
  );

  static BoxDecoration whiteCardDecoration = BoxDecoration(
    color: cardWhite,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.black.withOpacity(0.05)),
    boxShadow: const [
      BoxShadow(
        color: cardShadow,
        blurRadius: 10,
        offset: Offset(0, 4),
      )
    ],
  );
}
