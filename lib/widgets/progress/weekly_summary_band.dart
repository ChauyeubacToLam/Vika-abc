// WeeklySummaryBand — the "vital strip": the week distilled into a few
// editorial figures, set as a leaf of the page's private ledger (see
// LedgerFrame). Each stat is a big italic numeral seated on a short gold
// underline (the reserved-yellow "stat" use), over a tracked label, with the
// old wordy delta sentence distilled into one compact caret chip. Columns are
// parted by engraved hairlines that fade at their ends like a printed rule.
//
// Generic — pass any list of [WeeklyStat] and the strip lays them out.
// Premium Ivory tokens only.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'ledger_frame.dart';

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
      child: LedgerFrame(
        grainSeed: 53,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kicker — spark dot + tracked label + a thin gold rule that
            // trails off, like a ledger column heading.
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.yellow.withValues(alpha: 0.45),
                          c.yellow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatColumn(stat: stats[i])),
                    if (i < stats.length - 1) const _EngravedDivider(),
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

/// A 1px vertical rule that fades to nothing at both ends — reads as a printed
/// engraving rather than a hard box border.
class _EngravedDivider extends StatelessWidget {
  const _EngravedDivider();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.borderHi.withValues(alpha: 0),
                c.borderHi,
                c.borderHi,
                c.borderHi.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.22, 0.78, 1.0],
            ),
          ),
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
          // values ("24/28", "9h48'") never collide with the rule.
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
          const SizedBox(height: 9),
          // Short gold underline — the figure's printed base (reserved-yellow
          // "underline" use), with a faint bloom.
          Container(
            width: 18,
            height: 2,
            decoration: BoxDecoration(
              color: c.yellow,
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: c.yellow.withValues(alpha: 0.4),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
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
            const SizedBox(height: 10),
            // Scale down on very narrow cells so the chip never overflows.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _TrendChip(
                  label: stat.deltaNote!, positive: stat.deltaPositive),
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
