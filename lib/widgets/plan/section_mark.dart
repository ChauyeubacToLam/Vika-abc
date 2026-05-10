// SectionMark — magazine-style numbered section marker used at the top of
// every page section: yellow vertical bar + uppercase tracked label +
// hairline + "01 / 02" index numeral.
//
// Mirrors `SectionMark` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';
class SectionMark extends StatelessWidget {
  const SectionMark({
    super.key,
    required this.num,
    required this.label,
    this.total,
    this.padding = const EdgeInsets.fromLTRB(24, 36, 24, 0),
  });

  final String num; // '01'
  final String label; // 'Hôm nay'
  final String? total; // '02' — when null the index column is hidden
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: c.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          PlanEyebrow(
            label,
            size: 13,
            letterSpacing: 2,
            color: c.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: c.border),
          ),
          if (total != null) ...[
            const SizedBox(width: 12),
            Text(
              '$num / $total',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
