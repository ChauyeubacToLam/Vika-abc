// WeeklySummaryBand — the "vital strip": a raised cream card holding four
// editorial stats for the week. Each stat is a big italic numeral over a tiny
// uppercase label, with the old wordy delta sentence ("+1 vs tuần trước")
// distilled into a single compact trend chip — a caret + the bare delta. Less
// reading, more glanceable signal.
//
// Generic — pass any list of [WeeklyStat] and the strip lays them out, divided
// by hairlines. Premium Ivory tokens only.

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

  /// Compact delta token shown in the trend chip, e.g. "+1", "+3". Null hides
  /// the chip entirely.
  final String? deltaNote;

  /// When true the chip reads as a gain (yellow wash, rising caret); otherwise
  /// a quiet neutral chip with a falling caret.
  final bool deltaPositive;
}

class WeeklySummaryBand extends StatelessWidget {
  const WeeklySummaryBand({
    super.key,
    required this.stats,
    required this.kicker,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
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
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: c.ink.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.yellow.withValues(alpha: 0.6),
                        blurRadius: 5,
                      ),
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
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatColumn(stat: stats[i])),
                    if (i < stats.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // FittedBox scales the italic numeral down on narrow cells so long
          // values ("24/28", "9h48'") never collide with the hairline.
          SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                stat.value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.6,
                  height: 1.0,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
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
            const SizedBox(height: 10),
            // Scale down on very narrow cells so the chip never overflows.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _TrendChip(label: stat.deltaNote!, positive: stat.deltaPositive),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact gain/loss chip — a caret + the bare delta. Replaces the prior
/// italic delta sentence with a single glanceable token.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final fg = positive ? c.yellowInk : c.inkFaint;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
      decoration: BoxDecoration(
        color: positive ? c.yellowGhost : c.bg,
        borderRadius: BorderRadius.circular(9),
        border: positive ? null : Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.arrow_outward_rounded : Icons.south_east_rounded,
            size: 9.5,
            color: fg,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: fg,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
