import 'package:flutter/material.dart';

import '../vf_theme.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onStart;

  const WelcomePage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              children: [
                TextSpan(text: 'Vina', style: TextStyle(color: VF.accent)),
                TextSpan(text: 'Fit', style: TextStyle(color: VF.text)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: VFFitViewport(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'AI coach that\nwatches your form',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: VF.text,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Camera phân tích chuyển động theo rep, giữ mọi thứ gọn, rõ, và đủ nghiêm túc để tin tưởng mỗi ngày.',
                    style: TextStyle(
                      fontSize: 14,
                      color: VF.textMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FeatureRow(
                    title: 'Real-time analysis',
                    desc: 'Theo dõi form ngay trong lúc tập, không cần thiết bị ngoài điện thoại.',
                  ),
                  const SizedBox(height: 14),
                  const _FeatureRow(
                    title: 'Program built from your baseline',
                    desc: 'Onboarding dùng mục tiêu, tần suất tập, và squat assessment để đề xuất trình độ.',
                  ),
                  const SizedBox(height: 14),
                  const _FeatureRow(
                    title: 'Designed for home workouts',
                    desc: 'Giao diện sáng, sạch, tập trung vào coaching thay vì game hóa.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          VFButton(label: 'Bắt đầu', onTap: onStart),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        color: VF.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF11262B),
                    Color(0xFF102126),
                    Color(0xFF0B1A1A),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -10,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VF.accent.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -10,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 6,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: VF.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'LIVE AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: VF.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 24,
            child: Text(
              'PHOTO-READY HERO',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.26),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Row(
              children: const [
                Expanded(
                  child: _MetricCard(label: 'DEPTH', value: '108°', color: VF.accentSoftStrong),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(label: 'FORM', value: 'Good', color: VF.greenSoft),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(label: 'REPS', value: '3 / 5', color: Color(0x1AFFFFFF)),
                ),
              ],
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CameraBadge(),
                  SizedBox(height: 10),
                  Text(
                    'Swap real squat photo later',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0x66FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VF.accent.withValues(alpha: 0.45)),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Container(
          width: 26,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: VF.accentSoftStrong.withValues(alpha: 0.9)),
          ),
          child: const Center(
            child: SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VF.accentSoftStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.32),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color.value == const Color(0x1AFFFFFF).value
                  ? Colors.white
                  : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String title;
  final String desc;

  const _FeatureRow({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: VFCheckIcon(size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: VF.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: VF.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
