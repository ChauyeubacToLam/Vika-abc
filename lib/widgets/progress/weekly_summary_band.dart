// WeeklySummaryBand — editorial 4-stat strip that sits under the score
// gauge. Mirrors the Library stat band grammar (italic numerals + thin
// vertical hairlines + uppercase labels + yellow micro-rule under each
// value) but adds per-stat *delta notes* that read like a sports
// newspaper sidebar.
//
// Generic — pass any list of [WeeklyStat] and the band lays them out.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

@immutable
class WeeklyStat {
  const WeeklyStat({
    required this.value,
    required this.label,
    this.deltaNote,
    this.deltaPositive = true,
  });
  final String value;
  final String label;
  final String? deltaNote;

  /// When true, the delta note renders in yellow; otherwise faint ink.
  final bool deltaPositive;
}

class WeeklySummaryBand extends StatelessWidget {
  const WeeklySummaryBand({
    super.key,
    required this.stats,
    required this.kicker,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<WeeklyStat> stats;
  final String kicker;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 22),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.yellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: c.yellow, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatColumn(stat: stats[i])),
                    if (i < stats.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Container(width: 1, color: c.border),
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
  final WeeklyStat stat;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // FittedBox scales the italic value down on narrow cells so
          // long values ("24/28", "9h48'") never collide with the
          // hairline divider. Single-line, baseline-aligned.
          SizedBox(
            height: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                stat.value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.4,
                  height: 1.0,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 16, height: 1, color: c.yellow),
          const SizedBox(height: 10),
          Text(
            stat.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: c.inkSoft,
            ),
          ),
          if (stat.deltaNote != null) ...[
            const SizedBox(height: 5),
            Text(
              stat.deltaNote!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                height: 1.3,
                letterSpacing: -0.1,
                color: stat.deltaPositive ? c.yellow : c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
