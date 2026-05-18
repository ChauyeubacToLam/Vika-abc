// Context-aware color accessor for the Premium Ivory main app.
//
// Why not `Theme.of(context).colorScheme.X` directly?
//   `MaterialApp.theme` is still pinned to `VFTheme.lightTheme` because
//   ~20 legacy screens (auth, exercise, rest, summary, onboarding) depend
//   on its jade-green palette. We can't flip that wholesale in this PR.
//
// Instead, this `VikaColors` class reads the device's platform brightness
// and returns the right token set. Premium Ivory main-app screens
// (Home, Plan, Progress, Profile, Library) pull from here:
//
// ```dart
// final c = VikaColors.of(context);
// Container(color: c.bg, ...)
// ```
//
// When the user's OS theme flips, `MediaQuery.platformBrightnessOf` updates
// and a rebuild happens — every screen re-resolves the right palette.
// Legacy screens remain on VFTheme; the two systems coexist until we
// migrate them in a future PR.

import 'package:flutter/material.dart';

import 'tokens/colors_dark.dart';
import 'tokens/colors_light.dart';

class VikaColors {
  const VikaColors._({
    required this.bg,
    required this.bgRaised,
    required this.bgInverse,
    required this.bgInverseHi,
    required this.powder,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.inkGhost,
    required this.invInk,
    required this.invInkSoft,
    required this.invInkFaint,
    required this.border,
    required this.borderHi,
    required this.borderDark,
    required this.yellow,
    required this.yellowInk,
    required this.yellowGhost,
    required this.attention,
    required this.live,
    required this.bmiLow,
    required this.bmiGood,
    required this.bmiWarn,
    required this.bmiHigh,
    required this.phase1,
    required this.phase2,
    required this.phase3,
    required this.phase4,
    required this.isDark,
  });

  // Surfaces
  final Color bg;
  final Color bgRaised;
  final Color bgInverse;
  final Color bgInverseHi;
  final Color powder;

  // Ink
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color inkGhost;

  // Inverse ink (on warm-dark hero cards)
  final Color invInk;
  final Color invInkSoft;
  final Color invInkFaint;

  // Borders
  final Color border;
  final Color borderHi;
  final Color borderDark;

  // Yellow accent
  final Color yellow;
  final Color yellowInk;
  final Color yellowGhost;

  // Status
  final Color attention;
  final Color live;
  final Color bmiLow;
  final Color bmiGood;
  final Color bmiWarn;
  final Color bmiHigh;

  // Phase accents
  final Color phase1;
  final Color phase2;
  final Color phase3;
  final Color phase4;

  /// True when the active palette is the dark token set.
  final bool isDark;

  // ─── Light + dark instances ───
  static final VikaColors light = VikaColors._(
    bg: VikaLightColors.bg,
    bgRaised: VikaLightColors.bgRaised,
    bgInverse: VikaLightColors.bgInverse,
    bgInverseHi: VikaLightColors.bgInverseHi,
    powder: VikaLightColors.powder,
    ink: VikaLightColors.ink,
    inkSoft: VikaLightColors.inkSoft,
    inkFaint: VikaLightColors.inkFaint,
    inkGhost: VikaLightColors.inkGhost,
    invInk: VikaLightColors.invInk,
    invInkSoft: VikaLightColors.invInkSoft,
    invInkFaint: VikaLightColors.invInkFaint,
    border: VikaLightColors.border,
    borderHi: VikaLightColors.borderHi,
    borderDark: VikaLightColors.borderDark,
    yellow: VikaLightColors.yellow,
    yellowInk: VikaLightColors.yellowInk,
    yellowGhost: VikaLightColors.yellowGhost,
    attention: VikaLightColors.attention,
    live: VikaLightColors.live,
    bmiLow: VikaLightColors.bmiLow,
    bmiGood: VikaLightColors.bmiGood,
    bmiWarn: VikaLightColors.bmiWarn,
    bmiHigh: VikaLightColors.bmiHigh,
    phase1: VikaLightColors.phase1,
    phase2: VikaLightColors.phase2,
    phase3: VikaLightColors.phase3,
    phase4: VikaLightColors.phase4,
    isDark: false,
  );

  static final VikaColors dark = VikaColors._(
    bg: VikaDarkColors.bg,
    bgRaised: VikaDarkColors.bgRaised,
    bgInverse: VikaDarkColors.bgInverse,
    bgInverseHi: VikaDarkColors.bgInverseHi,
    powder: VikaDarkColors.powder,
    ink: VikaDarkColors.ink,
    inkSoft: VikaDarkColors.inkSoft,
    inkFaint: VikaDarkColors.inkFaint,
    inkGhost: VikaDarkColors.inkGhost,
    invInk: VikaDarkColors.invInk,
    invInkSoft: VikaDarkColors.invInkSoft,
    invInkFaint: VikaDarkColors.invInkFaint,
    border: VikaDarkColors.border,
    borderHi: VikaDarkColors.borderHi,
    borderDark: VikaDarkColors.borderDark,
    yellow: VikaDarkColors.yellow,
    yellowInk: VikaDarkColors.yellowInk,
    yellowGhost: VikaDarkColors.yellowGhost,
    attention: VikaDarkColors.attention,
    live: VikaDarkColors.live,
    bmiLow: VikaDarkColors.bmiLow,
    bmiGood: VikaDarkColors.bmiGood,
    bmiWarn: VikaDarkColors.bmiWarn,
    bmiHigh: VikaDarkColors.bmiHigh,
    phase1: VikaDarkColors.phase1,
    phase2: VikaDarkColors.phase2,
    phase3: VikaDarkColors.phase3,
    phase4: VikaDarkColors.phase4,
    isDark: true,
  );

  /// Resolve from a `BuildContext`. Uses
  /// `MediaQuery.platformBrightnessOf` — automatically tracks system
  /// dark mode toggles. If the user has set a manual override in-app
  /// (future feature), we'll inject an InheritedWidget here.
  static VikaColors of(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }
}

extension VikaColorsContext on BuildContext {
  /// Shorthand: `context.c.bg`.
  VikaColors get c => VikaColors.of(this);
}
