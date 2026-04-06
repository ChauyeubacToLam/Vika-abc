import 'package:flutter/material.dart';

import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class TrustPage extends StatelessWidget {
  const TrustPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return ColoredBox(
      color: VF.bg,
      child: Stack(
        children: [
          const VFDarkCurveBackdrop(height: 420),
          Positioned(
            left: -25 * s,
            top: 300 * s,
            child: const VFDecorativeRing(size: 120, opacity: 0.04),
          ),
          Column(
            children: [
              VFOnboardingNavBar(
                current: 3,
                total: 10,
                onBack: onBack,
                dark: true,
              ),
              Expanded(
                child: VFFitViewport(
                  padding: EdgeInsets.fromLTRB(16 * s, 16 * s, 16 * s, 0),
                  child: Column(
                    children: [
                      VFProgressRing(
                        progress: 0.87,
                        size: 175,
                        strokeWidth: 5.5,
                        glowWidth: 14,
                        color: VF.jadeGlow.withValues(alpha: 0.60),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        center: Text(
                          '87%',
                          style: VF.textStyle(
                            context,
                            size: 54,
                            weight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -4,
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * s),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40 * s),
                        child: Column(
                          children: [
                            Text(
                              'cải thiện form rõ rệt',
                              textAlign: TextAlign.center,
                              style: VF.textStyle(
                                context,
                                size: 16,
                                weight: FontWeight.w700,
                                color: const Color(0xCCFFFFFF),
                              ),
                            ),
                            SizedBox(height: 4 * s),
                            Text(
                              'sau 2 tuần · 50 người thử nghiệm',
                              textAlign: TextAlign.center,
                              style: VF.textStyle(
                                context,
                                size: 13,
                                weight: FontWeight.w500,
                                color: const Color(0x4DFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 26 * s),
                      Row(
                        children: [
                          const Expanded(
                            child: _TrustStepCard(
                              icon: Icons.phone_iphone_rounded,
                              title: 'Đặt điện thoại',
                              subtitle: 'Nghiêng, cách 2m',
                            ),
                          ),
                          SizedBox(width: 8 * s),
                          const Expanded(
                            child: _TrustStepCard(
                              icon: Icons.accessibility_new_rounded,
                              title: 'Tập bình thường',
                              subtitle: 'AI theo dõi 33 điểm',
                            ),
                          ),
                          SizedBox(width: 8 * s),
                          const Expanded(
                            child: _TrustStepCard(
                              icon: Icons.done_rounded,
                              title: 'Sửa form ngay',
                              subtitle: 'Phản hồi realtime',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 22 * s),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12 * s),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: VF.sp(context, 14),
                              fontWeight: FontWeight.w600,
                              color: VF.textSec,
                              height: 1.7,
                            ),
                            children: [
                              const TextSpan(text: 'Không cần phòng tập. '),
                              const TextSpan(
                                text: 'Không cần kinh nghiệm. ',
                                style: TextStyle(color: VF.textMuted),
                              ),
                              const TextSpan(
                                text: 'Chỉ 10 phút',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: VF.accent,
                                ),
                              ),
                              const TextSpan(text: ' mỗi ngày.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VFOnboardingButton(
                label: 'Tôi sẵn sàng',
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustStepCard extends StatelessWidget {
  const _TrustStepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12 * s, 18 * s, 12 * s, 16 * s),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(20 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8 * s,
            offset: Offset(0, 4 * s),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42 * s,
            height: 42 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14 * s),
              color: VF.accentSoft,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22 * s, color: VF.accent),
          ),
          SizedBox(height: 10 * s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: VF.textStyle(
              context,
              size: 13,
              weight: FontWeight.w700,
              color: VF.text,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 3 * s),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: VF.textStyle(
              context,
              size: 10,
              weight: FontWeight.w500,
              color: VF.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
