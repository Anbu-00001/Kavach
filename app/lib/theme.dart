// theme.dart — palette (light/dark), risk colors, type. Ported from the Kavach design bundle.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Color hx(String h) {
  h = h.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

/// Hanken Grotesque text style helper.
TextStyle kfont(double size, FontWeight w, Color c,
        {double? height, double spacing = 0}) =>
    GoogleFonts.getFont('Hanken Grotesque',
        fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: spacing);

/// Warm "paper" palette; risk colors fixed to kavach-core taxonomy.
class Pal {
  final bool dark;
  final Color bg, surface, surface2, surfaceUp, ink, inkSoft, inkFaint, line, lineSoft;
  final Color brand, brandInk, brandTint, onColor, accent;
  final Color safe, caution, high, safeTint, cautionTint, highTint;
  final List<BoxShadow> shadow;
  const Pal({
    required this.dark,
    required this.bg, required this.surface, required this.surface2, required this.surfaceUp,
    required this.ink, required this.inkSoft, required this.inkFaint,
    required this.line, required this.lineSoft,
    required this.brand, required this.brandInk, required this.brandTint,
    required this.onColor, required this.accent,
    required this.safe, required this.caution, required this.high,
    required this.safeTint, required this.cautionTint, required this.highTint,
    required this.shadow,
  });
}

Pal palette(bool dark, Color accent) {
  if (dark) {
    return Pal(
      dark: true,
      bg: hx('#15110D'), surface: hx('#211C16'), surface2: hx('#2C261E'), surfaceUp: hx('#322B22'),
      ink: hx('#F7F0E6'), inkSoft: hx('#BCAF9C'), inkFaint: hx('#867B6A'),
      line: hx('#3A332A'), lineSoft: hx('#2C261E'),
      brand: hx('#34C0CB'), brandInk: hx('#0B2E31'), brandTint: hx('#16302F'),
      onColor: hx('#1A130C'), accent: accent,
      safe: hx('#2bb56b'), caution: hx('#f5c233'), high: hx('#ff5a64'),
      safeTint: hx('#163024'), cautionTint: hx('#332b12'), highTint: hx('#3a1c1f'),
      shadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 50, offset: const Offset(0, 18))],
    );
  }
  return Pal(
    dark: false,
    bg: hx('#FBF6EF'), surface: hx('#FFFFFF'), surface2: hx('#F4ECE0'), surfaceUp: hx('#FFFFFF'),
    ink: hx('#241F19'), inkSoft: hx('#6E6557'), inkFaint: hx('#A2998A'),
    line: hx('#E9DECF'), lineSoft: hx('#F0E8DB'),
    brand: accent, brandInk: hx('#063E44'), brandTint: hx('#E1F0F1'),
    onColor: hx('#FFFFFF'), accent: accent,
    safe: hx('#1f9d55'), caution: hx('#f0b400'), high: hx('#e63946'),
    safeTint: hx('#E4F4EA'), cautionTint: hx('#FBF0D2'), highTint: hx('#FBE4E6'),
    shadow: [BoxShadow(color: hx('#4A3A26').withValues(alpha: 0.13), blurRadius: 44, offset: const Offset(0, 16))],
  );
}

/// Inherited theme carrying palette + text scale (mirrors the design's ThemeCtx).
class KavachTheme extends InheritedWidget {
  final Pal pal;
  final double scale;
  const KavachTheme({super.key, required this.pal, required this.scale, required super.child});
  static KavachTheme of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<KavachTheme>()!;
  @override
  bool updateShouldNotify(KavachTheme old) => old.scale != scale || old.pal.dark != pal.dark || old.pal.accent != pal.accent;
}
