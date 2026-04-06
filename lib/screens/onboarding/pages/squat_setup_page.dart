import 'package:flutter/material.dart';
import 'package:vinafit_mobile/widgets/pose_silhouette.dart';
import 'package:vinafit_mobile/widgets/vf_primitives.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class SquatSetupPage extends StatefulWidget {
  const SquatSetupPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<SquatSetupPage> createState() => _SquatSetupPageState();
}

class _SquatSetupPageState extends State<SquatSetupPage> {
  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return ColoredBox(
      color: VF.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VFOnboardingNavBar(
            current: 5,
            total: 11,
            onBack: widget.onBack,
          ),
          Expanded(
            child: VFFitViewport(
              padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * s),
                    child: Text(
                      'Bài kiểm tra đầu vào',
                      style: VF.textStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w900,
                        color: VF.text,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28 * s),
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
                      borderRadius: BorderRadius.circular(28 * s),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: VFGrainOverlay(opacity: 0.035),
                          ),
                          Positioned(
                            top: -15 * s,
                            right: -15 * s,
                            child:
                                VFDecorativeRing(size: 90 * s, opacity: 0.05),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(22 * s, 24 * s, 22 * s, 20 * s),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 90 * s,
                                      child: AspectRatio(
                                        aspectRatio: 0.82,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20 * s),
                                            color: Colors.white
                                                .withValues(alpha: 0.04),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.06),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              PoseSilhouette(
                                                type: 'squat',
                                                size: 50 * s,
                                                color: const Color(0x80FFFFFF),
                                              ),
                                              Positioned(
                                                bottom: 16 * s,
                                                child: Icon(
                                                  Icons
                                                      .keyboard_double_arrow_down_rounded,
                                                  size: 18 * s,
                                                  color: VF.jadeGlow
                                                      .withValues(alpha: 0.50),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 18 * s),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10 * s,
                                              vertical: 3 * s,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(7 * s),
                                              color: VF.jadeGlow
                                                  .withValues(alpha: 0.10),
                                              border: Border.all(
                                                color: VF.jadeGlow
                                                    .withValues(alpha: 0.08),
                                              ),
                                            ),
                                            child: Text(
                                              'LOWER BODY',
                                              style: VF.textStyle(
                                                context,
                                                size: 9,
                                                weight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                color: VF.jadeGlow
                                                    .withValues(alpha: 0.65),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 10 * s),
                                          Text(
                                            'Squat',
                                            style: VF.textStyle(
                                              context,
                                              size: 28,
                                              weight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -1.5,
                                            ),
                                          ),
                                          SizedBox(height: 4 * s),
                                          Text(
                                            'Đánh giá độ sâu, nhịp, và kiểm soát form hạ thân',
                                            style: VF.textStyle(
                                              context,
                                              size: 13,
                                              weight: FontWeight.w500,
                                              color: Colors.white
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          SizedBox(height: 14 * s),
                                          Row(
                                            children: [
                                              _BigStat(
                                                  value: '5', label: 'reps'),
                                              SizedBox(width: 12 * s),
                                              _DividerLine(),
                                              SizedBox(width: 12 * s),
                                              _BigStat(
                                                value: '~45',
                                                label: 'giây',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 18 * s),
                                Wrap(
                                  spacing: 8 * s,
                                  runSpacing: 8 * s,
                                  children: const [
                                    _DarkTag(label: 'Độ sâu'),
                                    _DarkTag(label: 'Tư thế lưng'),
                                    _DarkTag(label: 'Nhịp rep'),
                                    _DarkTag(label: 'Kiểm soát'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 14 * s),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18 * s,
                      vertical: 16 * s,
                    ),
                    decoration: BoxDecoration(
                      color: VF.surface,
                      borderRadius: BorderRadius.circular(18 * s),
                    ),
                    child: Row(
                      children: [
                        _CameraTipIcon(),
                        SizedBox(width: 14 * s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đặt điện thoại nghiêng, cách ~2m',
                                style: VF.textStyle(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: VF.text,
                                ),
                              ),
                              SizedBox(height: 1 * s),
                              Text(
                                'Camera nhìn toàn thân, nơi đủ sáng',
                                style: VF.textStyle(
                                  context,
                                  size: 11,
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(4 * s, 14 * s, 4 * s, 8 * s),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => widget.data.medicalClear =
                            !widget.data.medicalClear,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 24 * s,
                            height: 24 * s,
                            margin: EdgeInsets.only(top: 1 * s),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8 * s),
                              color: widget.data.medicalClear
                                  ? VF.accent
                                  : VF.textMuted.withValues(alpha: 0.08),
                              border: widget.data.medicalClear
                                  ? null
                                  : Border.all(
                                      color:
                                          VF.textMuted.withValues(alpha: 0.25),
                                      width: 2 * s,
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: widget.data.medicalClear
                                ? Icon(
                                    Icons.done_rounded,
                                    size: 14 * s,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          SizedBox(width: 14 * s),
                          Expanded(
                            child: Text(
                              'Tôi không có chấn thương nghiêm trọng hoặc bệnh lý cần lưu ý khi tập luyện',
                              style: VF.textStyle(
                                context,
                                size: 13,
                                weight: FontWeight.w600,
                                color: VF.textSec,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          VFOnboardingButton(
            label: 'Bắt đầu Squat',
            onTap: widget.data.medicalClear ? widget.onNext : null,
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: VF.textStyle(
            context,
            size: 22,
            weight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 5 * s),
        Text(
          label,
          style: VF.textStyle(
            context,
            size: 10,
            weight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      width: 1 * s,
      height: 20 * s,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _DarkTag extends StatelessWidget {
  const _DarkTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * s),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Text(
        label,
        style: VF.textStyle(
          context,
          size: 10,
          weight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
    );
  }
}

class _CameraTipIcon extends StatelessWidget {
  const _CameraTipIcon();

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      width: 42 * s,
      height: 42 * s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13 * s),
        color: VF.accentSoft,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.videocam_outlined,
        size: 20 * s,
        color: VF.accent,
      ),
    );
  }
}
