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
    _stagger = AnimationController(
      duration: const Duration(milliseconds: 1400),
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
    return '$dd / $mm / ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(widget.data);
    final r = V5Responsive.of(context);
    final bottomInset = r.viewPadding.bottom;
    return V5Screen(
      index: 17,
      onBack: widget.onBack,
      inverted: true,
      background: V5.heroBg,
      showChrome: false,
      children: [
        // Atmospheric layers — warm key + cool fill + texture.
        const Positioned(
          top: -180,
          left: -140,
          child: V5AmbientGlow(
            size: Size(440, 460),
            opacity: 0.28,
            color: V5.yellow,
          ),
        ),
        Positioned(
          right: -160,
          bottom: -120,
          child: V5AmbientGlow(
            size: const Size(360, 340),
            opacity: 0.16,
            color: const Color(0xFFCD7C45),
          ),
        ),
        const Positioned.fill(child: V5Texture(opacity: 0.06, density: 1.2)),

        // Decorative sparkles.
        const Positioned(
          top: 170,
          left: 36,
          child: Opacity(opacity: 0.55, child: V5Sparkle(size: 14)),
        ),
        const Positioned(
          top: 220,
          right: 52,
          child: Opacity(opacity: 0.40, child: V5Sparkle(size: 10)),
        ),
        const Positioned(
          top: 540,
          left: 64,
          child: Opacity(opacity: 0.42, child: V5Sparkle(size: 9)),
        ),

        // Main column — keeps everything in a flow that adapts to height,
        // instead of magic top:140 / 198 / 386 positions that overflow on
        // short phones.
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                V5.gutter,
                r.viewPadding.top +
                    r.pick(cozy: 64.0, short: 40.0, veryShort: 24.0),
                V5.gutter,
                bottomInset + r.pick(cozy: 120.0, short: 104.0),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    V5FadeIn(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: V5.yellow.withValues(alpha: 0.14),
                          border: Border.all(
                              color: V5.yellow.withValues(alpha: 0.36)),
                          borderRadius: BorderRadius.circular(V5.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const V5Sparkle(size: 12),
                            const SizedBox(width: V5.space8),
                            Text(
                              'NGÀY 1 · HÀNH TRÌNH BẮT ĐẦU',
                              style: V5
                                  .eyebrow(context, color: V5.yellow)
                                  .copyWith(letterSpacing: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                        height: r.pick(cozy: V5.space24, short: V5.space16)),
                    V5FadeIn(
                      delay: const Duration(milliseconds: 120),
                      slideY: 12,
                      child: Column(
                        children: [
                          Text(
                            'Hôm nay,\nbạn bắt đầu.',
                            textAlign: TextAlign.center,
                            style: r.isShort
                                ? V5.displaySm(context, color: V5.invInk)
                                : V5.display(context, color: V5.invInk),
                          ),
                          SizedBox(
                              height:
                                  r.pick(cozy: V5.space14, short: V5.space10)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Mỗi buổi tập là một bước tới sưc khoẻ mà bạn muốn có được.',
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              style: V5.body(context, color: V5.invInkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                        height: r.pick(cozy: V5.space28, short: V5.space20)),
                    V5FadeIn(
                      delay: const Duration(milliseconds: 240),
                      slideY: 16,
                      child: _CommitmentCard(
                        stagger: _stagger,
                        todayLabel: _todayLabel(),
                        freq: p.freq,
                        levelLabel: p.levelLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        V5PillCTA(
          label:
              (_busy || widget.busy) ? 'Đang lưu…' : 'Vào buổi tập đầu tiên',
          enabled: !_busy && !widget.busy,
          onTap: _handleComplete,
          yellow: true,
          bottom: 32 + bottomInset,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Commitment card — frosted glass with three animated lines
// ─────────────────────────────────────────────────────────────

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({
    required this.stagger,
    required this.todayLabel,
    required this.freq,
    required this.levelLabel,
  });

  final AnimationController stagger;
  final String todayLabel;
  final int freq;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(V5.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(V5.radiusLg),
            boxShadow: V5.elevation3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header.
              Row(
                children: [
                  Text(
                    'CAM KẾT CỦA BẠN',
                    style: V5
                        .eyebrow(context, color: V5.yellow)
                        .copyWith(letterSpacing: 1.6),
                  ),
                  const Spacer(),
                  Text(
                    todayLabel,
                    style: V5
                        .eyebrow(context, color: V5.invInkSoft)
                        .copyWith(letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _CommitmentRow(
                animation: stagger,
                intervalStart: 0.28,
                intervalEnd: 0.56,
                spans: [
                  const TextSpan(text: 'Tập '),
                  TextSpan(
                    text: '$freq buổi/tuần',
                    style: const TextStyle(color: V5.yellow),
                  ),
                  const TextSpan(text: ' theo lịch của tôi.'),
                ],
              ),
              const SizedBox(height: 12),
              _CommitmentRow(
                animation: stagger,
                intervalStart: 0.44,
                intervalEnd: 0.72,
                spans: [
                  const TextSpan(text: 'Hoàn thành '),
                  const TextSpan(
                    text: '4 tuần',
                    style: TextStyle(color: V5.yellow),
                  ),
                  const TextSpan(text: ' với mức '),
                  TextSpan(
                    text: levelLabel,
                    style: const TextStyle(color: V5.yellow),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              const SizedBox(height: 12),
              _CommitmentRow(
                animation: stagger,
                intervalStart: 0.60,
                intervalEnd: 0.88,
                spans: const [
                  TextSpan(text: 'Tin vào '),
                  TextSpan(
                    text: 'quá trình',
                    style: TextStyle(color: V5.yellow),
                  ),
                  TextSpan(text: ', không bỏ giữa chừng.'),
                ],
              ),

              const SizedBox(height: 18),

              // Vika signature.
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: V5.heroBorderHi),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: V5.accentGradient,
                        borderRadius: BorderRadius.circular(V5.radiusXs),
                        boxShadow: V5.yellowGlow(0.32),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'V',
                        style: V5.text(
                          context,
                          size: 14,
                          weight: FontWeight.w900,
                          color: V5.yellowInk,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ĐỒNG HÀNH CÙNG',
                          style: V5
                              .eyebrow(context, color: V5.invInkSoft)
                              .copyWith(letterSpacing: 1.0),
                        ),
                        const SizedBox(height: V5.space2),
                        Text(
                          'Vika · HLV cá nhân',
                          style: V5.titleSm(context, color: V5.invInk),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.check_rounded,
                      color: V5.yellow,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        curve: V5.curve,
      ),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-14 * (1 - t), 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: V5.yellow,
                    shape: BoxShape.circle,
                    boxShadow: V5.yellowGlow(0.24),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    color: V5.yellowInk,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: V5
                          .titleSm(context, color: V5.invInk)
                          .copyWith(height: 1.4),
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
