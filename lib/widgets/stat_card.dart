import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        color: accent ? VFTheme.accentBg : VFTheme.surface,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: VFTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: VFTheme.font(context, 22),
              fontWeight: FontWeight.w800,
              color: accent ? VFTheme.accent : VFTheme.text,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          SizedBox(height: 5 * s),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: VFTheme.font(context, 10),
              fontWeight: FontWeight.w600,
              color: accent ? VFTheme.accentText : VFTheme.textMuted,
              letterSpacing: 0.4,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
