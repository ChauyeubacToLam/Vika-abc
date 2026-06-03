// SettingsGroup + SettingRow — categorical settings list on the
// Profile screen. Rows keep the Premium Ivory hierarchy, but use softer
// group accents so Settings does not read as a generic Material list.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.label,
    required this.rows,
    this.accentColor,
  });

  final String label;
  final List<SettingRow> rows;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final accent = accentColor ?? c.phase1;
    final raisedTint = Color.lerp(c.bgRaised, accent, c.isDark ? 0.10 : 0.055)!;
    final borderTint = Color.lerp(c.border, accent, c.isDark ? 0.28 : 0.36)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: c.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: borderTint.withValues(alpha: c.isDark ? 0.8 : 1),
                  ),
                ),
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.bgRaised,
                  raisedTint,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderTint),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: c.isDark ? 0.10 : 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: c.ink.withValues(alpha: c.isDark ? 0.18 : 0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
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
                      color:
                          borderTint.withValues(alpha: c.isDark ? 0.7 : 0.62),
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
    this.accentColor,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final Color? accentColor;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final accent = accentColor ?? c.phase1;
    final iconBg = danger
        ? c.attention.withValues(alpha: 0.10)
        : Color.lerp(c.bg, accent, c.isDark ? 0.18 : 0.16)!;
    final iconBorder = danger
        ? c.attention.withValues(alpha: 0.28)
        : accent.withValues(alpha: c.isDark ? 0.34 : 0.42);
    final iconColor = danger
        ? c.attention
        : Color.lerp(accent, c.ink, c.isDark ? 0.08 : 0.36)!;
    final labelColor = danger ? c.attention : c.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: accent.withValues(alpha: 0.10),
        highlightColor: accent.withValues(alpha: 0.06),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap?.call();
              },
        child: Padding(
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
                  boxShadow: danger
                      ? null
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
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
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!danger)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.bg.withValues(alpha: c.isDark ? 0.28 : 0.64),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: c.inkSoft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
