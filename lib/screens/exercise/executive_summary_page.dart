import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../interpreter/interpreter_base.dart';
import '../../models/post_exercise_data.dart';
import '../../theme/vf_theme.dart';
import 'widgets/form_score_arc.dart';

class ExecutiveSummaryPage extends StatefulWidget {
  const ExecutiveSummaryPage({
    super.key,
    required this.report,
    required this.calories,
    required this.userWeightKg,
    required this.totalDuration,
    required this.onDone,
    this.percentile,
    this.vsLastWeekPct,
  });

  final PostExerciseData report;
  final int calories;
  final double userWeightKg;
  final Duration totalDuration;
  final VoidCallback onDone;
  final int? percentile;
  final int? vsLastWeekPct;

  @override
  State<ExecutiveSummaryPage> createState() => _ExecutiveSummaryPageState();
}

class _ExecutiveSummaryPageState extends State<ExecutiveSummaryPage> {
  final GlobalKey<_DetailSectionState> _detailKey =
      GlobalKey<_DetailSectionState>();

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      color: const Color(0xFFF0EDE6),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16 * s, 16 * s, 16 * s, 28 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TỔNG KẾT BUỔI TẬP',
                style: VFTheme.textStyle(
                  context,
                  size: 11,
                  weight: FontWeight.w800,
                  color: const Color(0xFF9C9B94),
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 12 * s),
              _ShareableCard(
                report: widget.report,
                calories: widget.calories,
                totalDuration: widget.totalDuration,
                percentile: widget.percentile,
                vsLastWeekPct: widget.vsLastWeekPct,
                isShareable: false,
                onOpenDetails: () {
                  _detailKey.currentState?.expandAndReveal();
                },
              ),
              SizedBox(height: 18 * s),
              _SectionCard(
                child: _SetQualitySection(setScores: widget.report.setScores),
              ),
              SizedBox(height: 14 * s),
              _CoachCard(text: widget.report.coachText),
              if (widget.report.issueQuestion != null) ...[
                SizedBox(height: 14 * s),
                _IssueQuestionCard(issue: widget.report.issueQuestion!),
              ],
              SizedBox(height: 14 * s),
              _DetailSection(
                key: _detailKey,
                cards: widget.report.detailCards,
                calories: widget.calories,
              ),
              SizedBox(height: 18 * s),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18594A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16 * s),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14 * s),
                    ),
                  ),
                  child: Text(
                    'Hoàn tất',
                    style: VFTheme.textStyle(
                      context,
                      size: 15,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareableCard extends StatelessWidget {
  const _ShareableCard({
    required this.report,
    required this.calories,
    required this.totalDuration,
    required this.onOpenDetails,
    this.percentile,
    this.vsLastWeekPct,
    this.isShareable = false,
  });

  final PostExerciseData report;
  final int calories;
  final Duration totalDuration;
  final VoidCallback onOpenDetails;
  final int? percentile;
  final int? vsLastWeekPct;
  final bool isShareable;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final accent = _accent(report.formScore);
    final durationMinutes =
        totalDuration.inMinutes > 0 ? totalDuration.inMinutes : 1;
    final stats =
        <({IconData icon, String value, String unit, double progress})>[
      (
        icon: Icons.local_fire_department_rounded,
        value: '$calories',
        unit: 'kcal',
        progress: (calories / 80).clamp(0.0, 1.0),
      ),
      (
        icon: Icons.schedule_rounded,
        value: '$durationMinutes',
        unit: 'phút',
        progress: (durationMinutes / 20).clamp(0.0, 1.0),
      ),
      (
        icon: Icons.fitness_center_rounded,
        value: '${report.totalReps}',
        unit: 'reps',
        progress: (report.totalReps / 24).clamp(0.0, 1.0),
      ),
      (
        icon: Icons.bar_chart_rounded,
        value: '${report.sets.length}',
        unit: 'sets',
        progress: (report.sets.length / 5).clamp(0.0, 1.0),
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24 * s),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF09120F),
                  Color(0xFF10211B),
                  Color(0xFF183128)
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F3D33).withValues(alpha: 0.18),
                  blurRadius: 28 * s,
                  offset: Offset(0, 18 * s),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _GrainPainter())),
                Positioned(
                  top: -24 * s,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 220 * s,
                      height: 220 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(22 * s, 22 * s, 22 * s, 20 * s),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('VINAFIT',
                                    style: VFTheme.textStyle(context,
                                        size: 10,
                                        weight: FontWeight.w900,
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                        letterSpacing: 3.8)),
                                SizedBox(height: 6 * s),
                                Text(report.exerciseName,
                                    style: VFTheme.textStyle(context,
                                        size: 20,
                                        weight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.4)),
                                SizedBox(height: 2 * s),
                                Text(_formatDate(DateTime.now()),
                                    style: VFTheme.textStyle(context,
                                        size: 11,
                                        weight: FontWeight.w600,
                                        color: Colors.white
                                            .withValues(alpha: 0.46))),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10 * s, vertical: 7 * s),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded,
                                    size: 14 * s, color: accent),
                                SizedBox(width: 4 * s),
                                Text('4',
                                    style: VFTheme.textStyle(context,
                                        size: 11,
                                        weight: FontWeight.w800,
                                        color: Colors.white
                                            .withValues(alpha: 0.86))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 22 * s),
                      FormScoreArc(
                        progress: report.formScore / 100,
                        size: 176 * s,
                        color: accent,
                        trackColor: Colors.white.withValues(alpha: 0.05),
                        strokeWidth: 7 * s,
                        glow: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${report.formScore}',
                                style: VFTheme.textStyle(context,
                                    size: 58,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -2.6)),
                            SizedBox(height: 8 * s),
                            Text('FORM SCORE',
                                style: VFTheme.textStyle(context,
                                    size: 9,
                                    weight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.24),
                                    letterSpacing: 3)),
                          ],
                        ),
                      ),
                      SizedBox(height: 18 * s),
                      Text(_winMessage(report.formScore),
                          textAlign: TextAlign.center,
                          style: VFTheme.textStyle(context,
                              size: 16,
                              weight: FontWeight.w800,
                              color: accent,
                              height: 1.35)),
                      if (percentile != null)
                        Text('Top $percentile% người dùng',
                            textAlign: TextAlign.center,
                            style: VFTheme.textStyle(context,
                                size: 16,
                                weight: FontWeight.w800,
                                color: accent,
                                height: 1.35)),
                      if (vsLastWeekPct != null) ...[
                        SizedBox(height: 6 * s),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                  text:
                                      '${vsLastWeekPct! > 0 ? '+' : ''}$vsLastWeekPct%',
                                  style: VFTheme.textStyle(context,
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: accent)),
                              TextSpan(
                                  text: ' so với tuần trước',
                                  style: VFTheme.textStyle(context,
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: Colors.white
                                          .withValues(alpha: 0.40))),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 20 * s),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 16 * s),
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.06)))),
                        child: Row(
                          children: stats
                              .map(
                                (item) => Expanded(
                                  child: _ShareStat(
                                    icon: item.icon,
                                    value: item.value,
                                    unit: item.unit,
                                    progress: item.progress,
                                    accent: accent,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      SizedBox(height: 2 * s),
                      Row(
                          children: report.setScores
                              .asMap()
                              .entries
                              .map((entry) => Expanded(
                                  child: Padding(
                                      padding: EdgeInsets.only(
                                          right: entry.key ==
                                                  report.setScores.length - 1
                                              ? 0
                                              : 6 * s),
                                      child: _SetStrip(score: entry.value))))
                              .toList()),
                      SizedBox(height: 18 * s),
                      if (!isShareable) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Tính năng chia sẻ card sẽ được bật ở bản sau.'))),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(vertical: 13 * s),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14 * s)),
                            ),
                            child: Text('Chia sẻ kết quả',
                                style: VFTheme.textStyle(context,
                                    size: 13,
                                    weight: FontWeight.w800,
                                    color: Colors.black)),
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        GestureDetector(
                          onTap: onOpenDetails,
                          child: Text('Xem chi tiết buổi tập →',
                              style: VFTheme.textStyle(context,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.46))),
                        ),
                      ] else
                        Padding(
                          padding: EdgeInsets.only(top: 4 * s),
                          child: Text('VINAFIT.APP',
                              style: VFTheme.textStyle(context,
                                  size: 8,
                                  weight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.20),
                                  letterSpacing: 2.4)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.progress,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String unit;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Column(
      children: [
        Icon(icon, size: 16 * s, color: accent.withValues(alpha: 0.88)),
        SizedBox(height: 6 * s),
        Text(value,
            style: VFTheme.textStyle(context,
                size: 17, weight: FontWeight.w800, color: Colors.white)),
        SizedBox(height: 2 * s),
        Text(unit,
            style: VFTheme.textStyle(context,
                size: 8,
                weight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.30),
                letterSpacing: 0.3)),
        SizedBox(height: 8 * s),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 3 * s,
            color: Colors.white.withValues(alpha: 0.06),
            child: FractionallySizedBox(
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SetStrip extends StatelessWidget {
  const _SetStrip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6 * s,
        color: Colors.white.withValues(alpha: 0.06),
        child: FractionallySizedBox(
          widthFactor: (score / 100).clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _accent(score),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFE5E2DB)),
        boxShadow: VFTheme.cardShadow,
      ),
      child: child,
    );
  }
}

class _SetQualitySection extends StatelessWidget {
  const _SetQualitySection({required this.setScores});

  final List<int> setScores;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FORM QUALITY TỪNG SET',
            style: VFTheme.textStyle(context,
                size: 10,
                weight: FontWeight.w800,
                color: const Color(0xFF9C9B94),
                letterSpacing: 1.2)),
        SizedBox(height: 14 * s),
        for (int i = 0; i < setScores.length; i++) ...[
          Row(
            children: [
              SizedBox(
                  width: 46 * s,
                  child: Text('Set ${i + 1}',
                      style: VFTheme.textStyle(context,
                          size: 12,
                          weight: FontWeight.w700,
                          color: const Color(0xFF5A5A52)))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 10 * s,
                    color: const Color(0xFFE8E4DD),
                    child: FractionallySizedBox(
                      widthFactor: (setScores[i] / 100).clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _accent(setScores[i]),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10 * s),
              Text('${setScores[i]}%',
                  style: VFTheme.textStyle(context,
                      size: 12,
                      weight: FontWeight.w800,
                      color: _accent(setScores[i]))),
            ],
          ),
          if (i != setScores.length - 1) SizedBox(height: 12 * s),
        ],
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0ED),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFD7E2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 5 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF18594A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('AI',
                style: VFTheme.textStyle(context,
                    size: 10,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8)),
          ),
          SizedBox(height: 10 * s),
          Text(text,
              style: VFTheme.textStyle(context,
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF0F3D33),
                  height: 1.5)),
        ],
      ),
    );
  }
}

class _IssueQuestionCard extends StatefulWidget {
  const _IssueQuestionCard({required this.issue});

  final DetectedEvidence issue;

  @override
  State<_IssueQuestionCard> createState() => _IssueQuestionCardState();
}

class _IssueQuestionCardState extends State<_IssueQuestionCard> {
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    Widget answerButton(String label, String value) {
      final selected = _answer == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _answer = value),
          borderRadius: BorderRadius.circular(12 * s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: 12 * s),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFC4841D) : Colors.white,
              borderRadius: BorderRadius.circular(12 * s),
              border: Border.all(
                  color: selected
                      ? const Color(0xFFC4841D)
                      : const Color(0xFFE8D4A7)),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: VFTheme.textStyle(context,
                    size: 13,
                    weight: FontWeight.w800,
                    color: selected ? Colors.white : const Color(0xFFC4841D))),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E4),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFE8D4A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_issueObservation(widget.issue),
              style: VFTheme.textStyle(context,
                  size: 12,
                  weight: FontWeight.w800,
                  color: const Color(0xFFC4841D))),
          SizedBox(height: 6 * s),
          Text(widget.issue.question,
              style: VFTheme.textStyle(context,
                  size: 14,
                  weight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                  height: 1.45)),
          SizedBox(height: 12 * s),
          Row(children: [
            answerButton('Có', 'yes'),
            SizedBox(width: 8 * s),
            answerButton('Không', 'no')
          ]),
        ],
      ),
    );
  }
}

class _DetailSection extends StatefulWidget {
  const _DetailSection({
    super.key,
    required this.cards,
    required this.calories,
  });

  final List<DetailCard> cards;
  final int calories;

  @override
  State<_DetailSection> createState() => _DetailSectionState();
}

class _DetailSectionState extends State<_DetailSection> {
  final GlobalKey _contentAnchorKey = GlobalKey();
  bool _expanded = false;

  void expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
  }

  void expandAndReveal() {
    void reveal() {
      final anchorContext = _contentAnchorKey.currentContext;
      if (anchorContext == null) return;
      Scrollable.ensureVisible(
        anchorContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    }

    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
      return;
    }

    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      reveal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return _SectionCard(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12 * s),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 2 * s),
              child: Row(
                children: [
                  Text('Chi tiết buổi tập',
                      style: VFTheme.textStyle(context,
                          size: 15,
                          weight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A))),
                  const Spacer(),
                  Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF9C9B94)),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - (12 * s)) / 2;
                final tiles = <Widget>[
                  ...widget.cards.map((card) => _DetailTile(card: card)),
                  _CaloriesTile(calories: widget.calories),
                ];
                return Padding(
                  key: _contentAnchorKey,
                  padding: EdgeInsets.only(top: 14 * s),
                  child: Wrap(
                    spacing: 12 * s,
                    runSpacing: 12 * s,
                    children: tiles
                        .map((tile) => SizedBox(width: itemWidth, child: tile))
                        .toList(),
                  ),
                );
              },
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.card});

  final DetailCard card;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final tone = _detailTone(card.color);
    return Container(
      constraints: BoxConstraints(minHeight: 176 * s),
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0xFFE5E2DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.label,
                  style: VFTheme.textStyle(context,
                      size: 11,
                      weight: FontWeight.w700,
                      color: const Color(0xFF9C9B94))),
              SizedBox(height: 8 * s),
              Text(card.value,
                  style: VFTheme.textStyle(context,
                      size: 24,
                      weight: FontWeight.w900,
                      color: tone,
                      letterSpacing: -0.8)),
              if ((card.subLabel ?? '').isNotEmpty) ...[
                SizedBox(height: 4 * s),
                Text(card.subLabel!,
                    style: VFTheme.textStyle(context,
                        size: 11,
                        weight: FontWeight.w600,
                        color: const Color(0xFF5A5A52))),
              ],
            ],
          ),
          SizedBox(height: 14 * s),
          if (card.useRadial)
            Align(
              alignment: Alignment.centerLeft,
              child: FormScoreArc(
                progress: ((card.radialValue ?? 0) / 100).clamp(0.0, 1.0),
                size: 56 * s,
                color: tone,
                trackColor: tone.withValues(alpha: 0.14),
                strokeWidth: 5 * s,
                child: Text('${(card.radialValue ?? 0).round()}',
                    style: VFTheme.textStyle(context,
                        size: 10, weight: FontWeight.w800, color: tone)),
              ),
            )
          else if ((card.miniBarValues ?? const <double>[]).isNotEmpty)
            SizedBox(
              height: 56 * s,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: card.miniBarValues!.asMap().entries.map((entry) {
                  final max = card.miniBarMax == null || card.miniBarMax == 0
                      ? 1.0
                      : card.miniBarMax!;
                  final ratio = (entry.value / max).clamp(0.0, 1.0);
                  final height = (card.lowerIsBetter ? (1 - ratio) : ratio)
                      .clamp(0.12, 1.0);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: entry.key == card.miniBarValues!.length - 1
                              ? 0
                              : 5 * s),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 56 * s * height,
                          decoration: BoxDecoration(
                              color: tone,
                              borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Container(
              height: 10 * s,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaloriesTile extends StatelessWidget {
  const _CaloriesTile({required this.calories});

  final int calories;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final fill = (calories / 90).clamp(0.0, 1.0);
    return Container(
      constraints: BoxConstraints(minHeight: 176 * s),
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0xFFE5E2DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30 * s,
                height: 30 * s,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EACF),
                  borderRadius: BorderRadius.circular(10 * s),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 16 * s,
                  color: const Color(0xFFC4841D),
                ),
              ),
              SizedBox(height: 12 * s),
              Text('Calories',
                  style: VFTheme.textStyle(context,
                      size: 11,
                      weight: FontWeight.w700,
                      color: const Color(0xFF9C9B94))),
              SizedBox(height: 8 * s),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$calories',
                      style: VFTheme.textStyle(context,
                          size: 24,
                          weight: FontWeight.w900,
                          color: const Color(0xFFC4841D),
                          letterSpacing: -0.8),
                    ),
                    TextSpan(
                      text: ' kcal',
                      style: VFTheme.textStyle(context,
                          size: 12,
                          weight: FontWeight.w700,
                          color: const Color(0xFF8C6A1A)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4 * s),
              Text('Ước tính theo MET và thời lượng buổi tập',
                  style: VFTheme.textStyle(context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFF5A5A52))),
            ],
          ),
          SizedBox(height: 14 * s),
          Container(
            padding: EdgeInsets.all(10 * s),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(12 * s),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 10 * s,
                    color: const Color(0xFFF3E2BE),
                    child: FractionallySizedBox(
                      widthFactor: fill,
                      alignment: Alignment.centerLeft,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFF2B454), Color(0xFFC4841D)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8 * s),
                Text('Năng lượng tiêu hao ước tính',
                    style: VFTheme.textStyle(context,
                        size: 10,
                        weight: FontWeight.w700,
                        color: const Color(0xFF8C6A1A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    final random = math.Random(7);
    for (int i = 0; i < 160; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        0.5 + random.nextDouble() * 0.7,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _accent(int score) => score >= 80
    ? const Color(0xFF4ADE80)
    : score >= 50
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF87171);

Color _detailTone(String color) => switch (color) {
      'amber' => const Color(0xFFC4841D),
      'coral' => const Color(0xFFD4553A),
      _ => const Color(0xFF18594A),
    };

String _winMessage(int score) => score >= 80
    ? 'Xuất sắc. Form rất chắc.'
    : score >= 50
        ? 'Đang tiến bộ rõ rồi.'
        : 'Hoàn thành đủ buổi tập.';

String _issueObservation(DetectedEvidence issue) => switch (issue.issueId) {
      'ankle_mobility' => 'AI thấy gót chân nhấc lên nhiều trong lúc squat.',
      'ankle_mobility_restriction' =>
        'AI thấy cổ chân và thân trên cùng mất ổn định khi xuống sâu.',
      'hip_flexor_overactivity' =>
        'AI thấy thân trên đổ về trước khá nhiều khi xuống squat.',
      'limited_mobility' => 'AI thấy độ sâu hiện tại vẫn còn bị giới hạn.',
      _ => 'AI ghi nhận tín hiệu: ${issue.rawSignal.replaceAll('_', ' ')}.',
    };

String _formatDate(DateTime date) {
  const months = [
    'Thg 1',
    'Thg 2',
    'Thg 3',
    'Thg 4',
    'Thg 5',
    'Thg 6',
    'Thg 7',
    'Thg 8',
    'Thg 9',
    'Thg 10',
    'Thg 11',
    'Thg 12'
  ];
  return '${date.day} ${months[date.month - 1]}';
}
