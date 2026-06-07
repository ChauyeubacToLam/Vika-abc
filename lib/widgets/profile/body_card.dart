// BodyCard — supporting cream card on Profile with height/weight/age +
// a refined BMI summary chip. v2 polish: bigger italic numerals,
// FittedBox safety on each stat, hairline micro-rules under each value,
// editorial BMI chip with category tag on the right.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class BodyCard extends StatelessWidget {
  const BodyCard({
    super.key,
    required this.height,
    required this.weight,
    required this.age,
    required this.bmi,
    this.bmiCategory = 'Cân đối',
    this.onEdit,
  });

  final int? height;
  final int? weight;
  final int? age;
  final String? bmi;
  final String bmiCategory;
  final VoidCallback? onEdit;

  /// Shown in place of any value that is null — never a fake number.
  static const _placeholder = '—';

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: c.yellow, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'VÓC DÁNG',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkSoft,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onEdit?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SỬA',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: c.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: c.inkSoft,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BodyStat(
                    value: height?.toString() ?? _placeholder,
                    unit: 'cm',
                    label: 'Chiều cao',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(width: 1, color: c.border),
                ),
                Expanded(
                  child: _BodyStat(
                    value: weight?.toString() ?? _placeholder,
                    unit: 'kg',
                    label: 'Cân nặng',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(width: 1, color: c.border),
                ),
                Expanded(
                  child: _BodyStat(
                    value: age?.toString() ?? _placeholder,
                    unit: 'tuổi',
                    label: 'Tuổi',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // BMI summary chip.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.yellowGhost,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: c.yellow.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BMI',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: c.invInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  bmi ?? _placeholder,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.6,
                    color: c.ink,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  bmiCategory,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.1,
                    color: c.inkSoft,
                  ),
                ),
                const Spacer(),
                Text(
                  'WHO CHÂU Á',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: c.inkFaint,
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
  const _BodyStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -1.4,
                      height: 0.9,
                      color: c.ink,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 3),
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
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 14, height: 1, color: c.yellow),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: c.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
