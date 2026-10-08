import 'package:flutter/material.dart';

class AppTheme {
  // SheRise Exact Web App Mobile Colors
  static const Color primaryRose = Color(0xFFF16F85);      // Web rose accent
  static const Color deepRose = Color(0xFFE11D48);         // Active category / badges
  static const Color brandRise = Color(0xFFDB2777);        // She'Rise' logo magenta
  static const Color darkSlate = Color(0xFF0F172A);        // Solid dark buttons & headers
  static const Color backgroundCream = Color(0xFFFAF7F7);  // Web mobile soft background
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color peachButton = Color(0xFFFDE6D2);      // "Send OTP" button background
  static const Color digilockerBlue = Color(0xFF1E3A8A);    // DigiLocker button
  static const Color textMuted = Color(0xFF64748B);        // Slate-500
  static const Color cardBorder = Color(0xFFF3E8EC);       // Soft rose border
  static const Color inputBorder = Color(0xFFF1E5E7);
  static const Color inputBg = Color(0xFFF9F6F6);

  static const Color emeraldGreen = Color(0xFF059669);
  static const Color amberGold = Color(0xFFD97706);
  static const Color errorRed = Color(0xFFEF4444);

  // Backward-compatible color aliases for existing widgets
  static const Color rosePrimary = deepRose;
  static const Color pinkPrimary = primaryRose;
  static const Color pinkSoft = Color(0xFFFCE7F3);
  static const Color roseLight = Color(0xFFFFF1F2);
  static const Color purplePrimary = Color(0xFF9333EA);
  static const Color textPrimary = darkSlate;
  static const Color textSecondary = textMuted;
  static const Color backgroundLight = backgroundCream;
  static const Color borderLight = cardBorder;
  static const Color divider = cardBorder;

  // Visual gradients and shadows
  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryRose, deepRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient rosePinkGradient = LinearGradient(
    colors: [primaryRose, deepRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardSoftGradient = LinearGradient(
    colors: [cardWhite, backgroundCream],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
  static const List<BoxShadow> glowPurpleShadow = [
    BoxShadow(
      color: Color(0x339333EA),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // Serif Title Style (Matching SheRise Web Logo & Headers)
  static TextStyle serifTitle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.bold,
    Color color = darkSlate,
  }) {
    return TextStyle(
      fontFamily: 'serif',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.5,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundCream,
      colorScheme: const ColorScheme.light(
        primary: deepRose,
        secondary: darkSlate,
        surface: cardWhite,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkSlate,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkSlate,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkSlate,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: deepRose, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}
