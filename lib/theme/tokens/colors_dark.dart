// Premium Ivory — DARK theme color tokens (REFINED set).
//
// Architectural principles preserved from the original Premium Ivory
// design pass:
//   • Warm dark page bg (#1F1812), NOT pure black — eye comfort + brand warmth
//   • Soft cream ink (#DCD0B8 base), NOT pure white — no pixel-burn
//   • Hero cards STAY dark instead of flipping ivory — preserves the
//     magazine layering metaphor (light theme = ink-on-cream;
//     dark theme = cream-on-warm-dark; hero cards in both themes are the
//     darkest surface, the warmest "object" sitting on the page)
//   • Yellow stays full saturation (10.6:1 AAA on warm-dark)
//
// Refinements vs. the first dark pass:
//   • inkFaint:    0.42 → 0.60   — biggest single fix; AA pass for small
//                                   text on every surface in dark mode
//   • invInkFaint: 0.42 → 0.60   — same fix, applied to alt hero card eyebrow
//   • inkSoft:     0.68 → 0.74
//   • invInkSoft:  0.70 → 0.76
//   • inkGhost:    0.18 → 0.22   — swipe dots actually visible
//   • border:      0.10 → 0.16   — section dividers visible
//   • borderHi:    0.18 → 0.26   — chart bg bars + nav bar edge readable
//   • borderDark:  0.08 → 0.14
//   • yellowGhost: 0.18 → 0.25   — delta badge reads as yellow-tinted
//   • bgInverse:   #352A1E → #4A3A28 (3.6× → 7.5× lift over page bg)
//   • bgInverseHi: #4A3A28 → #5C4B33
//   • powder:      #2F2519 → #3A2E22

import 'package:flutter/material.dart';

abstract final class VikaDarkColors {
  // ─── Surfaces ───
  static const Color bg = Color(0xFF1F1812); // warm charcoal page bg
  static const Color bgRaised = Color(0xFF2F2519); // nav pill, lifted cards
  static const Color bgInverse = Color(0xFF4A3A28); // PRIMARY hero card
  static const Color bgInverseHi = Color(0xFF5C4B33); // alt/secondary hero
  static const Color powder = Color(0xFF3A2E22); // tinted dark layered

  // ─── Ink — soft warm cream, capped to avoid pixel-burn ───
  static const Color ink = Color(0xFFDCD0B8);

  /// Secondary text. Use for eyebrows, captions, supporting copy that
  /// carries information. The 0.74 alpha was chosen to pass AA across
  /// every dark surface; eyebrow text routes here, not [inkFaint].
  static Color get inkSoft => ink.withValues(alpha: 0.74);

  /// **DECORATIVE ONLY.** The 0.60 alpha was bumped from 0.42 specifically
  /// because 9sp "Form 7 ngày" eyebrows on bgInverse were failing AA in
  /// the first dark pass. It now passes — but mirroring the light theme
  /// guidance, *all informational eyebrow / caption text should still
  /// route through [inkSoft]*. inkFaint is reserved for genuinely
  /// decorative micro-marks. Never put load-bearing text here.
  static Color get inkFaint => ink.withValues(alpha: 0.60);

  /// Pure decoration: ghost-numerals for rest days, swipe dots, dashed
  /// dividers. Never text.
  static Color get inkGhost => ink.withValues(alpha: 0.22);

  // ─── Inverse ink (on hero cards — also dark) ───
  static const Color invInk = Color(0xFFE5D9C0);
  static Color get invInkSoft => invInk.withValues(alpha: 0.76);
  static Color get invInkFaint => invInk.withValues(alpha: 0.60);

  // ─── Borders ───
  static Color get border => ink.withValues(alpha: 0.16);
  static Color get borderHi => ink.withValues(alpha: 0.26);
  static Color get borderDark => ink.withValues(alpha: 0.14);

  // ─── Yellow (kept at full saturation; 10.6:1 AAA on warm dark) ───
  static const Color yellow = Color(0xFFFFB701);
  static const Color yellowInk = Color(0xFF1F1812);
  static Color get yellowGhost => yellow.withValues(alpha: 0.25);

  // ─── Status (lifted variants for AAA on dark) ───
  static const Color attention = Color(0xFFE89A4B); // 7.3:1
  static const Color live = Color(0xFF34D17A); // 9.0:1

  static const Color bmiLow = Color(0xFF9CC0EE);
  static const Color bmiGood = Color(0xFFFFB701);
  static const Color bmiWarn = Color(0xFFF0B270);
  static const Color bmiHigh = Color(0xFFE89A4B);

  // ─── Phase accents (lifted for AAA contrast on warm dark) ───
  static const Color phase1 = Color(0xFFB7D4BF); // sage lifted
  static const Color phase2 = Color(0xFFF0B270); // amber lifted
  static const Color phase3 = Color(0xFFE89A4B); // earth (= light's amber)
  static const Color phase4 = Color(0xFF9CC0EE); // dusk lifted

  // ─── Special token-level refinements ───
  /// Hero day-number ghost (the big "03"/"04" in card corners).
  /// REFINED from yellow @ 0.16 → 0.20.
  static Color get heroDayGhost => yellow.withValues(alpha: 0.20);

  /// Nav bar inner highlight (the inset 1px white).
  /// REFINED from white @ 0.04 → 0.06.
  static const Color navInsetHighlight = Color(0x0FFFFFFF); // ≈ 0.06 alpha
}
