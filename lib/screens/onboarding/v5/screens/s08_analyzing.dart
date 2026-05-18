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
    setState(() => _reps = widget.data.fork == 'home' && widget.data.hasSquatAssessment ? 5 : 0);
    if (_reps >= 5) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted && widget.active) widget.onNext();
      });
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 420), (timer) {
      if (!mounted) return;
      setState(() => _reps = (_reps + 1).clamp(0, 5));
      if (_reps >= 5) {
        timer.cancel();
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted && widget.active) widget.onNext();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final exerciseName = widget.data.fork == 'yoga' ? 'Warrior I' : 'Squat';
    final pose = widget.data.fork == 'yoga' ? 'lunge' : 'squat';
    return V5Screen(
      index: 8,
      onBack: widget.onBack,
      inverted: true,
      background: V5.heroBg,
      children: [
        Positioned(
          top: -120,
          left: -60,
          child: Container(
            width: 360,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  V5.yellow.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 144,
          left: 0,
          right: 0,
          bottom: 240,
          child: Center(
            child: SizedBox(
              width: 340,
              height: 420,
              child: V5HeroFigure(pose: pose),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 128,
          child: V5Glass(
            borderRadius: 24,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BÀI 1/2 · $exerciseName'.toUpperCase(),
                  style: V5.text(
                    context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: V5.yellow,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$_reps',
                      style: V5.text(
                        context,
                        size: 50,
                        weight: FontWeight.w800,
                        color: V5.invInk,
                        letterSpacing: -2.4,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/5',
                      style: V5.text(
                        context,
                        size: 24,
                        weight: FontWeight.w700,
                        color: V5.invInkSoft,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'REPS ĐÃ HOÀN THÀNH',
                      style: V5.text(
                        context,
                        size: 11,
                        weight: FontWeight.w600,
                        color: V5.invInkSoft,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: _reps / 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(V5.yellow),
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
        ),
      ],
    );
  }
}
