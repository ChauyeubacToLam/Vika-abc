import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S09Phase1 extends StatefulWidget {
  const S09Phase1({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S09Phase1> createState() => _S09Phase1State();
}

class _S09Phase1State extends State<S09Phase1>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _scoreController;
  Timer? _barTimer;
  bool _showBars = false;

  List<AssessmentResultData> get _results {
    if (widget.data.fork == 'yoga') return yogaResultsMock;
    return [
      squatResultFromData(widget.data),
      homeResultsMock[1],
    ];
  }

  AssessmentResultData get _ex => _results[_tab];

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _replayAnimations();
  }

  @override
  void dispose() {
    _barTimer?.cancel();
    _scoreController.dispose();
    super.dispose();
  }

  void _setTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _replayAnimations();
  }

  void _replayAnimations() {
    _barTimer?.cancel();
    setState(() => _showBars = false);
    _scoreController.forward(from: 0);
    _barTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showBars = true);
    });
  }

  void _toggleFeedback(String id) {
    setState(() {
      final feedback = widget.data.feedbackByExercise[_ex.id] ?? <String>[];
      final next = List<String>.from(feedback);
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      widget.data.feedbackByExercise[_ex.id] = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return V5Screen(
      index: 9,
      onBack: widget.onBack,
      children: [
        // Flow layout: header → tabs → expanded scroll content. Replaces
        // the previous trio of fixed-y Positioned blocks that overflowed
        // on screens shorter than 844px.
        Positioned(
          top: 144,
          left: 0,
          right: 0,
          bottom: 32 + 60 + bottomInset + 12, // CTA region + safe gap
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const V5Eyebrow(label: 'Kết quả đánh giá'),
                    const SizedBox(height: 10),
                    Text(
                      'Đánh giá hoàn tất',
                      style: V5.text(
                        context,
                        size: 24,
                        weight: FontWeight.w800,
                        color: V5.ink,
                        letterSpacing: -0.8,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: V5.surface,
                    border: Border.all(color: V5.border),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [V5.cardShadow(0.08)],
                  ),
                  child: Row(
                    children: results.asMap().entries.map((entry) {
                      final i = entry.key;
                      final active = _tab == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _setTab(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? V5.ink : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              entry.value.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.text(
                                context,
                                size: 12,
                                weight: FontWeight.w700,
                                color: active ? V5.invInk : V5.inkSoft,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: V5FadeIn(
                    key: ValueKey(_ex.id),
                    child: Column(
                      children: [
                        _DataCard(
                          ex: _ex,
                          isYoga: widget.data.fork == 'yoga',
                          tab: _tab,
                          scoreAnimation: _scoreController,
                          showBars: _showBars,
                        ),
                        const SizedBox(height: 10),
                        _AnalysisCard(
                          ex: _ex,
                          selected: widget.data.feedbackByExercise[_ex.id] ??
                              const <String>[],
                          onToggle: _toggleFeedback,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Tiếp tục',
          onTap: widget.onNext,
          bottom: 32 + bottomInset,
        ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.ex,
    required this.isYoga,
    required this.tab,
    required this.scoreAnimation,
    required this.showBars,
  });

  final AssessmentResultData ex;
  final bool isYoga;
  final int tab;
  final Animation<double> scoreAnimation;
  final bool showBars;

  @override
  Widget build(BuildContext context) {
    // Chart range — for `lowerIsBetter` (squat depth), tall bars represent
    // *low* values, so we anchor the chart's "top" at chartFloor (best case)
    // and "bottom" at chartMax (worst case). For normal metrics, bottom = 0.
    final dataMax = ex.chartData.reduce(math.max);
    final dataMin = ex.chartData.reduce(math.min);
    final chartMax = ex.lowerIsBetter
        ? math.max(dataMax, ex.chartTarget) + 5.0
        : math.max(dataMax, ex.chartTarget) * 1.1;
    final chartFloor = ex.lowerIsBetter
        ? (ex.chartFloor ?? math.min(dataMin, ex.chartTarget) - 10).toDouble()
        : 0.0;
    double barFraction(num value) {
      if (chartMax - chartFloor <= 0) return 0;
      return ex.lowerIsBetter
          ? ((chartMax - value) / (chartMax - chartFloor)).clamp(0.0, 1.0)
          : ((value - chartFloor) / (chartMax - chartFloor)).clamp(0.0, 1.0);
    }
    bool isOk(int value) =>
        ex.lowerIsBetter ? value <= ex.chartTarget : value >= ex.chartTarget;
    final pose = isYoga ? (tab == 0 ? 'lunge' : 'reach') : (tab == 0 ? 'squat' : 'reach');
    return Container(
      decoration: BoxDecoration(
        gradient: V5.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: V5.heroBorder),
        boxShadow: [V5.cardShadow(0.08)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -30,
            width: 220,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: V5.yellow.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.metric.toUpperCase(),
                            style: V5.text(
                              context,
                              size: 10,
                              weight: FontWeight.w700,
                              color: V5.invInkSoft,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedBuilder(
                            animation: scoreAnimation,
                            builder: (context, _) {
                              final eased =
                                  1 - math.pow(1 - scoreAnimation.value, 3);
                              final score = (ex.score * eased).round();
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$score',
                                    style: V5.text(
                                      context,
                                      size: 48,
                                      weight: FontWeight.w800,
                                      color: V5.yellow,
                                      letterSpacing: -2,
                                      height: .92,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ex.scoreUnit,
                                    style: V5.text(
                                      context,
                                      size: 20,
                                      weight: FontWeight.w700,
                                      color: V5.yellow,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ex.metricLabel,
                            style: V5.text(
                              context,
                              size: 12,
                              weight: FontWeight.w600,
                              color: V5.invInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Opacity(
                        opacity: .70,
                        child: V5HeroFigure(pose: pose),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  children: [
                    Text(
                      ex.chartTitle,
                      style: V5.text(
                        context,
                        size: 11,
                        weight: FontWeight.w700,
                        color: V5.invInk,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Chart layout — three explicit zones in the same Stack so
                    // the dashed target line sits in the SAME coordinate space
                    // as the bar tops. (Codex's previous version put labels
                    // above/below each bar, which shifted the bar baseline by
                    // ~28px and made the line render visually-detached from
                    // the bar tops.)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const valueLabelHeight = 14.0;
                        const repLabelHeight = 14.0;
                        const valueGap = 4.0;
                        const repGap = 4.0;
                        const barAreaHeight = 78.0;
                        final totalHeight = valueLabelHeight +
                            valueGap +
                            barAreaHeight +
                            repGap +
                            repLabelHeight;
                        return SizedBox(
                          height: totalHeight,
                          child: Stack(
                            children: [
                              // Bar columns. Each column draws its own value
                              // label just above the bar via a Stack with
                              // bottom-aligned bar + Positioned label.
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children:
                                    ex.chartData.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final value = entry.value;
                                  final ok = isOk(value);
                                  final barH =
                                      barFraction(value) * barAreaHeight;
                                  return Expanded(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 3),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // Bar drawing zone — fixed height,
                                          // bar bottom-aligned, value label
                                          // sits above bar top.
                                          SizedBox(
                                            height: valueLabelHeight +
                                                valueGap +
                                                barAreaHeight,
                                            child: Stack(
                                              alignment: Alignment.bottomCenter,
                                              clipBehavior: Clip.none,
                                              children: [
                                                _GrowingBar(
                                                  visible: showBars,
                                                  delayMs: i * 90,
                                                  height: barH,
                                                  color: ok
                                                      ? V5.yellow
                                                      : V5.yellow
                                                          .withValues(alpha: 0.4),
                                                ),
                                                Positioned(
                                                  bottom: barH + 1,
                                                  child: Text(
                                                    '$value',
                                                    style: V5.text(
                                                      context,
                                                      size: 9,
                                                      weight: FontWeight.w700,
                                                      color: ok
                                                          ? V5.yellow
                                                          : V5.invInkSoft,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: repGap),
                                          SizedBox(
                                            height: repLabelHeight,
                                            child: Text(
                                              '${i + 1}',
                                              style: V5.text(
                                                context,
                                                size: 9,
                                                weight: FontWeight.w600,
                                                color: V5.invInkSoft,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrowingBar extends StatefulWidget {
  const _GrowingBar({
    required this.visible,
    required this.delayMs,
    required this.height,
    required this.color,
  });

  final bool visible;
  final int delayMs;
  final double height;
  final Color color;

  @override
  State<_GrowingBar> createState() => _GrowingBarState();
}

class _GrowingBarState extends State<_GrowingBar> {
  Timer? _timer;
  bool _grow = false;

  @override
  void didUpdateWidget(covariant _GrowingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.delayMs != widget.delayMs ||
        oldWidget.height != widget.height) {
      _schedule();
    }
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    setState(() => _grow = false);
    if (!widget.visible) return;
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _grow = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: _grow ? widget.height : 0,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.ex,
    required this.selected,
    required this.onToggle,
  });

  final AssessmentResultData ex;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            V5.yellow.withValues(alpha: 0.08),
            V5.yellow.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: V5.yellow.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: V5.yellow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const V5Sparkle(size: 10, color: V5.yellowInk),
                const SizedBox(width: 6),
                Text(
                  'VIKA PHÁT HIỆN · ${ex.detectedPattern}'.toUpperCase(),
                  style: V5.text(
                    context,
                    size: 9,
                    weight: FontWeight.w800,
                    color: V5.yellowInk,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ex.coachBody,
            style: V5.text(
              context,
              size: 13,
              weight: FontWeight.w500,
              color: V5.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: V5.ink.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),
          Text(
            ex.questionTitle,
            style: V5.text(
              context,
              size: 13,
              weight: FontWeight.w800,
              color: V5.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            ex.questionSub,
            style: V5.text(
              context,
              size: 11,
              weight: FontWeight.w500,
              color: V5.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ex.candidates.map((c) {
              final isSel = selected.contains(c.id);
              return GestureDetector(
                onTap: () => onToggle(c.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? V5.ink : V5.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: isSel ? V5.ink : V5.borderHi),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSel) ...[
                        const Icon(Icons.check_rounded, color: V5.yellow, size: 12),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        c.label,
                        style: V5.text(
                          context,
                          size: 11,
                          weight: FontWeight.w700,
                          color: isSel ? V5.invInk : V5.ink,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
