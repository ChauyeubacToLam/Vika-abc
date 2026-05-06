import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class V5 {
  const V5._();

  static const bg = Color(0xFFF4EEE2);
  static const bgSoft = Color(0xFFEBE3D2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFBF6EA);

  static const heroBg = Color(0xFF1F1812);
  static const heroBgDeep = Color(0xFF15110D);

  static const ink = Color(0xFF2A1F12);
  static Color get inkSoft => ink.withValues(alpha: 0.62);
  static Color get inkFaint => ink.withValues(alpha: 0.38);
  static Color get inkDim => ink.withValues(alpha: 0.20);

  static const invInk = Color(0xFFFBF6EA);
  static Color get invInkSoft => invInk.withValues(alpha: 0.62);
  static Color get invInkFaint => invInk.withValues(alpha: 0.38);

  static const yellow = Color(0xFFFFB701);
  static const yellowDeep = Color(0xFFC18800);
  static Color get yellowSoft => yellow.withValues(alpha: 0.18);
  static const yellowInk = Color(0xFF1F1812);

  static Color get border => ink.withValues(alpha: 0.08);
  static Color get borderHi => ink.withValues(alpha: 0.14);
  static Color get heroBorder => Colors.white.withValues(alpha: 0.06);
  static Color get shadow => ink.withValues(alpha: 0.08);
  static Color get shadowDeep => ink.withValues(alpha: 0.18);

  static double scale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return (size.width / 390).clamp(0.88, 1.12).toDouble();
  }

  static TextStyle text(
    BuildContext context, {
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double? letterSpacing,
    double? height,
  }) {
    // Inter — Geist isn't shipped in google_fonts yet; Inter is its
    // predecessor (same Vercel design lineage) and the closest visual match.
    // Clean geometric feel, complete Vietnamese diacritic coverage.
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static BoxShadow cardShadow([double alpha = 0.08]) => BoxShadow(
        color: ink.withValues(alpha: alpha),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );

  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment(-0.8, -1),
        end: Alignment(1, 1),
        colors: [heroBg, heroBgDeep],
      );

  static String levelLabel(String? level) {
    return switch (level) {
      'advanced' => 'Nâng cao',
      'intermediate' => 'Trung cấp',
      _ => 'Người mới',
    };
  }
}
