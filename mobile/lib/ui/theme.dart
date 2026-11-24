import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF07152A);
  static const navy2 = Color(0xFF0F2544);
  static const navy3 = Color(0xFF14305A);
  static const emerald = Color(0xFF12A372);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0x33D4AF37);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    brightness: b,
    primary: AppColors.emerald,
    secondary: AppColors.gold,
    surface: dark ? AppColors.navy2 : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: dark ? AppColors.navy : const Color(0xFFF3F6F4),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.navy : const Color(0xFFF3F6F4),
      foregroundColor: dark ? Colors.white : AppColors.navy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w700,
          color: dark ? Colors.white : AppColors.navy),
    ),
    cardTheme: CardThemeData(
      color: dark ? AppColors.navy2 : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dark ? const Color(0xFF1E3B66) : const Color(0xFFDCE5E0))),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0A1C36) : Colors.white,
      indicatorColor: AppColors.goldSoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF0B1F3A) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

const heroGradient = LinearGradient(
  colors: [Color(0xFF0E8A5F), Color(0xFF0B5E52), Color(0xFF0B2A4A)],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);
