// EditorialCloser — the magazine-style end-of-page bar. Hairline + uppercase
// wordmark ("VIKA · LỘ TRÌNH") + middle hairline + italic tagline on the
// right.
//
// Mirrors the closer pattern at the bottom of every screen in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';

class EditorialCloser extends StatelessWidget {
  const EditorialCloser({
    super.key,
    required this.section,
    required this.tagline,
    this.padding = const EdgeInsets.fromLTRB(24, 36, 24, 0),
  });

  final String section; // 'LỘ TRÌNH'
  final String tagline; // '4 tuần · Phase 1.'
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'VIKA · ${section.toUpperCase()}',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(height: 1, color: c.border),
            ),
            const SizedBox(width: 14),
            Text(
              tagline,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: c.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
