import 'package:flutter/material.dart';
import 'package:vika/widgets/pose_silhouette.dart';
import 'package:vika/widgets/vf_primitives.dart';

import '../vf_theme.dart';

class AnalyzingPage extends StatefulWidget {
  const AnalyzingPage({
    super.key,
    required this.active,
    required this.onNext,
  });

  final bool active;
  final VoidCallback onNext;

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _armAdvanceIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AnalyzingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _armAdvanceIfNeeded();
  }

  void _armAdvanceIfNeeded() {
    if (_armed || !widget.active) return;
    _armed = true;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && widget.active) {
        widget.onNext();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VF.surfaceDark,
            VF.jadeDark,
            Color(0xFF0A2E22),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: VFGrainOverlay(opacity: 0.035)),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120 * s,
                      height: 120 * s,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _PulseRing(
                            scale: 1 + (_controller.value * 0.18),
                            opacity: 0.30 - (_controller.value * 0.18),
                            strokeWidth: 3 * s,
                          ),
                          _PulseRing(
                            scale: 0.72 + (_controller.value * 0.12),
                            opacity: 0.15 - (_controller.value * 0.08),
                            strokeWidth: 2 * s,
                          ),
                          PoseSilhouette(
                            type: 'squat',
                            size: 34 * s,
                            color: VF.jadeGlow.withValues(alpha: 0.60),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32 * s),
                    Text(
                      'Đang phân tích...',
                      style: VF.textStyle(
                        context,
                        size: 22,
                        weight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      'AI đang xử lý 33 điểm cơ thể từ bài tập của bạn',
                      textAlign: TextAlign.center,
                      style: VF.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.30),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24 * s),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final progress =
                            ((_controller.value + (index * 0.18)) % 1.0);
                        return Container(
                          width: 8 * s,
                          height: 8 * s,
                          margin: EdgeInsets.symmetric(horizontal: 3 * s),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VF.jadeGlow.withValues(
                              alpha: 0.20 + ((1 - progress) * 0.45),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.scale,
    required this.opacity,
    required this.strokeWidth,
  });

  final double scale;
  final double opacity;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 100 * s,
        height: 100 * s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: VF.jadeGlow.withValues(
              alpha: opacity.clamp(0.0, 1.0),
            ),
            width: strokeWidth,
          ),
        ),
      ),
    );
  }
}
