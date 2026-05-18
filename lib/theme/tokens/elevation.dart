// Elevation tokens.
//
// IMPORTANT: Vika's primary elevation cue is **warmth shift**, not shadow.
// Light theme:  bgRaised on bg → cards feel raised because they're warmer.
// Dark theme:   bgInverse on bg → cards feel raised because they're warmer.
//
// Shadows are reserved for two specific cases only:
//   • Yellow CTA pills (they need to "float" because they're the
//     primary interaction; shadow keeps them visually buoyant)
//   • Bottom nav capsule (frosted glass float)
//
// Drop-shadow style does not work the same in dark mode (a warm-dark
// surface casting shadow on a warm-dark background is invisible).
// In dark mode we substitute a **subtle inner highlight** ring.

import 'package:flutter/material.dart';

abstract final class VikaElevation {
  // ─── Yellow CTA shadow (light theme) ───
  static const List<BoxShadow> yellowCtaLight = [
    BoxShadow(
      color: Color(0x59FFB701), // yellow @ 0.35
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];

  /// Yellow CTA in dark mode: shadow is invisible against warm-dark bg,
  /// so we use a subtle yellow glow ring at the top edge to give the
  /// pill the same "lit from below" feeling.
  static const List<BoxShadow> yellowCtaDark = [
    BoxShadow(
      color: Color(0x40FFB701), // yellow @ 0.25
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  // ─── Bottom nav capsule shadow ───
  static const List<BoxShadow> navCapsuleLight = [
    BoxShadow(
      color: Color(0x1A1F1812), // ink @ 0.10
      blurRadius: 28,
      offset: Offset(0, 8),
    ),
  ];

  /// Dark mode: ink-on-dark shadow is invisible. Use a darker shadow
  /// from beneath the bg to push the capsule forward, plus an inset
  /// highlight at the top.
  static const List<BoxShadow> navCapsuleDark = [
    BoxShadow(
      color: Color(0x66000000), // soft black @ 0.40 — deeper than bg
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
