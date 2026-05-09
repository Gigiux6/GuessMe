import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFFF007F); // Neon Pink
  static const Color secondaryColor = Color(0xFFFFFF00); // Yellow
  static const Color cyanColor = Color(0xFF00FFFF); // Cyan
  static const Color accentColor = Color(0xFF39FF14); // Acid Green
  static const Color backgroundColor = Color(0xFF0A0F24); // Midnight Blue
  static const Color surfaceColor = Color(0xFF151B38);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  static ThemeData getTheme(bool isDarkMode) {
    final Brightness brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final Color bg = isDarkMode ? backgroundColor : cyanColor;
    final Color surface = isDarkMode ? surfaceColor : Colors.grey[100]!;
    final Color text = isDarkMode ? Colors.white : Colors.black;

    return ThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        onPrimary: Colors.black,
        secondary: secondaryColor,
        onSecondary: Colors.black,
        surface: surface,
        onSurface: text,
        error: Colors.red,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.fredokaTextTheme(
        isDarkMode ? ThemeData.dark().textTheme : ThemeData.light().textTheme
      ).copyWith(
        displayLarge: GoogleFonts.luckiestGuy(
          fontSize: 36,
          color: primaryColor,
          letterSpacing: 2,
        ),
        headlineMedium: GoogleFonts.luckiestGuy(
          fontSize: 24,
          color: secondaryColor,
          letterSpacing: 1.5,
        ),
        titleLarge: GoogleFonts.luckiestGuy(
          fontSize: 20,
          color: text,
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: secondaryColor, width: 3),
        ),
        labelStyle: TextStyle(color: isDarkMode ? textSecondary : Colors.black54),
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        elevation: 0,
      ),
    );
  }
}
