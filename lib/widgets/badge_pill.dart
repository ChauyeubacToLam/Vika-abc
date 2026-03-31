import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.label,
    this.color = VFTheme.accent,
    this.background = VFTheme.accentBg,
    this.fontSize = 10,
    this.padding,
    this.uppercase = true,
  });

  final String label;
  final Color color;
  final Color background;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: 8 * VFTheme.scale(context),
            vertical: 3 * VFTheme.scale(context),
          ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6 * VFTheme.scale(context)),
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style: TextStyle(
          fontSize: VFTheme.font(context, fontSize),
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
    );
  }
}
