// Border-radius scale for Premium Ivory main-app screens.
//
// Hierarchy:
//   r4-r12  → small inline elements (chips, status pills, mini cards)
//   r16-r20 → list rows, secondary cards
//   r24-r28 → hero cards (warm-dark, the "important" surfaces)
//   r999    → full pill (CTAs, nav capsule, badge dots)

import 'package:flutter/widgets.dart';

abstract final class VikaRadius {
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r28 = 28;
  static const double r999 = 999;

  // BorderRadius helpers — saves a few characters at every call site.
  static const BorderRadius all4 = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius all8 = BorderRadius.all(Radius.circular(r8));
  static const BorderRadius all12 = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius all16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius all20 = BorderRadius.all(Radius.circular(r20));
  static const BorderRadius all24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius all28 = BorderRadius.all(Radius.circular(r28));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(r999));
}
