import 'package:flutter/material.dart';
import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S13Signup extends StatefulWidget {
  const S13Signup({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S13Signup> createState() => _S13SignupState();
}

class _S13SignupState extends State<S13Signup> {
  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(widget.data);
    final bmi = widget.data.bmi?.toStringAsFixed(1) ?? '22.0';
    return V5Screen(
      index: 13,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: 144,
          left: 16,
          right: 16,
          height: 168,
          child: V5FadeIn(
            child: V5HeroCard(
              borderRadius: 24,
              child: Stack(
                children: [
                  Positioned(
                    top: 18,
                    left: 20,
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 12, color: V5.yellow),
                        const SizedBox(width: 8),
                        Text(
                          'LỘ TRÌNH CỦA BẠN ĐÃ SẴN SÀNG',
                          style: V5.text(
                            context,
                            size: 10,
                            weight: FontWeight.w800,
                            color: V5.invInk,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      children: [
                        Expanded(child: _HeroStat(label: 'Mức tập', value: p.levelLabel)),
                        const SizedBox(width: 8),
                        Expanded(child: _HeroStat(
                          label: 'Lịch tập',
                          value: '${p.freq}',
                          suffix: 'buổi/tuần',
                          yellow: true,
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _HeroStat(label: 'BMI', value: bmi)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 328,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoàn tất thiết lập',
                style: V5.text(
                  context,
                  size: 22,
                  weight: FontWeight.w800,
                  color: V5.ink,
                  letterSpacing: -.7,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lộ trình của bạn đã được thiết kế xong!',
                style: V5.text(
                  context,
                  size: 12,
                  weight: FontWeight.w500,
                  color: V5.inkSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Vào giao diện chính',
          enabled: true,
          onTap: widget.onNext,
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.suffix,
    this.yellow = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final bool yellow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: V5.text(
              context,
              size: 8,
              weight: FontWeight.w700,
              color: V5.invInkSoft,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: V5.text(
                context,
                size: 14,
                weight: FontWeight.w800,
                color: yellow ? V5.yellow : V5.invInk,
                letterSpacing: -.3,
                height: 1,
              ),
              children: [
                TextSpan(text: value),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w700,
                      color: V5.invInk,
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
