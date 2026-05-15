// Vika typography scale — Premium Ivory.
//
// Single family: **Be Vietnam Pro** (bundled). All sizes, weights, and
// styles defined here. New screens should pull text styles via
// `VikaType.X(context)` instead of constructing inline TextStyles.
//
// ─── Vietnamese-aware line heights ──────────────────────────────────────
// Vietnamese stacked diacritics — `ấ ầ ẩ ẫ ậ ổ ỗ ộ ằ ẳ ẵ ặ` — clip at the
// default English line-height of ~1.2. Required minimums:
//
//   12–16sp body         → height 1.45
//   18–24sp heading      → height 1.30
//   28–48sp display      → height 1.15  (minimum)
//   hero numerals only*  → height 0.95  (numerals don't carry diacritics)
//   single-line labels   → height 1.20
//
// *Used only for stat values like `74%` or `+14` — never for any text
//  containing Vietnamese characters.

import 'package:flutter/material.dart';

abstract final class VikaType {
  static const String _family = 'BeVietnamPro';

  // ─── Display ────────────────────────────────────────────────────────────

  /// 48sp / italic 800. Hero numerals, biggest editorial italic moments.
  /// Use only on text that does NOT contain stacked Vietnamese diacritics
  /// (the 0.95 height clips them); e.g. `+14`, `74%`, `8`.
  static const TextStyle display1 = TextStyle(
    fontFamily: _family,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    letterSpacing: -2,
    height: 0.95,
  );

  /// 32sp / italic 800 — page hero italic ("Tuần 03", "Khoẻ hơn rõ rệt.").
  static const TextStyle display2 = TextStyle(
    fontFamily: _family,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    letterSpacing: -1.4,
    height: 1.15,
  );

  /// 24sp / 700 upright — section display titles ("Đi từng tuần.").
  static const TextStyle display3 = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.15,
  );

  // ─── Heading ────────────────────────────────────────────────────────────

  /// 20sp / 700 — primary card headlines.
  static const TextStyle heading1 = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
  );

  /// 18sp / 700 — section subheads.
  static const TextStyle heading2 = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // ─── Body ───────────────────────────────────────────────────────────────

  static const TextStyle bodyLg = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  // ─── Labels (uppercase tracked) ────────────────────────────────────────

  /// 13sp / 700 — for the "01 / 02" index numerals and related primary labels.
  static const TextStyle labelLg = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
  );

  /// 11sp / 800 / tracked 1.6 — eyebrow voice ("HÔM NAY · BUỔI 03").
  /// Color routes through `inkSoft` (NOT inkFaint) per accessibility rules.
  static const TextStyle label = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    height: 1.2,
  );

  /// 9sp / 800 / tracked 1.6 — micro labels at the edge of legibility.
  static const TextStyle labelSm = TextStyle(
    fontFamily: _family,
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    height: 1.2,
  );

  // ─── Buttons ────────────────────────────────────────────────────────────

  /// 14sp / 800 italic — pill CTAs ("Bắt đầu Buổi 03").
  static const TextStyle button = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Tabular figures helper for any TextStyle that needs column-aligned
  /// numerals. Apply via `.copyWith(fontFeatures: VikaType.tabular)`.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // ─── Text scaler clamp ────────────────────────────────────────────────
  // Wrap MaterialApp.builder's child with a MediaQuery override that clamps
  // the user's preferred text scale to [0.9, 1.3]. Respects accessibility
  // settings within reason; stops 2× scales from breaking the JSX-tight
  // layouts.

  static const double minScale = 0.9;
  static const double maxScale = 1.3;

  /// Apply to `MaterialApp.builder`'s child.
  static Widget clampTextScaler(BuildContext context, Widget? child) {
    final original = MediaQuery.textScalerOf(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: original.clamp(
          minScaleFactor: minScale,
          maxScaleFactor: maxScale,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

