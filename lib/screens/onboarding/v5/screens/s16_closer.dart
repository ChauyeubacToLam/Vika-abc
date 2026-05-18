import 'dart:ui';

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S16Closer extends StatefulWidget {
  const S16Closer({
    super.key,
    required this.data,
    required this.onComplete,
    required this.onBack,
    this.busy = false,
  });

  final OnboardingData data;
  final Future<void> Function() onComplete;
  final VoidCallback onBack;
  final bool busy;

  @override
  State<S16Closer> createState() => _S16CloserState();
}

class _S16CloserState extends State<S16Closer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Animation 6 — sequential commitment check-in.
    // Items reveal at 400ms / 620ms / 840ms (each 380ms long).
    // Single controller drives all three via Interval curves.
    _stagger = AnimationController(
      duration: const Duration(milliseconds: 1220),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (_busy || widget.busy) return;
    setState(() => _busy = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _todayLabel() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    return '$dd/$mm/${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(widget.data);
    return V5Screen(
      index: 16,
      onBack: widget.onBack,
      inverted: true,
      background: V5.heroBg,
      showChrome: false,
      children: [
        // Atmospheric glow layers — radial gradients (no MaskFilter / blur
        // pass) so there's no first-frame unblurred-disk flash.
        Positioned(
          top: -160,
          left: -120,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  V5.yellow.withValues(alpha: 0.30),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -120,
          bottom: -100,
          child: Container(
            width: 320,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  V5.yellow.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: 160,
          left: 32,
          child: Opacity(opacity: 0.50, child: V5Sparkle(size: 14)),
        ),
        const Positioned(
          top: 200,
          right: 48,
          child: Opacity(opacity: 0.35, child: V5Sparkle(size: 10)),
        ),
        const Positioned(
          top: 540,
          left: 60,
          child: Opacity(opacity: 0.40, child: V5Sparkle(size: 9)),
        ),

        // Eyebrow pill
        Positioned(
          top: 140,
          left: 0,
          right: 0,
          child: Center(
            child: V5FadeIn(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: V5.yellow.withValues(alpha: 0.15),
                  border: Border.all(color: V5.yellow.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const V5Sparkle(size: 11),
                    const SizedBox(width: 6),
                    Text(
                      'NGÀY 1 · HÀNH TRÌNH BẮT ĐẦU',
                      style: V5.text(
                        context,
                        size: 10,
                        weight: FontWeight.w800,
                        color: V5.yellow,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Big title block
        Positioned(
          top: 200,
          left: 24,
          right: 24,
          child: V5FadeIn(
            delay: const Duration(milliseconds: 80),
            child: Column(
              children: [
                Text(
                  'Hôm nay,\nbạn bắt đầu.',
                  textAlign: TextAlign.center,
                  style: V5.text(
                    context,
                    size: 36,
                    weight: FontWeight.w800,
                    color: V5.invInk,
                    letterSpacing: -1.4,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Mỗi buổi tập là một lá phiếu cho con người bạn muốn trở thành.',
                    textAlign: TextAlign.center,
                    style: V5.text(
                      context,
                      size: 13,
                      weight: FontWeight.w500,
                      color: V5.invInkSoft,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Commitment card
        Positioned(
          top: 368,
          left: 20,
          right: 20,
          child: V5FadeIn(
            delay: const Duration(milliseconds: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card header
                      Row(
                        children: [
                          Text(
                            'CAM KẾT CỦA BẠN',
                            style: V5.text(
                              context,
                              size: 9,
                              weight: FontWeight.w800,
                              color: V5.yellow,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _todayLabel(),
                            style: V5.text(
                              context,
                              size: 9,
                              weight: FontWeight.w600,
                              color: V5.invInkSoft,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3 commitment lines — Animation 6 (sequential check-in)
                      _CommitmentRow(
                        animation: _stagger,
                        // 400ms delay / 380ms duration in a 1220ms total
                        intervalStart: 400 / 1220,
                        intervalEnd: 780 / 1220,
                        spans: [
                          const TextSpan(text: 'Tập '),
                          TextSpan(
                            text: '${p.freq} buổi/tuần',
                            style: const TextStyle(color: V5.yellow),
                          ),
                          const TextSpan(text: ' theo lịch của tôi'),
                        ],
                      ),
                      const SizedBox(height: 11),
                      _CommitmentRow(
                        animation: _stagger,
                        intervalStart: 620 / 1220,
                        intervalEnd: 1000 / 1220,
                        spans: [
                          const TextSpan(text: 'Đi qua '),
                          const TextSpan(
                            text: '4 tuần',
                            style: TextStyle(color: V5.yellow),
                          ),
                          const TextSpan(text: ' với mức '),
                          TextSpan(
                            text: p.levelLabel,
                            style: const TextStyle(color: V5.yellow),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      _CommitmentRow(
                        animation: _stagger,
                        intervalStart: 840 / 1220,
                        intervalEnd: 1220 / 1220,
                        spans: const [
                          TextSpan(text: 'Tin vào '),
                          TextSpan(
                            text: 'quá trình',
                            style: TextStyle(color: V5.yellow),
                          ),
                          TextSpan(text: ', không bỏ giữa chừng'),
                        ],
                      ),

                      // Vika signature
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: V5.yellow,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'V',
                                style: V5.text(
                                  context,
                                  size: 12,
                                  weight: FontWeight.w900,
                                  color: V5.yellowInk,
                                  letterSpacing: -0.5,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ĐỒNG HÀNH CÙNG',
                                  style: V5.text(
                                    context,
                                    size: 9,
                                    weight: FontWeight.w700,
                                    color: V5.invInkSoft,
                                    letterSpacing: 0.4,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Vika · HLV cá nhân hoá',
                                  style: V5.text(
                                    context,
                                    size: 11,
                                    weight: FontWeight.w800,
                                    color: V5.invInk,
                                    letterSpacing: -0.2,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(
                              Icons.check_rounded,
                              color: V5.yellow,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // CTA — yellow background, dark inner button (color reversal)
        V5PillCTA(
          label: (_busy || widget.busy)
              ? 'Đang lưu...'
              : 'Vào buổi tập đầu tiên',
          enabled: !_busy && !widget.busy,
          onTap: _handleComplete,
          yellow: true,
          bottom: 32,
        ),
      ],
    );
  }
}

/// One commitment line. Slides in from the left + fades, driven by an
/// `Interval` slice of the parent stagger controller.
class _CommitmentRow extends StatelessWidget {
  const _CommitmentRow({
    required this.animation,
    required this.intervalStart,
    required this.intervalEnd,
    required this.spans,
  });

  final AnimationController animation;
  final double intervalStart;
  final double intervalEnd;
  final List<TextSpan> spans;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(
        intervalStart,
        intervalEnd,
        // cubic-bezier(0.34, 1.3, 0.64, 1) — slight overshoot.
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-12 * (1 - t), 0),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: V5.yellow,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    color: V5.yellowInk,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: V5.text(
                        context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: V5.invInk,
                        letterSpacing: -0.2,
                      ),
                      children: spans,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
