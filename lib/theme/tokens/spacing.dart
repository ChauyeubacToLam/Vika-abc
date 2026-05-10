// 4pt baseline grid for all padding / margin / gap values in the
// Premium Ivory main-app screens.
//
// Use these via `VikaSpace.s12` etc. — every magic number padding
// in widget code should resolve to one of these tokens (or a direct
// `r.w(...)` for responsive scaling, which then takes a token
// at the source).

abstract final class VikaSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Page horizontal padding (the magazine "gutter").
  /// Use as the outer padding of every main-app screen.
  static const double pageGutter = s24;

  /// Internal padding for hero cards (slightly tighter than gutter).
  static const double heroPadding = 22;
}
