// SettingsGroup + SettingRow — categorical settings list on the Profile
// screen, in the Premium Ivory language: warm-cream cards, a single reserved-
// yellow tick per group label, and monochrome warm-ink rows. No per-group
// "phase" colors — Settings reads as one disciplined system, not a Material
// rainbow. Yellow stays reserved (here: the group-label tick).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.label,
    required this.rows,
  });

  final String label;
  final List<SettingRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canonical section grammar — reserved-yellow tick + ink label +
          // hairline rule. Matches _SectionHeader and the Plan ledger's mark,
          // so Settings belongs to the same editorial system as every tab.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 11),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.ink,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(child: Container(height: 1, color: c.border)),
              ],
            ),
          ),
          // Flat cream card — one hairline, one soft warm shadow. No colored
          // gradient or border; the restraint is what reads as expensive.
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.bgRaised,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: c.ink.withValues(alpha: c.isDark ? 0.22 : 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: c.border,
                      indent: 68,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    this.danger = false,
    this.onTap,
    this.comingSoon = false,
    this.showChevron = true,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final bool danger;
  final VoidCallback? onTap;

  /// Optional trailing widget shown in place of the chevron — e.g. a state
  /// toggle. When set, the chevron is suppressed; the row's [onTap] still fires
  /// so the whole row stays the tap target (wrap an indicator-only control in
  /// IgnorePointer to avoid double handling).
  final Widget? trailing;

  /// Renders the row visibly non-interactive (subdued, no tap ripple) with a
  /// "Sắp ra mắt" chip in place of the chevron. Used for features that are
  /// intentionally deferred, so they don't read as a working-but-inert row.
  final bool comingSoon;

  /// When false, the trailing chevron is hidden — for display-only rows
  /// (e.g. the email row) that carry information but aren't tappable.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);

    // Monochrome warm chips: a tinted-cream square with a hairline and an
    // ink-soft glyph. Danger rows swap to the warm amber alarm; deferred rows
    // recede to faint. No per-row glow — uniform, quiet, premium.
    final iconBg = comingSoon
        ? c.bg.withValues(alpha: c.isDark ? 0.24 : 0.6)
        : danger
            ? c.attention.withValues(alpha: 0.10)
            : c.powder.withValues(alpha: c.isDark ? 0.5 : 1);
    final iconBorder = comingSoon
        ? c.border
        : danger
            ? c.attention.withValues(alpha: 0.28)
            : c.border;
    final iconColor = comingSoon
        ? c.inkFaint
        : danger
            ? c.attention
            : c.inkSoft;
    final labelColor =
        comingSoon ? c.inkSoft : (danger ? c.attention : c.ink);

    // Deferred rows never fire onTap, even if one was passed by mistake.
    final effectiveOnTap = comingSoon ? null : onTap;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: labelColor,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: comingSoon ? c.inkFaint : c.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (comingSoon)
            _ComingSoonChip()
          else if (trailing != null)
            trailing!
          else if (!danger && showChevron)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: c.inkGhost,
            ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: c.ink.withValues(alpha: 0.06),
        highlightColor: c.ink.withValues(alpha: 0.04),
        onTap: effectiveOnTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                effectiveOnTap();
              },
        child: content,
      ),
    );
  }
}

/// Small muted "Sắp ra mắt" chip shown on intentionally-deferred rows.
class _ComingSoonChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: c.isDark ? 0.3 : 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Text(
        'Sắp ra mắt',
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: c.inkFaint,
        ),
      ),
    );
  }
}
