// LibraryStatBand — editorial stat strip used as a divider between
// major sections in the Library page. Magazine-style: italic display
// numerals as anchors, tiny uppercase labels below, separated by thin
// vertical hairlines. Adds visual rhythm to the page (not just a
// stack of rails) and reinforces the catalog's depth at a glance.
//
// Generic — takes a `List<LibraryStat>` so future content additions
// (e.g., "12 huấn luyện viên") just slot in.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class LibraryStat {
  const LibraryStat({required this.value, required this.label});
  final String value;
  final String label;
}

class LibraryStatBand extends StatelessWidget {
  const LibraryStatBand({
    super.key,
    required this.stats,
    this.kicker = 'KHO VIKA · TÍNH ĐẾN HÔM NAY',
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  });

  final List<LibraryStat> stats;

  /// Italic uppercase editorial framing above the stat row. Reads as
  /// "MASTHEAD · DATE" — anchors the band as a publication strip.
  final String kicker;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 22),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  kicker,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.inkSoft,
                  ),
                ),
                const Spacer(),
                Text(
                  '+ MỚI TUẦN NÀY',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.yellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatColumn(stat: stats[i])),
                    if (i < stats.length - 1)
                      Container(
                        width: 1,
                        color: c.border,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat});
  final LibraryStat stat;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          stat.value,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.8,
            height: 0.92,
            color: c.ink,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 14,
          height: 1,
          color: c.yellow,
        ),
        const SizedBox(height: 8),
        Text(
          stat.label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: c.inkSoft,
          ),
        ),
      ],
    );
  }
}
