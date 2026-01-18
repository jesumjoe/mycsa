import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primaryNavy = Color(0xFF052659); // Deep Navy
  static const Color backgroundDark = Color(0xFF021024); // Darker Navy/Black
  static const Color accentBlue = Color(0xFF5483B3); // Medium Blue
  static const Color lightBlue = Color(0xFF7DA0CA); // Light Blue
  static const Color paleBlue = Color(0xFFC1E8FF); // Very Light Blue
  static const Color white = Colors.white;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryNavy,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryNavy,
        onPrimary: white,
        secondary: accentBlue,
        onSecondary: white,
        surface: primaryNavy, 
        onSurface: white,
        background: backgroundDark,
        onBackground: white,
      ),

      // Typography
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: white,
          displayColor: white,
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: white),
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Input Decoration (TextFields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryNavy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightBlue),
        hintStyle: TextStyle(color: lightBlue.withOpacity(0.7)),
        prefixIconColor: lightBlue,
        suffixIconColor: lightBlue,
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: white,
          elevation: 5,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),

      // OutlinedButton Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: paleBlue,
          side: const BorderSide(color: accentBlue),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentBlue,
        foregroundColor: white,
      ),
    );
  }
}
