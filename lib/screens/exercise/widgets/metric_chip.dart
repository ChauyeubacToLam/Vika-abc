import 'package:flutter/material.dart';

import '../../onboarding/vf_theme.dart';

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    required this.state,
  });

  final String label;
  final String value;
  final MetricChipState state;

  @override
  Widget build(BuildContext context) {
    final bgColor = switch (state) {
      MetricChipState.good => VF.jadeGlow.withValues(alpha: 0.14),
      MetricChipState.warning => VF.coral.withValues(alpha: 0.14),
      MetricChipState.neutral => Colors.white.withValues(alpha: 0.06),
    };
    final borderColor = switch (state) {
      MetricChipState.good => VF.jadeGlow.withValues(alpha: 0.20),
      MetricChipState.warning => VF.coral.withValues(alpha: 0.24),
      MetricChipState.neutral => Colors.white.withValues(alpha: 0.08),
    };
    final valueColor = switch (state) {
      MetricChipState.good => VF.jadeGlow,
      MetricChipState.warning => VF.coral,
      MetricChipState.neutral => Colors.white.withValues(alpha: 0.82),
    };
    final labelColor = switch (state) {
      MetricChipState.good => VF.jadeGlow.withValues(alpha: 0.85),
      MetricChipState.warning => VF.coral.withValues(alpha: 0.88),
      MetricChipState.neutral => Colors.white.withValues(alpha: 0.40),
    };

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
              color: labelColor,
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

enum MetricChipState { good, warning, neutral }
