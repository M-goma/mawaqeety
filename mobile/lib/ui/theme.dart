import 'package:flutter/material.dart';

/// A colour style. Each one works in both night and day modes.
class Palette {
  final String id, nameAr;
  final Color bg, surface, surface2, primary, accent, accentLight, heroText;
  final List<Color> hero;
  const Palette({
    required this.id, required this.nameAr, required this.bg, required this.surface, required this.surface2,
    required this.primary, required this.accent, required this.accentLight, required this.heroText, required this.hero,
  });

  Color get accentSoft => accent.withValues(alpha: 0.2);
  Color get border => Color.lerp(surface, primary, 0.18)!;
  Color get navBar => Color.lerp(bg, surface, 0.45)!;
  Color get input => Color.lerp(bg, surface, 0.6)!;
  Color get lightBg => Color.lerp(Colors.white, primary, 0.05)!;
  Color get lightBorder => Color.lerp(Colors.white, primary, 0.16)!;
}

const palettes = <Palette>[
  Palette(id: 'emerald', nameAr: 'زمرّدي وذهبي', bg: Color(0xFF07152A), surface: Color(0xFF0F2544), surface2: Color(0xFF14305A),
      primary: Color(0xFF12A372), accent: Color(0xFFD4AF37), accentLight: Color(0xFFE9C75A), heroText: Color(0xFFCCE9DD),
      hero: [Color(0xFF0E8A5F), Color(0xFF0B5E52), Color(0xFF0B2A4A)]),
  Palette(id: 'royal', nameAr: 'أزرق ملكي', bg: Color(0xFF060E24), surface: Color(0xFF0E1B3D), surface2: Color(0xFF16275A),
      primary: Color(0xFF3B82F6), accent: Color(0xFFF5C451), accentLight: Color(0xFFFFD873), heroText: Color(0xFFD6E4FF),
      hero: [Color(0xFF2563EB), Color(0xFF1E3A8A), Color(0xFF0B1437)]),
  Palette(id: 'violet', nameAr: 'بنفسجي ليلي', bg: Color(0xFF110A24), surface: Color(0xFF1D1438), surface2: Color(0xFF2A1D52),
      primary: Color(0xFF8B5CF6), accent: Color(0xFFF0B90B), accentLight: Color(0xFFFFD25C), heroText: Color(0xFFE6DCFF),
      hero: [Color(0xFF7C3AED), Color(0xFF4C1D95), Color(0xFF1A0F33)]),
  Palette(id: 'maroon', nameAr: 'عنّابي', bg: Color(0xFF1A0A0E), surface: Color(0xFF2A1218), surface2: Color(0xFF3B1A22),
      primary: Color(0xFFC2415D), accent: Color(0xFFE8B86A), accentLight: Color(0xFFF5CF8C), heroText: Color(0xFFF8DCE2),
      hero: [Color(0xFFB0304F), Color(0xFF6E1A2F), Color(0xFF2A0D15)]),
  Palette(id: 'desert', nameAr: 'رملي صحراوي', bg: Color(0xFF1A130B), surface: Color(0xFF2A2014), surface2: Color(0xFF3A2C1C),
      primary: Color(0xFFD08C3C), accent: Color(0xFFF2D49B), accentLight: Color(0xFFF8E2B6), heroText: Color(0xFFF6E6CC),
      hero: [Color(0xFFC07A2C), Color(0xFF7A4A1C), Color(0xFF2B1D0E)]),
  Palette(id: 'turquoise', nameAr: 'فيروزي', bg: Color(0xFF041A1D), surface: Color(0xFF0A2A2F), surface2: Color(0xFF103A40),
      primary: Color(0xFF14B8A6), accent: Color(0xFFF7C948), accentLight: Color(0xFFFFDD7A), heroText: Color(0xFFD2F5F0),
      hero: [Color(0xFF0D9488), Color(0xFF115E59), Color(0xFF062A2D)]),
  Palette(id: 'amoled', nameAr: 'أسود فحمي', bg: Color(0xFF000000), surface: Color(0xFF111111), surface2: Color(0xFF1C1C1C),
      primary: Color(0xFF22C55E), accent: Color(0xFFE5C158), accentLight: Color(0xFFF0D47A), heroText: Color(0xFFDDDDDD),
      hero: [Color(0xFF1F1F1F), Color(0xFF121212), Color(0xFF000000)]),
  Palette(id: 'sunset', nameAr: 'غروب', bg: Color(0xFF1B0F17), surface: Color(0xFF2B1724), surface2: Color(0xFF3C2032),
      primary: Color(0xFFF97316), accent: Color(0xFFFCD34D), accentLight: Color(0xFFFDE68A), heroText: Color(0xFFFFE4D2),
      hero: [Color(0xFFEA580C), Color(0xFF9D174D), Color(0xFF2E1065)]),
  Palette(id: 'olive', nameAr: 'زيتوني', bg: Color(0xFF0E140A), surface: Color(0xFF1A2414), surface2: Color(0xFF26341D),
      primary: Color(0xFF84A93A), accent: Color(0xFFE4C46A), accentLight: Color(0xFFF0D88E), heroText: Color(0xFFE5EFD2),
      hero: [Color(0xFF6B8E23), Color(0xFF3F5A1A), Color(0xFF151F0D)]),
  Palette(id: 'silver', nameAr: 'فضّي', bg: Color(0xFF0F1216), surface: Color(0xFF1A1F26), surface2: Color(0xFF252C35),
      primary: Color(0xFF94A3B8), accent: Color(0xFF7DD3FC), accentLight: Color(0xFFA5E1FD), heroText: Color(0xFFE2E8F0),
      hero: [Color(0xFF64748B), Color(0xFF334155), Color(0xFF0F172A)]),
];

Palette paletteById(String id) => palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

/// The active palette's colours (names kept from the original design).
class AppColors {
  static Palette current = palettes.first;
  static Color get navy => current.bg;
  static Color get navy2 => current.surface;
  static Color get navy3 => current.surface2;
  static Color get emerald => current.primary;
  static Color get gold => current.accent;
  static Color get goldSoft => current.accentSoft;
  static Color get goldLight => current.accentLight;
  static Color get heroText => current.heroText;
}

LinearGradient get heroGradient => LinearGradient(
      colors: AppColors.current.hero,
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    );

ThemeData buildTheme(Brightness b, Palette p) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: b,
    primary: p.primary,
    secondary: p.accent,
    surface: dark ? p.surface : Colors.white,
  );
  final bg = dark ? p.bg : p.lightBg;
  final fg = dark ? Colors.white : p.bg;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w700, color: fg),
    ),
    cardTheme: CardThemeData(
      color: dark ? p.surface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dark ? p.border : p.lightBorder)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? p.navBar : Colors.white,
      indicatorColor: p.accentSoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? p.input : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
