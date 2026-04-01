import 'package:flutter/material.dart';

import '../../onboarding/vf_theme.dart';

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    required this.good,
  });

  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final bgColor = good
        ? VF.jadeGlow.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = good
        ? VF.jadeGlow.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.08);
    final valueColor =
        good ? VF.jadeGlow : Colors.white.withValues(alpha: 0.82);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: good
                  ? VF.jadeGlow.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.40),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              value,
              key: ValueKey<String>(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
