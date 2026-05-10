// BodyCard — supporting cream card on Profile with height/weight/age + a
// BMI summary bar.
//
// Mirrors `ProfileBodyCard` and `BodyStat` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class BodyCard extends StatelessWidget {
  const BodyCard({
    super.key,
    required this.height,
    required this.weight,
    required this.age,
    required this.bmi,
    this.onEdit,
  });

  final int height;
  final int weight;
  final int age;
  final String bmi;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PlanEyebrow('Vóc dáng', size: 10, letterSpacing: 2),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Text(
                  'SỬA',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: c.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                    child: _BodyStat(
                  value: '$height',
                  unit: 'cm',
                  label: 'Chiều cao',
                )),
                Container(width: 1, color: c.border),
                const SizedBox(width: 16),
                Expanded(
                    child: _BodyStat(
                  value: '$weight',
                  unit: 'kg',
                  label: 'Cân nặng',
                )),
                Container(width: 1, color: c.border),
                const SizedBox(width: 16),
                Expanded(
                    child: _BodyStat(
                  value: '$age',
                  unit: 'tuổi',
                  label: 'Tuổi',
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // BMI bar.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.yellowGhost,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      PlanEyebrow('BMI', size: 9, letterSpacing: 1.4),
                      const SizedBox(width: 6),
                      Text(
                        bmi,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.4,
                          color: c.ink,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          color: c.inkGhost,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cân đối',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'WHO CHÂU Á',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyStat extends StatelessWidget {
  const _BodyStat({required this.value, required this.unit, required this.label});

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1,
                height: 0.9,
                color: c.ink,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: c.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        PlanEyebrow(label, size: 9, letterSpacing: 1.4),
      ],
    );
  }
}
