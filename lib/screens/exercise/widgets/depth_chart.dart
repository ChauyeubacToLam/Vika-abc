import 'package:flutter/material.dart';

import '../../onboarding/vf_theme.dart';

class DepthBarDatum {
  const DepthBarDatum({
    required this.label,
    required this.value,
    required this.good,
  });

  final String label;
  final double value;
  final bool good;
}

class DepthChart extends StatelessWidget {
  const DepthChart({
    super.key,
    required this.data,
    this.title = 'Độ sâu từng rep',
  });

  final List<DepthBarDatum> data;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final values = data.map((item) => item.value).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VF.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: VF.text,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final heightFactor =
                    0.28 + (((maxValue - item.value) / range) * 0.58);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: index == data.length - 1 ? 0 : 6),
                    child: Column(
                      children: [
                        Text(
                          '${item.value.round()}°',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: item.good ? VF.accent : VF.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: heightFactor),
                              duration:
                                  Duration(milliseconds: 420 + (index * 40)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return FractionallySizedBox(
                                  heightFactor: value,
                                  widthFactor: 1,
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                        bottom: Radius.circular(4),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: item.good
                                            ? const [VF.accent, VF.surfaceDark]
                                            : [
                                                VF.textMuted
                                                    .withValues(alpha: 0.45),
                                                VF.textMuted
                                                    .withValues(alpha: 0.2),
                                              ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: VF.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
