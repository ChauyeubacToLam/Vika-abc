import 'dart:async';

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

/// S08 — the post-assessment "analyzing" beat. A brief, on-brand moment that
/// reads the captured movement: the real Vika mark + name, an italic display
/// headline, and a staged checklist that ticks through the actual analysis
/// steps (depth/form → compare to standard → compute level). Auto-advances to
/// S09 once the steps complete; a quiet hint lets the user skip the wait.
///
/// Only ever shown when both assessment legs were captured — the skip path
/// jumps straight to the level picker — so it never has to handle empty data.
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

class _S08AnalyzingState extends State<S08Analyzing>
    with SingleTickerProviderStateMixin {
  static const _stepDuration = Duration(milliseconds: 820);

  late final AnimationController _halo;
  Timer? _stepTimer;
  int _completedSteps = 0;
  bool _advanced = false;

  List<String> get _steps => widget.data.fork == 'yoga'
      ? const [
          'Đánh giá mức độ thăng bằng',
          'So sánh với  động tác chuẩn',
          'Xác định level & điểm cần cải thiện',
        ]
      : const [
          'Đánh giá độ sâu & form',
          'So sánh với  động tác chuẩn',
          'Xác định level & điểm cần cải thiện',
        ];

  @override
  void initState() {
    super.initState();
    _halo = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant S08Analyzing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _start();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _halo.dispose();
    super.dispose();
  }

  void _start() {
    _stepTimer?.cancel();
    _advanced = false;
    setState(() => _completedSteps = 0);
    _stepTimer = Timer.periodic(_stepDuration, (timer) {
      if (!mounted) return;
      setState(() => _completedSteps = (_completedSteps + 1).clamp(0, 3));
      if (_completedSteps >= 3) {
        timer.cancel();
        _scheduleAdvance(const Duration(milliseconds: 640));
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

  /// Skip the remaining wait — jump straight to the results.
  void _finishNow() {
    if (_advanced) return;
    _advanced = true;
    _stepTimer?.cancel();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final veryCompact = r.isVeryShort;
    final bottomInset = r.viewPadding.bottom;
    final topPad = veryCompact ? 46.0 : 60.0;

    return V5Screen(
      index: 10,
      onBack: widget.onBack,
      inverted: true,
      background: V5.heroBg,
      children: [
        // Atmosphere — twin glows + film grain.
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
        const Positioned.fill(
          child: V5Texture(opacity: 0.05, density: 1.3),
        ),

        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                V5.gutter,
                topPad,
                V5.gutter,
                bottomInset + V5.space16,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          V5FadeIn(
                            slideY: 10,
                            child: _BrandLockup(
                              halo: _halo,
                              compact: veryCompact,
                            ),
                          ),
                          SizedBox(
                            height: veryCompact ? V5.space20 : V5.space28,
                          ),
                          V5FadeIn(
                            delay: const Duration(milliseconds: 140),
                            slideY: 10,
                            child: Text(
                              'Đang phân tích\nchuyển động của bạn',
                              textAlign: TextAlign.center,
                              style: (veryCompact
                                      ? V5.titleLg(context, color: V5.invInk)
                                      : V5.headline(context, color: V5.invInk))
                                  .copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.08,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  V5FadeIn(
                    delay: const Duration(milliseconds: 240),
                    slideY: 14,
                    child: _AnalysisCard(
                      steps: _steps,
                      completed: _completedSteps,
                      compact: veryCompact,
                    ),
                  ),
                  SizedBox(height: veryCompact ? V5.space10 : V5.space14),
                  _ContinueHint(onTap: _finishNow),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Brand lockup — the real Vika mark + name, breathing halo
// ─────────────────────────────────────────────────────────────

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.halo, required this.compact});

  final Animation<double> halo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tile = compact ? 64.0 : 78.0;
    return AnimatedBuilder(
      animation: halo,
      builder: (context, _) {
        final t = halo.value; // 0 → 1 → 0
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tile,
              height: tile,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: V5.yellow.withValues(alpha: 0.26 + 0.22 * t),
                    blurRadius: 32 + 18 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                  BoxShadow(
                    color: const Color(0xFF120D08).withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/branding/Logo.jpeg',
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: compact ? V5.space10 : V5.space14),
            Text(
              'VIKA',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: compact ? 17 : 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                height: 1,
                color: V5.invInk,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Analysis card — staged checklist + slim progress
// ─────────────────────────────────────────────────────────────

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.steps,
    required this.completed,
    required this.compact,
  });

  final List<String> steps;
  final int completed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return V5Glass(
      borderRadius: V5.radiusLg,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 14 : 18,
        compact ? 16 : 20,
        compact ? 14 : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const V5PulseDot(color: V5.yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PHÂN TÍCH FORM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.eyebrow(context, color: V5.yellow),
                ),
              ),
              Text(
                '${completed.clamp(0, steps.length)}/${steps.length}',
                style: V5.eyebrow(context, color: V5.invInkSoft),
              ),
            ],
          ),
          SizedBox(height: compact ? V5.space12 : V5.space14),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? V5.space8 : V5.space10),
            _AnalysisStepRow(
              label: steps[i],
              state: i < completed
                  ? _StepState.done
                  : i == completed
                      ? _StepState.active
                      : _StepState.pending,
            ),
          ],
          SizedBox(height: compact ? V5.space12 : V5.space16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completed / steps.length),
              duration: const Duration(milliseconds: 420),
              curve: V5.curve,
              builder: (_, value, __) => LinearProgressIndicator(
                minHeight: 4,
                value: value,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(V5.yellow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _AnalysisStepRow extends StatelessWidget {
  const _AnalysisStepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final faded = state == _StepState.pending;
    return Row(
      children: [
        _StepIndicator(state: state),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V5
                .body(
                  context,
                  color: faded ? V5.invInkFaint : V5.invInk,
                )
                .copyWith(
                  fontWeight: faded ? FontWeight.w500 : FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.state});

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    switch (state) {
      case _StepState.done:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: V5.yellow,
            shape: BoxShape.circle,
            boxShadow: V5.yellowGlow(0.18),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, size: 14, color: V5.yellowInk),
        );
      case _StepState.active:
        return const SizedBox(
          width: size,
          height: size,
          child: Center(child: V5PulseDot(color: V5.yellow)),
        );
      case _StepState.pending:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: V5.invInkDim, width: 1.4),
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Continue hint — quiet escape hatch from the auto-advance
// ─────────────────────────────────────────────────────────────

class _ContinueHint extends StatelessWidget {
  const _ContinueHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Chạm để bỏ qua',
              style: V5.bodySm(context, color: V5.invInkFaint),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: V5.invInkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
