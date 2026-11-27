import 'package:flutter/material.dart';

/// A colour style. Each one works in both night and day modes.
class Palette {
  final String id, nameAr;
  final Color bg, surface, surface2, primary, accent, accentLight, heroText;
  final List<Color> hero;
  /// Optional tinted background and card colour for the light mode (e.g. beige for the coffee palettes).
  final Color? lightBase, lightCard, lightAccent;
  const Palette({
    required this.id, required this.nameAr, required this.bg, required this.surface, required this.surface2,
    required this.primary, required this.accent, required this.accentLight, required this.heroText, required this.hero,
    this.lightBase, this.lightCard, this.lightAccent,
  });

  Color get accentSoft => accent.withValues(alpha: 0.2);
  Color get border => Color.lerp(surface, primary, 0.18)!;
  Color get navBar => Color.lerp(bg, surface, 0.45)!;
  Color get input => Color.lerp(bg, surface, 0.6)!;
  Color get lightBg => lightBase ?? Color.lerp(Colors.white, primary, 0.05)!;
  Color get lightSurface => lightCard ?? Colors.white;
  Color get lightBorder => Color.lerp(lightSurface, primary, 0.16)!;
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
  // Coffee browns (beige in the light mode).
  Palette(id: 'mocha', nameAr: 'موكا', bg: Color(0xFF1E1511), surface: Color(0xFF2E211B), surface2: Color(0xFF3D2D24),
      primary: Color(0xFF9C6B4E), accent: Color(0xFFEBD3B0), accentLight: Color(0xFFF5E4C8), heroText: Color(0xFFF3E6D6),
      hero: [Color(0xFF8A5E45), Color(0xFF5E4033), Color(0xFF2A1D17)], lightBase: Color(0xFFE6DACC), lightCard: Color(0xFFF7F0E7), lightAccent: Color(0xFF8A5A3C)),
  Palette(id: 'latte', nameAr: 'لاتيه', bg: Color(0xFF2B2119), surface: Color(0xFF3B2E24), surface2: Color(0xFF4B3B2F),
      primary: Color(0xFFB48A64), accent: Color(0xFFF3E2C7), accentLight: Color(0xFFFAEEDB), heroText: Color(0xFFFFF4E6),
      hero: [Color(0xFFB08A6A), Color(0xFF7D5D47), Color(0xFF3B2C22)], lightBase: Color(0xFFEDE3D6), lightCard: Color(0xFFFBF6EF), lightAccent: Color(0xFF96683F)),
  Palette(id: 'cocoa', nameAr: 'كاكاو', bg: Color(0xFF170E0B), surface: Color(0xFF261813), surface2: Color(0xFF34221B),
      primary: Color(0xFF7A4A35), accent: Color(0xFFD9A57A), accentLight: Color(0xFFE8BF9A), heroText: Color(0xFFF2DDD0),
      hero: [Color(0xFF6E4230), Color(0xFF462A1F), Color(0xFF1C110D)], lightBase: Color(0xFFE2D4C9), lightCard: Color(0xFFF5EEE8), lightAccent: Color(0xFF7A4A35)),
  Palette(id: 'caramel', nameAr: 'كراميل', bg: Color(0xFF1F140A), surface: Color(0xFF2F2012), surface2: Color(0xFF402C19),
      primary: Color(0xFFC98A45), accent: Color(0xFFF7DDB0), accentLight: Color(0xFFFCEBCB), heroText: Color(0xFFFFEEDB),
      hero: [Color(0xFFC07F3D), Color(0xFF85552A), Color(0xFF2E1F10)], lightBase: Color(0xFFF0E3D0), lightCard: Color(0xFFFCF7EF), lightAccent: Color(0xFFA8692C)),
  // More colours.
  Palette(id: 'rose', nameAr: 'وردي ترابي', bg: Color(0xFF1C1214), surface: Color(0xFF2C1D21), surface2: Color(0xFF3B282D),
      primary: Color(0xFFC07A86), accent: Color(0xFFF2D0B6), accentLight: Color(0xFFF8E1CF), heroText: Color(0xFFFBE6EA),
      hero: [Color(0xFFB06C78), Color(0xFF7A4651), Color(0xFF2C1A1F)], lightBase: Color(0xFFF1E3E3), lightCard: Color(0xFFFCF6F6), lightAccent: Color(0xFFA4566A)),
  Palette(id: 'mint', nameAr: 'نعناعي', bg: Color(0xFF07171A), surface: Color(0xFF0E2629), surface2: Color(0xFF15363A),
      primary: Color(0xFF3CC7A0), accent: Color(0xFFFFE08A), accentLight: Color(0xFFFFEBB0), heroText: Color(0xFFD8F7EE),
      hero: [Color(0xFF2FB18D), Color(0xFF1C6E5E), Color(0xFF082224)]),
  Palette(id: 'navy', nameAr: 'كحلي بحري', bg: Color(0xFF050B16), surface: Color(0xFF0C1626), surface2: Color(0xFF132138),
      primary: Color(0xFF2F6FB0), accent: Color(0xFFE6E1D3), accentLight: Color(0xFFF2EEE4), heroText: Color(0xFFD9E6F5),
      hero: [Color(0xFF23578C), Color(0xFF173A60), Color(0xFF07101D)]),
  Palette(id: 'lavender', nameAr: 'لافندر', bg: Color(0xFF13111E), surface: Color(0xFF211D33), surface2: Color(0xFF2E2846),
      primary: Color(0xFF9D8BD8), accent: Color(0xFFF4D6A0), accentLight: Color(0xFFF9E4BF), heroText: Color(0xFFEDE7FF),
      hero: [Color(0xFF8C79CC), Color(0xFF5B4B91), Color(0xFF1C1730)], lightBase: Color(0xFFEDEAF6), lightCard: Color(0xFFFBFAFF), lightAccent: Color(0xFF6F5BB5)),
];

Palette paletteById(String id) => palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

/// Size of icons and tiles, chosen in Settings (small / medium / large).
class UiScale {
  static int size = 1;
  /// The whole interface is zoomed (text, icons, cards and spacing together).
  static double get zoom => const [0.86, 0.93, 1.0][size.clamp(0, 2)];
  /// Kept for older call sites: icons follow the global zoom now.
  static double get icon => 1.0;
}

/// Zooms the whole app by [UiScale.zoom]: lays it out on a larger virtual screen and scales it down to fit.
class AppZoom extends StatelessWidget {
  final Widget child;
  const AppZoom({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final f = UiScale.zoom;
    if (f == 1.0) return child;
    final mq = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / f, h = c.maxHeight / f;
      return FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: w,
          height: h,
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(w, h),
              padding: mq.padding / f,
              viewPadding: mq.viewPadding / f,
              viewInsets: mq.viewInsets / f,
            ),
            child: child,
          ),
        ),
      );
    });
  }
}

/// The active palette's colours (names kept from the original design).
class AppColors {
  static Palette current = palettes.first;
  static Color get navy => current.bg;
  static Color get navy2 => current.surface;
  static Color get navy3 => current.surface2;
  static Color get emerald => current.primary;
  /// True while the light mode is showing (set by the app builder).
  static bool light = false;
  static Color get gold => light && current.lightAccent != null ? current.lightAccent! : current.accent;
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
    surface: dark ? p.surface : p.lightSurface,
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
      color: dark ? p.surface : p.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dark ? p.border : p.lightBorder)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? p.navBar : p.lightSurface,
      indicatorColor: p.accentSoft,
      elevation: 12,
      shadowColor: Colors.black,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    // 3D: buttons and chips are raised with a shadow, the navigation bar casts one upward.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 6,
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      elevation: 3,
      pressElevation: 0,
      shadowColor: Colors.black,
      selectedShadowColor: Colors.black,
      selectedColor: p.primary,
      backgroundColor: dark ? Color.lerp(p.surface2, Colors.white, 0.05) : p.lightSurface,
      side: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.10) : p.lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: fg),
      secondaryLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
      checkmarkColor: Colors.white,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        backgroundColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.selected) ? p.primary : (dark ? p.surface : p.lightSurface)),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Colors.white : fg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? p.input : p.lightSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Raised "3D" surface: a soft top-to-bottom gradient, a light rim on top, and a deep drop shadow.
/// Drop-in for Material [Card] (same common parameters).
class Card3D extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final double radius;
  const Card3D({super.key, this.child, this.margin, this.color, this.shape, this.clipBehavior = Clip.antiAlias, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.current;
    final dark = _isDark(context);
    final base = dark ? p.surface : p.lightSurface;
    final top = dark ? Color.lerp(base, Colors.white, 0.07)! : base;
    final bottom = dark ? Color.lerp(base, Colors.black, 0.22)! : Color.lerp(base, p.primary, 0.04)!;
    final side = shape is RoundedRectangleBorder ? (shape as RoundedRectangleBorder).side : BorderSide.none;
    final r = BorderRadius.circular(radius);
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
          boxShadow: dark
              ? const [
                  BoxShadow(color: Color(0x8C000000), blurRadius: 16, offset: Offset(0, 9)),
                  BoxShadow(color: Color(0x59000000), blurRadius: 0, offset: Offset(0, 2.5)),
                ]
              : [BoxShadow(color: p.primary.withValues(alpha: 0.16), blurRadius: 14, offset: const Offset(0, 7))],
        ),
        child: Container(
          clipBehavior: clipBehavior,
          decoration: BoxDecoration(
            borderRadius: r,
            color: color,
            border: side != BorderSide.none
                ? Border.fromBorderSide(side)
                : Border(top: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.13) : p.lightBorder, width: 1)),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// Decoration for the big gradient "hero" cards: raised, with a shine on top and depth at the bottom.
BoxDecoration hero3D({double radius = 24}) => BoxDecoration(
      gradient: heroGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.28))),
      boxShadow: const [
        BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 12)),
        BoxShadow(color: Color(0x4D000000), blurRadius: 0, offset: Offset(0, 3)),
      ],
    );

/// A small raised icon tile (used in lists and grids).
class Tile3D extends StatelessWidget {
  final Widget child;
  final double size;
  final bool gold;
  const Tile3D({super.key, required this.child, this.size = 42, this.gold = false});
  @override
  Widget build(BuildContext context) {
    final p = AppColors.current;
    final dark = _isDark(context);
    final c1 = gold ? p.accentLight : (dark ? Color.lerp(p.surface2, Colors.white, 0.16)! : Color.lerp(p.lightSurface, p.primary, 0.10)!);
    final c2 = gold ? Color.lerp(p.accent, Colors.black, 0.3)! : (dark ? Color.lerp(p.surface, Colors.black, 0.25)! : Color.lerp(p.lightSurface, p.primary, 0.24)!);
    final size = this.size * UiScale.icon;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [c1, c2]),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.55 : 0.18), blurRadius: 8, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10), blurRadius: 0, offset: const Offset(0, 3)),
        ],
      ),
      child: Transform.scale(scale: UiScale.icon, child: child),
    );
  }
}
