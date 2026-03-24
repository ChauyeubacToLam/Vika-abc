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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * VFTheme.scale(context),
        vertical: 12 * VFTheme.scale(context),
      ),
      decoration: BoxDecoration(
        color: accent ? VFTheme.accentBg : VFTheme.surface,
        borderRadius: BorderRadius.circular(10 * VFTheme.scale(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: VFTheme.font(context, 22),
              fontWeight: FontWeight.w700,
              color: accent ? VFTheme.accent : VFTheme.text,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          SizedBox(height: 4 * VFTheme.scale(context)),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: VFTheme.font(context, 10),
              fontWeight: FontWeight.w500,
              color: accent ? VFTheme.accentText : VFTheme.textMuted,
              letterSpacing: 0.3,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
