import 'package:flutter/material.dart';
import 'package:vinafit_mobile/widgets/vf_primitives.dart';

import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class AssessmentIntroPage extends StatelessWidget {
  const AssessmentIntroPage({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VFOnboardingNavBar(
            current: 4,
            total: 10,
            onBack: onBack,
          ),
          Expanded(
            child: VFFitViewport(
              padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Squat Assessment',
                          style: VF.textStyle(
                            context,
                            size: 28,
                            weight: FontWeight.w900,
                            color: VF.text,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        Text(
                          'Đây là bài đánh giá đầu tiên để AI hiểu cách bạn squat và cá nhân hóa lộ trình phù hợp hơn.',
                          style: VF.textStyle(
                            context,
                            size: 14,
                            weight: FontWeight.w500,
                            color: VF.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 * s),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24 * s),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          VF.surfaceDark,
                          VF.jadeDark,
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24 * s),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: VFGrainOverlay(opacity: 0.035),
                          ),
                          Positioned(
                            top: -10 * s,
                            right: -10 * s,
                            child:
                                const VFDecorativeRing(size: 80, opacity: 0.04),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(22 * s, 20 * s, 22 * s, 20 * s),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _AssessmentTag(
                                    label: 'BẠN TẬP',
                                    color: Colors.white.withValues(alpha: 0.40),
                                    background:
                                        Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                SizedBox(height: 14 * s),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: _AssessmentMiniCard(
                                        title: 'Squat',
                                        subtitle: '5 reps',
                                      ),
                                    ),
                                    SizedBox(width: 10 * s),
                                    const Expanded(
                                      child: _AssessmentMiniCard(
                                        title: 'Wall Push-up',
                                        subtitle: '5 reps',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 18 * s),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10 * s,
                                      ),
                                      child: Icon(
                                        Icons.south_rounded,
                                        size: 16 * s,
                                        color:
                                            VF.jadeGlow.withValues(alpha: 0.50),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14 * s),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _AssessmentTag(
                                    label: 'AI PHÂN TÍCH',
                                    color: VF.jadeGlow.withValues(alpha: 0.70),
                                    background:
                                        VF.jadeGlow.withValues(alpha: 0.10),
                                  ),
                                ),
                                SizedBox(height: 12 * s),
                                Row(
                                  children: const [
                                    Expanded(
                                      child: _MetricColumn(
                                        icon: Icons.show_chart_rounded,
                                        label: 'Độ sâu & góc',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MetricColumn(
                                        icon: Icons.straighten_rounded,
                                        label: 'Tư thế lưng',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MetricColumn(
                                        icon: Icons.schedule_rounded,
                                        label: 'Nhịp & kiểm soát',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AssessmentTag(
                          label: 'BẠN NHẬN ĐƯỢC',
                          color: VF.accent,
                          background: VF.accent.withValues(alpha: 0.08),
                        ),
                        SizedBox(height: 12 * s),
                        Container(
                          padding: EdgeInsets.all(20 * s),
                          decoration: BoxDecoration(
                            color: VF.surface,
                            borderRadius: BorderRadius.circular(22 * s),
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
                              Row(
                                children: [
                                  VFProgressRing(
                                    progress: 0.75,
                                    size: 52,
                                    strokeWidth: 3.5,
                                    color: VF.accent.withValues(alpha: 0.50),
                                    backgroundColor:
                                        VF.textMuted.withValues(alpha: 0.15),
                                    center: Text(
                                      '?',
                                      style: VF.textStyle(
                                        context,
                                        size: 15,
                                        weight: FontWeight.w900,
                                        color: VF.text,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14 * s),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Điểm form & cấp độ',
                                          style: VF.textStyle(
                                            context,
                                            size: 14,
                                            weight: FontWeight.w700,
                                            color: VF.text,
                                          ),
                                        ),
                                        SizedBox(height: 3 * s),
                                        Text(
                                          'Điểm mạnh, điểm yếu, và lộ trình cá nhân hóa',
                                          style: VF.textStyle(
                                            context,
                                            size: 11,
                                            weight: FontWeight.w500,
                                            color: VF.textMuted,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14 * s),
                              Wrap(
                                spacing: 6 * s,
                                runSpacing: 6 * s,
                                children: [
                                  _chip(context, 'Cấp độ phù hợp', true),
                                  _chip(context, 'Điểm cần cải thiện', false),
                                  _chip(context, 'Chương trình 4 tuần', false),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8 * s, 14 * s, 8 * s, 8 * s),
                    child: Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 16 * s,
                          color: VF.textMuted,
                        ),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: Text(
                            'Đặt điện thoại nghiêng, cách khoảng 2m',
                            style: VF.textStyle(
                              context,
                              size: 12,
                              weight: FontWeight.w600,
                              color: VF.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          VFOnboardingButton(
            label: 'Bắt đầu đánh giá',
            onTap: onNext,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool active) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 5 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * s),
        color: active ? VF.accentSoft : VF.textMuted.withValues(alpha: 0.06),
      ),
      child: Text(
        label,
        style: VF.textStyle(
          context,
          size: 11,
          weight: FontWeight.w600,
          color: active ? VF.accent : VF.textMuted,
        ),
      ),
    );
  }
}

class _AssessmentTag extends StatelessWidget {
  const _AssessmentTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * s),
        color: background,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5 * s,
            height: 5 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: 6 * s),
          Text(
            label,
            style: TextStyle(
              fontSize: VF.sp(context, 10),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5 * s,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentMiniCard extends StatelessWidget {
  const _AssessmentMiniCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * s),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VF.textStyle(
              context,
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          SizedBox(height: 2 * s),
          Text(
            subtitle,
            style: VF.textStyle(
              context,
              size: 10,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 18 * s,
          color: VF.jadeGlow.withValues(alpha: 0.50),
        ),
        SizedBox(height: 4 * s),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: VF.sp(context, 9),
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}
