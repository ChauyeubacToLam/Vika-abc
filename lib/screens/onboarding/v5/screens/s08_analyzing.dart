import 'dart:async';

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S08Analyzing extends StatefulWidget {
  const S08Analyzing({
    super.key,
    required this.data,
    required this.active,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final bool active;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S08Analyzing> createState() => _S08AnalyzingState();
}

class _S08AnalyzingState extends State<S08Analyzing> {
  Timer? _timer;
  int _reps = 0;
  bool _advanced = false;

  @override
  void didUpdateWidget(covariant S08Analyzing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _start();
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _advanced = false;
    setState(() => _reps =
        widget.data.fork == 'home' && widget.data.hasSquatAssessment ? 5 : 0);
    if (_reps >= 5) {
      _scheduleAdvance(const Duration(milliseconds: 800));
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 420), (timer) {
      if (!mounted) return;
      setState(() => _reps = (_reps + 1).clamp(0, 5));
      if (_reps >= 5) {
        timer.cancel();
        _scheduleAdvance(const Duration(milliseconds: 500));
      }
    });
  }

  void _scheduleAdvance(Duration delay) {
    Future<void>.delayed(delay, () {
      if (!mounted || _advanced || !widget.active) return;
      _advanced = true;
      widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final exerciseName = widget.data.fork == 'yoga' ? 'Warrior I' : 'Squat';
    final r = V5Responsive.of(context);
    final veryCompact = r.isVeryShort;
    final bottomInset = r.viewPadding.bottom;
    return V5Screen(
      index: 10,
      onBack: widget.onBack,
      inverted: true,
      background: V5.heroBg,
      children: [
        // Atmospheric backdrop — single static glow, no animations.
        const Positioned(
          top: -160,
          left: -120,
          child: V5AmbientGlow(
            size: Size(440, 460),
            opacity: 0.24,
            color: V5.yellow,
          ),
        ),
        Positioned(
          right: -160,
          bottom: -80,
          child: V5AmbientGlow(
            size: const Size(360, 360),
            opacity: 0.12,
            color: const Color(0xFFCD7C45),
          ),
        ),

        // Centered V monogram + status text.
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                V5.gutter,
                veryCompact ? 108 : 120,
                V5.gutter,
                bottomInset + (veryCompact ? 206 : 220),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simple gradient monogram with halo. No CustomPaint,
                    // no AnimationController — just a static container.
                    Container(
                      width: veryCompact ? 82 : 108,
                      height: veryCompact ? 82 : 108,
                      decoration: BoxDecoration(
                        gradient: V5.accentGradient,
                        shape: BoxShape.circle,
                        boxShadow: V5.yellowGlow(0.40),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'V',
                        style: V5.text(
                          context,
                          size: veryCompact ? 40 : 52,
                          weight: FontWeight.w900,
                          color: V5.yellowInk,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(height: veryCompact ? V5.space20 : V5.space28),
                    Text(
                      'Đang phân tích',
                      style: veryCompact
                          ? V5.title(context, color: V5.invInk)
                          : V5.titleLg(context, color: V5.invInk),
                    ),
                    if (!veryCompact) ...[
                      const SizedBox(height: V5.space6),
                      Text(
                        'Vika đang đọc chuyển động của bạn.',
                        style: V5.bodySm(context, color: V5.invInkSoft),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Glass progress card.
        Positioned(
          left: V5.gutter,
          right: V5.gutter,
          bottom: bottomInset + 116,
          child: V5Glass(
            borderRadius: V5.radiusLg,
            padding: EdgeInsets.fromLTRB(
              veryCompact ? 16 : 20,
              veryCompact ? 14 : 16,
              veryCompact ? 16 : 20,
              veryCompact ? 14 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const V5PulseDot(color: V5.yellow),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'BÀI 1/2 · ${exerciseName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.eyebrow(context, color: V5.yellow),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _reps.toString(),
                      style: V5.stat(context, color: V5.invInk),
                    ),
                    const SizedBox(width: V5.space4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: V5.space8),
                      child: Text(
                        '/ 5',
                        style: V5.title(context, color: V5.invInkSoft),
                      ),
                    ),
                    const SizedBox(width: V5.space10),
                    Expanded(
                      child: Text(
                        'NHỊP HOÀN THÀNH',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.eyebrow(context, color: V5.invInkSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _reps / 5),
                    duration: const Duration(milliseconds: 380),
                    curve: V5.curve,
                    builder: (_, value, __) => LinearProgressIndicator(
                      minHeight: 4,
                      value: value,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(V5.yellow),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        V5PillCTA(
          label: 'Hoàn thành đánh giá',
          onTap: widget.onNext,
          yellow: true,
          bottom: 32 + bottomInset,
        ),
      ],
    );
  }
}
