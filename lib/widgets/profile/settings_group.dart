// SettingsGroup + SettingRow — categorical settings list on the
// Profile screen. v2 polish: group label uses the 13pt section-header
// grammar (yellow accent bar + uppercase eyebrow), rows are slightly
// taller with refined icon medallions and a more visible chevron.

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
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 1, color: c.border)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.bgRaised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: c.border,
                        indent: 60,
                      ),
                  ],
                ],
              ),
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
  });

  final IconData icon;
  final String label;
  final String? sub;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final iconBg = danger ? c.attention.withValues(alpha: 0.08) : c.bg;
    final iconColor = danger ? c.attention : c.inkSoft;
    final labelColor = danger ? c.attention : c.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: danger
                        ? c.attention.withValues(alpha: 0.2)
                        : c.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: labelColor,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        sub!,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!danger)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: c.inkFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
