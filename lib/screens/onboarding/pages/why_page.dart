import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class WhyPage extends StatefulWidget {
  const WhyPage({
    super.key,
    required this.data,
    required this.onNext,
  });

  final OnboardingData data;
  final VoidCallback onNext;

  @override
  State<WhyPage> createState() => _WhyPageState();
}

class _WhyPageState extends State<WhyPage> {
  static const _reasons = [
    (
      id: 'pain',
      title: 'Hết đau mỏi',
      subtitle: 'Ngồi cả ngày mà không nhức',
      color: VF.coral,
      icon: Icons.self_improvement_outlined,
    ),
    (
      id: 'confidence',
      title: 'Tự tin hơn',
      subtitle: 'Thay đổi khi nhìn gương',
      color: VF.accent,
      icon: Icons.sentiment_satisfied_alt_outlined,
    ),
    (
      id: 'energy',
      title: 'Nhiều năng lượng',
      subtitle: 'Không kiệt sức khi về nhà',
      color: VF.amber,
      icon: Icons.bolt_rounded,
    ),
    (
      id: 'health',
      title: 'Khỏe lâu dài',
      subtitle: '40 tuổi vẫn chạy với con',
      color: VF.blue,
      icon: Icons.favorite_border_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return ColoredBox(
      color: VF.bg,
      child: Stack(
        children: [
          const VFDarkCurveBackdrop(height: 275, radius: 40),
          Positioned(
            top: 40 * s,
            right: -10 * s,
            child: const VFDecorativeRing(size: 96, opacity: 0.06),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VFOnboardingNavBar(current: 1, total: 10, dark: true),
              Padding(
                padding: EdgeInsets.fromLTRB(28 * s, 20 * s, 28 * s, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BƯỚC 1',
                      style: VF.textStyle(
                        context,
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: VF.jadeGlow.withValues(alpha: 0.35),
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      'Điều gì đang khiến\nbạn bắt đầu?',
                      style: VF.textStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: VFFitViewport(
                  padding: EdgeInsets.fromLTRB(20 * s, 16 * s, 20 * s, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _reasons.map((reason) {
                      final selected = widget.data.why == reason.id;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8 * s),
                        child: VFLeftAccentOptionCard(
                          selected: selected,
                          accentColor: reason.color,
                          onTap: () =>
                              setState(() => widget.data.why = reason.id),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
                            child: Row(
                              children: [
                                Container(
                                  width: 52 * s,
                                  height: 52 * s,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16 * s),
                                    color:
                                        (selected ? reason.color : VF.textMuted)
                                            .withValues(
                                      alpha: selected ? 0.12 : 0.06,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    reason.icon,
                                    size: 28 * s,
                                    color:
                                        selected ? reason.color : VF.textMuted,
                                  ),
                                ),
                                SizedBox(width: 16 * s),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reason.title,
                                        style: VF.textStyle(
                                          context,
                                          size: 16,
                                          weight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color:
                                              selected ? VF.text : VF.textSec,
                                        ),
                                      ),
                                      SizedBox(height: 2 * s),
                                      Text(
                                        reason.subtitle,
                                        style: VF.textStyle(
                                          context,
                                          size: 12,
                                          weight: FontWeight.w500,
                                          color: VF.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (widget.data.why != null)
                VFOnboardingButton(
                  label: 'Tiếp theo',
                  onTap: widget.onNext,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
