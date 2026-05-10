// SettingsGroup + SettingRow — categorical settings list on the Profile
// screen. Group label uppercase tracked, then a cream card containing rows
// with an icon tile, label, optional sub-label, and a chevron.
//
// Mirrors `SettingsGroup`, `SettingRow`, and `SettingsIcon` in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../plan/plan_typography.dart';
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PlanEyebrow(label, size: 9, letterSpacing: 1.6),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.bgRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: c.border,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: danger ? Colors.transparent : c.bg,
                  borderRadius: BorderRadius.circular(9),
                  border: danger
                      ? Border.all(color: c.borderHi)
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 16,
                  color: danger ? c.attention : c.inkSoft,
                ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: danger ? c.attention : c.ink,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
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
