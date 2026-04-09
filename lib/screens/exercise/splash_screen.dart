import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/post_exercise_data.dart';
import '../../theme/vf_theme.dart';
import 'widgets/form_score_arc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.report,
    required this.onDone,
  });

  final PostExerciseData report;
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  Timer? _transitionTimer;
  bool _didFinish = false;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _transitionTimer = Timer(const Duration(seconds: 3), _finish);
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _finish() {
    if (_didFinish) return;
    _didFinish = true;
    widget.onDone();
  }

  Color get _scoreColor {
    if (widget.report.formScore >= 80) return const Color(0xFF4ADE80);
    if (widget.report.formScore >= 50) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  String get _message {
    if (widget.report.formScore >= 80) return 'Xuất sắc';
    if (widget.report.formScore >= 50) return 'Tốt lắm';
    return 'Hoàn thành';
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F3D33),
              Color(0xFF18594A),
              Color(0xFF102B24),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(progress: _confettiController.value),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24 * s, 22 * s, 24 * s, 22 * s),
                child: Column(
                  children: [
                    Text(
                      'HOÀN THÀNH BÀI TẬP',
                      style: VFTheme.textStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.74),
                        letterSpacing: 1.8,
                      ),
                    ),
                    const Spacer(),
                    FormScoreArc(
                      progress: widget.report.formScore / 100,
                      size: 196 * s,
                      color: _scoreColor,
                      trackColor: Colors.white.withValues(alpha: 0.12),
                      strokeWidth: 12 * s,
                      glow: true,
                      duration: const Duration(milliseconds: 1500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${widget.report.formScore}%',
                            style: VFTheme.textStyle(
                              context,
                              size: 34,
                              weight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            'Form score',
                            style: VFTheme.textStyle(
                              context,
                              size: 11,
                              weight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 22 * s),
                    Text(
                      _message,
                      style: VFTheme.textStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 18 * s),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16 * s,
                        vertical: 14 * s,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18 * s),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SplashStat(
                              label: 'Reps',
                              value: '${widget.report.totalReps}',
                            ),
                          ),
                          Expanded(
                            child: _SplashStat(
                              label: 'Sets',
                              value: '${widget.report.sets.length}',
                            ),
                          ),
                          Expanded(
                            child: _SplashStat(
                              label: 'Đúng form',
                              value:
                                  '${widget.report.totalGoodReps}/${widget.report.totalReps}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'tap để tiếp tục',
                      style: VFTheme.textStyle(
                        context,
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.54),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashStat extends StatelessWidget {
  const _SplashStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: VFTheme.textStyle(
            context,
            size: 19,
            weight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: VFTheme.textStyle(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.64),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  static const List<Color> _palette = [
    Color(0xFF4ADE80),
    Color(0xFFFBBF24),
    Color(0xFFF87171),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 30; index++) {
      final seed = index + 1;
      final randomX = (math.sin(seed * 12.4) + 1) / 2;
      final randomDrift = math.cos(seed * 8.2);
      final randomDelay = ((seed * 37) % 100) / 100;
      final localProgress = ((progress + randomDelay) % 1.0);
      final x = size.width * randomX + randomDrift * 18 * localProgress;
      final y = size.height * localProgress - 28;
      final rotation = (progress * math.pi * (seed.isEven ? 2 : -2));
      final color = _palette[index % _palette.length].withValues(alpha: 0.9);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final paint = Paint()..color = color;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 14),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
