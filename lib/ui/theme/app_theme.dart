import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/models/company_config_model.dart';

class AppTheme {
  // Brand Colors (Defaults for Agropecuaria Las Marías)
  static const Color defaultPrimary = Color(0xFFBA4817); // Original ALM Orange
  static const Color defaultSecondary = Color(0xFFE5A102); // Original ALM Yellow
  
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
    colors: [pureBlack, Color(0xFF1A1A1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    final tint = Color.alphaBlend(defaultPrimary.withOpacity(0.10), pureWhite);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: tint,
      primaryColor: defaultPrimary,
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
        seedColor: defaultPrimary,
        primary: defaultPrimary,
        secondary: defaultSecondary,
        surface: cardWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: defaultPrimary,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ThemeData buildDynamicTheme(CompanyConfigModel? config) {
    if (config == null) return lightTheme;
    
    final primary = config.primaryColor;
    final secondary = config.secondaryColor;
    final tint = Color.alphaBlend(primary.withOpacity(0.10), pureWhite);

    return lightTheme.copyWith(
      scaffoldBackgroundColor: tint,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: cardWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }

  static const Color primaryOrange = defaultPrimary;
  static const Color primaryYellow = defaultSecondary;

  static BoxDecoration get whiteCardDecoration => BoxDecoration(
    color: cardWhite,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: cardShadow, offset: Offset(0, 4), blurRadius: 12)],
  );

  static BoxDecoration get orangeCardDecoration => BoxDecoration(
    gradient: const LinearGradient(colors: [primaryOrange, primaryYellow]),
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: cardShadow, offset: Offset(0, 4), blurRadius: 12)],
  );

  static LinearGradient get buttonGradient => const LinearGradient(
    colors: [primaryOrange, primaryYellow],
  );
}
