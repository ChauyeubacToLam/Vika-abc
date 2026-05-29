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
  late final PageController _pageController;
  Timer? _barTimer;
  bool _showBars = false;

  List<AssessmentResultData> get _results {
    if (widget.data.fork == 'yoga') return yogaResultsMock;
    return [
      squatResultFromData(widget.data),
      homeResultsMock[1],
    ];
  }

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _pageController = PageController();
    _replayAnimations();
  }

  @override
  void dispose() {
    _barTimer?.cancel();
    _pageController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _setTab(int index, {bool animatePage = true}) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _replayAnimations();
    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: V5.curveSharp,
      );
    }
  }

  void _replayAnimations() {
    _barTimer?.cancel();
    setState(() => _showBars = false);
    _scoreController.forward(from: 0);
    _barTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showBars = true);
    });
  }

  void _toggleFeedbackFor(AssessmentResultData ex, String id) {
    setState(() {
      final feedback = widget.data.feedbackByExercise[ex.id] ?? <String>[];
      final next = List<String>.from(feedback);
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      widget.data.feedbackByExercise[ex.id] = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final r = V5Responsive.of(context);
    return V5Page(
      index: 11,
      onBack: widget.onBack,
      cta: V5PillCTA(label: 'Tiếp tục', onTap: widget.onNext),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5ScreenHeader(
            eyebrow: 'Kết quả đánh giá',
            title: 'Đây là\nkết quả của bạn.',
            size: r.isShort ? V5HeaderSize.medium : V5HeaderSize.large,
          ),
          SizedBox(height: r.pick(cozy: V5.space20, short: V5.space14)),
          _ExerciseTabs(
            results: results,
            currentTab: _tab,
            onTap: (index) => _setTab(index),
          ),
          SizedBox(height: r.pick(cozy: V5.space14, short: V5.space10)),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: results.length,
              onPageChanged: (index) => _setTab(index, animatePage: false),
              itemBuilder: (context, index) {
                final ex = results[index];
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DataCard(
                        ex: ex,
                        scoreAnimation: _scoreController,
                        showBars: _showBars,
                      ),
                      const SizedBox(height: V5.space12),
                      _AnalysisCard(
                        ex: ex,
                        selected: widget.data.feedbackByExercise[ex.id] ??
                            const <String>[],
                        onToggle: (id) => _toggleFeedbackFor(ex, id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!r.isShort) ...[
            const SizedBox(height: V5.space8),
            Center(
              child: _SwipeHint(current: _tab, total: results.length),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Exercise segment control
// ─────────────────────────────────────────────────────────────

class _ExerciseTabs extends StatelessWidget {
  const _ExerciseTabs({
    required this.results,
    required this.currentTab,
    required this.onTap,
  });

  final List<AssessmentResultData> results;
  final int currentTab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusMd),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: Row(
        children: results.asMap().entries.map((entry) {
          final i = entry.key;
          final active = currentTab == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: V5.curveSharp,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: active ? V5.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(V5.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.value.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.titleSm(
                    context,
                    color: active ? V5.invInk : V5.inkSoft,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final width = math.min(300.0, MediaQuery.sizeOf(context).width - 44);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: V5.ink.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(V5.radiusFull),
          border: Border.all(color: V5.border),
        ),
        child: Row(
          children: [
            Icon(Icons.swipe_rounded, size: 14, color: V5.inkSoft),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Vuốt ngang để xem bài khác',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V5.caption(context, color: V5.inkSoft),
              ),
            ),
            const SizedBox(width: 10),
            for (var i = 0; i < total; i++)
              Container(
                width: i == current ? 14 : 5,
                height: 5,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i == current ? V5.ink : V5.inkDim,
                  borderRadius: BorderRadius.circular(V5.radiusFull),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Data card — premium dark editorial with score + bar chart
// ─────────────────────────────────────────────────────────────

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.ex,
    required this.scoreAnimation,
    required this.showBars,
  });

  final AssessmentResultData ex;
  final Animation<double> scoreAnimation;
  final bool showBars;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
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

    final targetFraction = barFraction(ex.chartTarget);
    bool isOk(int value) =>
        ex.lowerIsBetter ? value <= ex.chartTarget : value >= ex.chartTarget;

    return V5HeroCard(
      borderRadius: V5.radiusLg,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: V5AmbientGlow(
              size: const Size(240, 240),
              opacity: 0.18,
              color: V5.yellow,
            ),
          ),
          Column(
            children: [
              // Top — score region.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 16 : 22,
                  narrow ? 18 : 22,
                  narrow ? 16 : 22,
                  narrow ? 14 : 18,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.metric.toUpperCase(),
                            style: V5.eyebrow(context, color: V5.invInkSoft),
                          ),
                          const SizedBox(height: 10),
                          AnimatedBuilder(
                            animation: scoreAnimation,
                            builder: (context, _) {
                              final eased =
                                  1 - math.pow(1 - scoreAnimation.value, 3);
                              final score = (ex.score * eased).round();
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$score',
                                      style: V5
                                          .stat(context, color: V5.yellow)
                                          .copyWith(fontSize: narrow ? 42 : 58),
                                    ),
                                    const SizedBox(width: 6),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        ex.scoreUnit,
                                        style: V5
                                            .titleLg(
                                              context,
                                              color: V5.yellow,
                                            )
                                            .copyWith(
                                                fontSize: narrow ? 14 : 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ex.metricLabel,
                            style: V5.bodySm(context, color: V5.invInkSoft),
                          ),
                        ],
                      ),
                    ),
                    // Numeric quality badge — refined "verdict" pill.
                    Flexible(
                        child: Align(
                      alignment: Alignment.centerRight,
                      child: _ScoreVerdict(ex: ex),
                    )),
                  ],
                ),
              ),
              const V5Divider(dark: true),
              // Bottom — chart.
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ex.chartTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V5.eyebrow(context, color: V5.invInk),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 1.5,
                                color: V5.yellow.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Mục tiêu ${ex.chartTarget}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V5.caption(
                                    context,
                                    color: V5.invInkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _BarChart(
                      values: ex.chartData,
                      barFraction: barFraction,
                      targetFraction: targetFraction,
                      isOk: isOk,
                      showBars: showBars,
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

// ─────────────────────────────────────────────────────────────
// Score verdict — pill that says "Tốt" / "Cần cải thiện"
// ─────────────────────────────────────────────────────────────

class _ScoreVerdict extends StatelessWidget {
  const _ScoreVerdict({required this.ex});

  final AssessmentResultData ex;

  @override
  Widget build(BuildContext context) {
    final passed = ex.lowerIsBetter
        ? ex.score <= ex.chartTarget
        : ex.score >= ex.chartTarget;
    final label = passed ? 'TRÊN MỤC TIÊU' : 'CẦN ĐỘ SÂU';
    final color = passed ? V5.success : V5.yellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(passed ? Icons.check_rounded : Icons.trending_up_rounded,
                color: color, size: 12),
            const SizedBox(width: 6),
            Text(
              label,
              style: V5.eyebrow(context, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bar chart — with dashed target line + per-rep bars
// ─────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.barFraction,
    required this.targetFraction,
    required this.isOk,
    required this.showBars,
  });

  final List<int> values;
  final double Function(num value) barFraction;
  final double targetFraction;
  final bool Function(int value) isOk;
  final bool showBars;

  @override
  Widget build(BuildContext context) {
    const valueLabelHeight = 14.0;
    const repLabelHeight = 14.0;
    const valueGap = 4.0;
    const repGap = 8.0;
    const barAreaHeight = 88.0;
    final totalHeight =
        valueLabelHeight + valueGap + barAreaHeight + repGap + repLabelHeight;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // Dashed target line — overlays the bar area at the
          // appropriate fraction.
          Positioned(
            left: 0,
            right: 0,
            top: valueLabelHeight +
                valueGap +
                (1 - targetFraction) * barAreaHeight,
            child: CustomPaint(
              size: const Size.fromHeight(1),
              painter: _DashedLine(color: V5.yellow.withValues(alpha: 0.45)),
            ),
          ),

          // Bars.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values.asMap().entries.map((entry) {
              final i = entry.key;
              final value = entry.value;
              final ok = isOk(value);
              final barH = barFraction(value) * barAreaHeight;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: valueLabelHeight + valueGap + barAreaHeight,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            _GrowingBar(
                              visible: showBars,
                              delayMs: i * 110,
                              height: barH,
                              color: ok
                                  ? V5.yellow
                                  : V5.yellow.withValues(alpha: 0.32),
                              border: ok
                                  ? V5.yellowDeep.withValues(alpha: 0.4)
                                  : V5.invInkFaint,
                            ),
                            Positioned(
                              bottom: barH + 2,
                              child: Text(
                                '$value',
                                style: V5.text(
                                  context,
                                  size: 9.5,
                                  weight: FontWeight.w700,
                                  color: ok ? V5.yellow : V5.invInkSoft,
                                  letterSpacing: -0.1,
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
                            size: 9.5,
                            weight: FontWeight.w600,
                            color: V5.invInkSoft,
                            letterSpacing: 0.4,
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
  }
}

class _DashedLine extends CustomPainter {
  _DashedLine({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dashWidth = 5.0;
    const dashGap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLine old) => old.color != color;
}

class _GrowingBar extends StatefulWidget {
  const _GrowingBar({
    required this.visible,
    required this.delayMs,
    required this.height,
    required this.color,
    required this.border,
  });

  final bool visible;
  final int delayMs;
  final double height;
  final Color color;
  final Color border;

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
      duration: const Duration(milliseconds: 420),
      curve: V5.curve,
      height: _grow ? widget.height : 0,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        border: Border.all(color: widget.border, width: 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Analysis card — Vika coaching feedback + self-report chips
// ─────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            V5.yellow.withValues(alpha: 0.08),
            V5.yellow.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: V5.yellow.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(V5.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: V5.yellow,
              borderRadius: BorderRadius.circular(V5.radiusFull),
            ),
            child: Row(
              children: [
                const V5Sparkle(size: 11, color: V5.yellowInk),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'VIKA PHÁT HIỆN · ${ex.detectedPattern}'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V5
                        .eyebrow(context, color: V5.yellowInk)
                        .copyWith(letterSpacing: 1.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: V5.space12),
          Text(
            ex.coachBody,
            style: V5.body(context),
          ),
          const SizedBox(height: V5.space12),
          const V5Divider(),
          const SizedBox(height: V5.space12),
          Text(
            ex.questionTitle,
            style: V5.titleSm(context),
          ),
          const SizedBox(height: 4),
          Text(
            ex.questionSub,
            style: V5.bodySm(context, color: V5.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ex.candidates.map((c) {
              final isSel = selected.contains(c.id);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggle(c.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: V5.curveSharp,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? V5.ink : V5.surface,
                      borderRadius: BorderRadius.circular(V5.radiusFull),
                      border: Border.all(
                        color: isSel ? V5.ink : V5.borderHi,
                        width: isSel ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSel) ...[
                          const Icon(Icons.check_rounded,
                              color: V5.yellow, size: 13),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            c.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V5.text(
                              context,
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: isSel ? V5.invInk : V5.ink,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
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
