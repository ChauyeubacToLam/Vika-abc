import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../interpreter/interpreter_base.dart';
import '../../models/post_exercise_data.dart';
import '../../services/exercise_comparison_service.dart';
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
    this.isFirstSession = false,
    this.comparison,
    this.streakDays = 0,
    this.percentile,
    this.vsLastWeekPct,
    this.lastOverallDifficulty,
    this.onOverallDifficulty,
    this.sessionProgressLabel,
    this.doneLabel = 'Hoàn tất',
    this.isFinalWorkoutSlot = true,
  });

  final PostExerciseData report;
  final int calories;
  final double userWeightKg;
  final Duration totalDuration;
  final VoidCallback onDone;
  final bool isFirstSession;
  final SessionComparison? comparison;
  final int streakDays;
  final int? percentile;
  final int? vsLastWeekPct;
  final String? lastOverallDifficulty;
  final ValueChanged<String>? onOverallDifficulty;
  final String? sessionProgressLabel;
  final String doneLabel;
  final bool isFinalWorkoutSlot;

  @override
  State<ExecutiveSummaryPage> createState() => _ExecutiveSummaryPageState();
}

class _ExecutiveSummaryPageState extends State<ExecutiveSummaryPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _shimmerController;

  // Cache CurvedAnimations so we don't allocate a fresh listener on every
  // rebuild — undisposed CurvedAnimations stay attached to _entryController
  // and trip framework assertions during teardown.
  late final CurvedAnimation _beat0;
  late final CurvedAnimation _beat1;
  late final CurvedAnimation _beat2;
  late final CurvedAnimation _beat3;
  late final CurvedAnimation _beat4;
  late final CurvedAnimation _beat5;

  /// Tracks which difficulty the user selected. Null = not yet answered.
  /// Done button stays disabled until this is non-null.
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _beat0 = _makeBeat(0.0, 0.24);
    _beat1 = _makeBeat(0.14, 0.38);
    _beat2 = _makeBeat(0.24, 0.58);
    _beat3 = _makeBeat(0.46, 0.78);
    _beat4 = _makeBeat(0.58, 0.86);
    _beat5 = _makeBeat(0.68, 1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entryController.forward();
    });
  }

  @override
  void dispose() {
    _beat0.dispose();
    _beat1.dispose();
    _beat2.dispose();
    _beat3.dispose();
    _beat4.dispose();
    _beat5.dispose();
    _entryController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  CurvedAnimation _makeBeat(double begin, double end) {
    return CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  /// Called when user taps a difficulty emoji on the executive summary.
  /// Writes to DB via screen callback and locks selection.
  void _handleDifficultyTap(String difficulty) {
    if (_selectedDifficulty != null) return;
    setState(() => _selectedDifficulty = difficulty);
    widget.onOverallDifficulty?.call(difficulty);
  }

  void _showShareStub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label sẽ có ở phiên bản sau.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      color: const Color(0xFFF0EDE6),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24 * s, 48 * s, 24 * s, 40 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.sessionProgressLabel != null) ...[
                _SequenceProgressHeader(label: widget.sessionProgressLabel!),
                SizedBox(height: 14 * s),
              ],
              _BeatReveal(
                animation: _beat0,
                child: _HeroPhotoCard(
                  report: widget.report,
                  calories: widget.calories,
                  totalDuration: widget.totalDuration,
                  isFirstSession: widget.isFirstSession,
                  comparison: widget.comparison,
                  streakDays: widget.streakDays,
                  isFinalWorkoutSlot: widget.isFinalWorkoutSlot,
                  onShare: () => _showShareStub('Chỉnh sửa & chia sẻ'),
                  onShareToZalo: () => _showShareStub('Chia sẻ qua Zalo'),
                ),
              ),
              SizedBox(height: 24 * s),
              if (widget.comparison != null && widget.isFinalWorkoutSlot)
                _BeatReveal(
                  animation: _beat1,
                  child: _ComparisonBanner(comparison: widget.comparison!),
                ),
              _BeatReveal(
                animation: _beat2,
                child: _FormTerrainSection(
                  setScores: widget.report.setScores,
                  totalDuration: widget.totalDuration,
                ),
              ),
              SizedBox(height: 24 * s),
              _BeatReveal(
                animation: _beat3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CoachSection(text: widget.report.coachText),
                    if (widget.report.issueQuestion != null) ...[
                      SizedBox(height: 18 * s),
                      _IssueQuestionCard(issue: widget.report.issueQuestion!),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24 * s),
              _BeatReveal(
                animation: _beat4,
                child: _OverallDifficultySection(
                  lastDifficulty: widget.lastOverallDifficulty,
                  selected: _selectedDifficulty,
                  onTap: _handleDifficultyTap,
                ),
              ),
              SizedBox(height: 24 * s),
              _BeatReveal(
                animation: _beat5,
                child: _DoneSection(
                  shimmer: _shimmerController,
                  disabled: _selectedDifficulty == null,
                  label: widget.doneLabel,
                  onDone: widget.onDone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeatReveal extends StatelessWidget {
  const _BeatReveal({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final distance = 18 * VFTheme.scale(context);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value.clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(value);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * distance),
            child: child,
          ),
        );
      },
    );
  }
}

class _SequenceProgressHeader extends StatelessWidget {
  const _SequenceProgressHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Row(
      children: [
        Container(
          width: 7 * s,
          height: 7 * s,
          decoration: const BoxDecoration(
            color: Color(0xFF18594A),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8 * s),
        Text(
          label,
          style: VFTheme.textStyle(
            context,
            size: 10,
            weight: FontWeight.w800,
            color: const Color(0xFF5A5A52),
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _HeroPhotoCard extends StatelessWidget {
  const _HeroPhotoCard({
    required this.report,
    required this.calories,
    required this.totalDuration,
    required this.isFirstSession,
    required this.comparison,
    required this.streakDays,
    required this.isFinalWorkoutSlot,
    required this.onShare,
    required this.onShareToZalo,
  });

  final PostExerciseData report;
  final int calories;
  final Duration totalDuration;
  final bool isFirstSession;
  final SessionComparison? comparison;
  final int streakDays;
  final bool isFinalWorkoutSlot;
  final VoidCallback onShare;
  final VoidCallback onShareToZalo;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final accent = _accent(report.formScore);
    final headline = isFinalWorkoutSlot
        ? _scoreHeadline(report.formScore)
        : 'Bài này đã xong';
    final subtitle = isFinalWorkoutSlot
        ? _heroSubtitle(
            score: report.formScore,
            comparison: comparison,
            isFirstSession: isFirstSession,
          )
        : 'Nghỉ một chút rồi bắt đầu bài tiếp nhé.';

    return Container(
      height: 420 * s,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 60 * s,
            offset: Offset(0, 20 * s),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A2A3A),
                    Color(0xFF0D1925),
                    Color(0xFF0A1520),
                    Color(0xFF0E1D16),
                  ],
                  stops: [0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 84 * s,
            right: 95 * s,
            child: _HeroGlow(
              width: 120 * s,
              height: 200 * s,
              opacity: 0.04,
            ),
          ),
          Positioned(
            top: 126 * s,
            right: 108 * s,
            child: _HeroGlow(
              width: 60 * s,
              height: 80 * s,
              opacity: 0.06,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _HeroSkeletonPainter()),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(18 * s),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32 * s,
                        height: 32 * s,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF18594A), Color(0xFF34D399)],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          'N',
                          style: VFTheme.textStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Người tập',
                            style: VFTheme.textStyle(
                              context,
                              size: 13,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2 * s),
                          Text(
                            _formatHeroDate(DateTime.now()),
                            style: VFTheme.textStyle(
                              context,
                              size: 9,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.exerciseName} · ${report.sets.length} hiệp · ${_formatReportWork(report)}',
                        style: VFTheme.textStyle(
                          context,
                          size: 10,
                          weight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 6 * s),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FormScoreArc(
                            progress: report.formScore / 100,
                            size: 52 * s,
                            strokeWidth: 3.5 * s,
                            color: accent,
                            trackColor: Colors.white.withValues(alpha: 0.12),
                            duration: const Duration(milliseconds: 1800),
                            child: Text(
                              '${report.formScore}',
                              style: VFTheme.textStyle(
                                context,
                                size: 15,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12 * s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headline,
                                  style: VFTheme.textStyle(
                                    context,
                                    size: 20,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: 2 * s),
                                Text(
                                  subtitle,
                                  style: VFTheme.textStyle(
                                    context,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10 * s),
                      Container(
                        padding: EdgeInsets.only(top: 10 * s),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _HeroStat(
                                label: 'Thời gian',
                                value: _formatClock(totalDuration),
                              ),
                            ),
                            Expanded(
                              child: _HeroStat(
                                label: 'Calories',
                                value: '~$calories',
                              ),
                            ),
                            Expanded(
                              child: _HeroStat(
                                label: 'Chuỗi',
                                value: _heroStreakValue(streakDays),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      if (isFinalWorkoutSlot)
                        Row(
                          children: [
                            Expanded(
                              child: _HeroActionButton(
                                onTap: onShare,
                                label: 'Chỉnh sửa & chia sẻ',
                                icon: Icons.edit_outlined,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                borderColor:
                                    Colors.white.withValues(alpha: 0.12),
                                textColor: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8 * s),
                            _HeroActionButton(
                              onTap: onShareToZalo,
                              label: 'Zalo',
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              borderColor: Colors.white.withValues(alpha: 0.08),
                              textColor: Colors.white.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* Text(
          value,
          style: VFTheme.textStyle(
            context,
            size: 15,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ), */
        SizedBox(height: 2 * s),
        if (DateTime.now().millisecondsSinceEpoch < 0)
          Text(
            label,
            style: VFTheme.textStyle(
              context,
              size: 8,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.onTap,
    required this.label,
    required this.fillColor,
    required this.borderColor,
    required this.textColor,
    this.icon,
  });

  final VoidCallback onTap;
  final String label;
  final Color fillColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12 * s),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12 * s),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14 * s, color: textColor),
                SizedBox(width: 6 * s),
              ],
              Text(
                label,
                style: VFTheme.textStyle(
                  context,
                  size: 12,
                  weight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonBanner extends StatelessWidget {
  const _ComparisonBanner({required this.comparison});

  final SessionComparison comparison;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final style = _stylingFor(comparison.type);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
      margin: EdgeInsets.only(bottom: 24 * s),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: style.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      style.icon,
                      size: 18 * s,
                      color: style.primaryColor,
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: Text(
                        comparison.primaryLine,
                        style: VFTheme.textStyle(
                          context,
                          size: 14,
                          weight: FontWeight.w700,
                          color: style.primaryColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (comparison.isPainLinked) ...[
                SizedBox(width: 8 * s),
                _PainLinkedChip(color: style.primaryColor),
              ],
            ],
          ),
          if (comparison.secondaryLine != null) ...[
            SizedBox(height: 5 * s),
            Padding(
              padding: EdgeInsets.only(left: 26 * s),
              child: Text(
                comparison.secondaryLine!,
                style: VFTheme.textStyle(
                  context,
                  size: 11,
                  weight: FontWeight.w500,
                  color: style.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BannerStyling _stylingFor(ComparisonType type) {
    switch (type) {
      case ComparisonType.personalBestFormScore:
      case ComparisonType.personalBestFault:
        return const _BannerStyling(
          background: Color(0xFFE8F0ED),
          border: Color(0xFFC5D9CF),
          primaryColor: Color(0xFF0F3D33),
          icon: Icons.emoji_events_rounded,
        );
      case ComparisonType.improvementStreak:
      case ComparisonType.consistencyStreak:
        return const _BannerStyling(
          background: Color(0xFFF5EEE0),
          border: Color(0xFFE4D6B8),
          primaryColor: Color(0xFF8A5A20),
          icon: Icons.local_fire_department_rounded,
        );
      case ComparisonType.aboveAverage:
        return const _BannerStyling(
          background: Color(0xFFF0EBF5),
          border: Color(0xFFD7CCE0),
          primaryColor: Color(0xFF5E3E8A),
          icon: Icons.trending_up_rounded,
        );
      case ComparisonType.deltaPositive:
        return const _BannerStyling(
          background: Color(0xFFFFFFFF),
          border: Color(0xFFE5E2DB),
          primaryColor: Color(0xFF18594A),
          icon: Icons.auto_awesome_rounded,
        );
      case ComparisonType.formSolid:
        return const _BannerStyling(
          background: Color(0xFFF4F1EA),
          border: Color(0xFFDCD8CF),
          primaryColor: Color(0xFF18594A),
          icon: Icons.check_circle_outline_rounded,
        );
      case ComparisonType.sessionComplete:
        return const _BannerStyling(
          background: Color(0xFFEEEBE5),
          border: Color(0xFFD8D4CB),
          primaryColor: Color(0xFF5A5A52),
          icon: Icons.check_circle_outline_rounded,
        );
      case ComparisonType.none:
        return const _BannerStyling(
          background: Color(0xFFFFFFFF),
          border: Color(0xFFE5E2DB),
          primaryColor: Color(0xFF18594A),
          icon: Icons.auto_awesome_rounded,
        );
    }
  }
}

class _BannerStyling {
  const _BannerStyling({
    required this.background,
    required this.border,
    required this.primaryColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color primaryColor;
  final IconData icon;
}

class _PainLinkedChip extends StatelessWidget {
  const _PainLinkedChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.center_focus_strong_rounded, size: 10 * s, color: color),
          SizedBox(width: 4 * s),
          Text(
            'Vùng cơ nhắm tới',
            style: VFTheme.textStyle(
              context,
              size: 9,
              weight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormTerrainSection extends StatelessWidget {
  const _FormTerrainSection({
    required this.setScores,
    required this.totalDuration,
  });

  final List<int> setScores;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final durationMinutes = math.max(totalDuration.inMinutes, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HÀNH TRÌNH FORM',
              style: VFTheme.textStyle(
                context,
                size: 10,
                weight: FontWeight.w700,
                color: const Color(0xFFB5B3AC),
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${setScores.length} hiệp · $durationMinutes phút',
              style: VFTheme.textStyle(
                context,
                size: 11,
                weight: FontWeight.w600,
                color: const Color(0xFF9C9B94),
              ),
            ),
          ],
        ),
        SizedBox(height: 16 * s),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = 196 * s;
            return SizedBox(
              width: width,
              height: height,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) {
                  return CustomPaint(
                    painter: _FormTerrainPainter(
                      setScores: setScores,
                      progress: progress,
                      scale: s,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FormTerrainPainter extends CustomPainter {
  const _FormTerrainPainter({
    required this.setScores,
    required this.progress,
    required this.scale,
  });

  final List<int> setScores;
  final double progress;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (setScores.isEmpty) return;

    final isDense = setScores.length >= 5;
    final chartTop = 22 * scale;
    final chartBottom = size.height - (20 * scale);
    final padY = 20 * scale;
    final pointRadius = (isDense ? 6 : 7) * scale;
    final bestPointRadius = (isDense ? 8.5 : 10) * scale;
    final bestGlowRadius = (isDense ? 14 : 18) * scale;
    final padX = math.max((isDense ? 28 : 36) * scale, bestGlowRadius);
    final chartLeft = padX;
    final chartRight = size.width - padX;
    final innerTop = chartTop + padY;
    final innerBottom = chartBottom - padY;
    final innerHeight = innerBottom - innerTop;
    final chartWidth = chartRight - chartLeft;
    final scoreLabelGap = (isDense ? 16 : 18) * scale;
    final setLabelGap = (isDense ? 24 : 28) * scale;
    final bestLabelGap = (isDense ? 35 : 40) * scale;
    final scoreFontSize = (isDense ? 11.5 : 13) * scale;
    final bestScoreFontSize = (isDense ? 13 : 16) * scale;
    final setLabelFontSize = (isDense ? 8.5 : 10) * scale;
    final bestLabelFontSize = (isDense ? 7 : 8) * scale;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E2DB)
      ..strokeWidth = 1;

    for (final pct in const [0.25, 0.5, 0.75]) {
      final y = innerBottom - (pct * innerHeight);
      _drawDashedLine(
        canvas,
        Offset(chartLeft - (10 * scale), y),
        Offset(chartRight + (10 * scale), y),
        gridPaint,
      );
    }

    final minScore = setScores.reduce(math.min);
    final maxScore = setScores.reduce(math.max);
    final range = math.max(maxScore - minScore, 1);
    final bestIndex = setScores.indexOf(maxScore);
    final stepX =
        setScores.length <= 1 ? 0.0 : chartWidth / (setScores.length - 1);

    final points = <Offset>[];
    for (int i = 0; i < setScores.length; i++) {
      final x =
          setScores.length == 1 ? size.width / 2 : chartLeft + (stepX * i);
      final normalized = (setScores[i] - minScore) / range;
      final y = innerBottom - (normalized * innerHeight);
      points.add(Offset(x, y));
    }

    final strokePath = _buildSmoothPath(points);
    final fillPath = Path.from(strokePath)
      ..lineTo(points.last.dx, chartBottom)
      ..lineTo(points.first.dx, chartBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2E856E)
              .withValues(alpha: 0.18 * progress.clamp(0.0, 1.0)),
          const Color(0xFF2E856E)
              .withValues(alpha: 0.06 * progress.clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(0, chartTop, size.width, chartBottom));
    canvas.drawPath(fillPath, fillPaint);

    final animatedStroke = _extractPath(strokePath, progress);
    final strokePaint = Paint()
      ..color = const Color(0xFF2E856E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(animatedStroke, strokePaint);

    final pointRevealDivisor = math.max(points.length.toDouble(), 1.0);
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final score = setScores[i];
      final pointRevealStart = i / pointRevealDivisor;
      final pointProgress = ((progress - pointRevealStart) * 4).clamp(0.0, 1.0);
      if (pointProgress <= 0) continue;

      final color = _accentSoft(score);
      final isBest = i == bestIndex;

      if (isBest) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.08 * pointProgress);
        canvas.drawCircle(point, bestGlowRadius, glowPaint);
      }

      final outerPaint = Paint()
        ..color = Colors.white.withValues(alpha: pointProgress);
      canvas.drawCircle(
          point, isBest ? bestPointRadius : pointRadius, outerPaint);

      final borderPaint = Paint()
        ..color = color.withValues(alpha: pointProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isBest ? 3 : 2) * scale;
      canvas.drawCircle(
        point,
        isBest ? bestPointRadius : pointRadius,
        borderPaint,
      );

      _paintLabel(
        canvas,
        bounds: size,
        text: '$score%',
        offset: Offset(point.dx, point.dy - scoreLabelGap),
        style: GoogleFonts.dmSans(
          fontSize: isBest ? bestScoreFontSize : scoreFontSize,
          fontWeight: isBest ? FontWeight.w900 : FontWeight.w700,
          color: color.withValues(alpha: pointProgress),
        ),
      );
      _paintLabel(
        canvas,
        bounds: size,
        text: 'Set ${i + 1}',
        offset: Offset(point.dx, point.dy + setLabelGap),
        style: GoogleFonts.dmSans(
          fontSize: setLabelFontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFB5B3AC).withValues(alpha: pointProgress),
        ),
      );
      if (isBest) {
        _paintLabel(
          canvas,
          bounds: size,
          text: 'Kỷ lục cá nhân',
          offset: Offset(point.dx, point.dy + bestLabelGap),
          style: GoogleFonts.dmSans(
            fontSize: bestLabelFontSize,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: pointProgress),
          ),
        );
      }
    }
  }

  Path _buildSmoothPath(List<Offset> points) {
    if (points.length == 1) {
      return Path()
        ..moveTo(points.first.dx, points.first.dy)
        ..lineTo(points.first.dx, points.first.dy);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = previous.dx + ((current.dx - previous.dx) * 0.5);
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  Path _extractPath(Path source, double drawProgress) {
    final metrics = source.computeMetrics().toList();
    if (metrics.isEmpty) return source;

    final targetLength = metrics.fold<double>(
          0,
          (sum, metric) => sum + metric.length,
        ) *
        drawProgress.clamp(0.0, 1.0);

    final path = Path();
    var currentLength = 0.0;
    for (final metric in metrics) {
      final nextLength = currentLength + metric.length;
      if (targetLength >= nextLength) {
        path.addPath(metric.extractPath(0, metric.length), Offset.zero);
      } else {
        final remaining =
            (targetLength - currentLength).clamp(0.0, metric.length);
        path.addPath(metric.extractPath(0, remaining), Offset.zero);
        break;
      }
      currentLength = nextLength;
    }
    return path;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dash = 4.0;
    const gap = 6.0;
    final totalWidth = end.dx - start.dx;
    var x = start.dx;
    while (x < end.dx) {
      final next = math.min(x + (dash * scale), start.dx + totalWidth);
      canvas.drawLine(Offset(x, start.dy), Offset(next, end.dy), paint);
      x = next + (gap * scale);
    }
  }

  void _paintLabel(
    Canvas canvas, {
    required Size bounds,
    required String text,
    required Offset offset,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(
        (offset.dx - (painter.width / 2)).clamp(
          4 * scale,
          bounds.width - painter.width - (4 * scale),
        ),
        (offset.dy - (painter.height / 2)).clamp(
          4 * scale,
          bounds.height - painter.height - (4 * scale),
        ),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FormTerrainPainter oldDelegate) {
    return oldDelegate.setScores != setScores ||
        oldDelegate.progress != progress ||
        oldDelegate.scale != scale;
  }
}

class _CoachSection extends StatelessWidget {
  const _CoachSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      padding: EdgeInsets.only(left: 16 * s),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0x402E856E), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20 * s,
                height: 20 * s,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF18594A),
                  borderRadius: BorderRadius.circular(6 * s),
                ),
                child: Text(
                  'AI',
                  style: VFTheme.textStyle(
                    context,
                    size: 8,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(width: 6 * s),
              Text(
                'HLV AI',
                style: VFTheme.textStyle(
                  context,
                  size: 10,
                  weight: FontWeight.w700,
                  color: const Color(0xFF2E856E),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            text,
            style: GoogleFonts.oswald(
              fontSize: VFTheme.sp(context, 14),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3D3D35),
              height: 1.75,
            ),
          ),
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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 18 * s, 16 * s),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC4841D).withValues(alpha: 0.04),
            const Color(0xFFC4841D).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(
          color: const Color(0xFFC4841D).withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _issueObservation(widget.issue),
            style: VFTheme.textStyle(
              context,
              size: 12,
              weight: FontWeight.w700,
              color: const Color(0xFFC4841D),
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            widget.issue.question,
            style: VFTheme.textStyle(
              context,
              size: 14,
              weight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),
          SizedBox(height: 14 * s),
          Row(
            children: [
              Expanded(
                child: _IssueAnswerButton(
                  label: 'Có',
                  selected: _answer == 'yes',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFD4553A), Color(0xFFB83A2A)],
                  ),
                  onTap: () => setState(() => _answer = 'yes'),
                ),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: _IssueAnswerButton(
                  label: 'Không',
                  selected: _answer == 'no',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF18594A), Color(0xFF2E856E)],
                  ),
                  onTap: () => setState(() => _answer = 'no'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IssueAnswerButton extends StatelessWidget {
  const _IssueAnswerButton({
    required this.label,
    required this.selected,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14 * s),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(vertical: 12 * s),
            decoration: BoxDecoration(
              gradient: selected ? gradient : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(14 * s),
              border: selected
                  ? null
                  : Border.all(
                      color: const Color(0xFFE5E2DB),
                      width: 1.5,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.1 : 0.03),
                  blurRadius: selected ? 14 * s : 3 * s,
                  offset: Offset(0, selected ? 4 * s : 1 * s),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: VFTheme.textStyle(
                context,
                size: 14,
                weight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneSection extends StatelessWidget {
  const _DoneSection({
    required this.shimmer,
    required this.onDone,
    required this.label,
    this.disabled = false,
  });

  final Animation<double> shimmer;
  final VoidCallback onDone;
  final String label;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final borderRadius = BorderRadius.circular(16 * s);

    Widget buildButton(double shimmerValue) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF18594A), Color(0xFF2E856E)],
          ),
          borderRadius: borderRadius,
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: const Color(0xFF18594A).withValues(alpha: 0.25),
                    blurRadius: 24 * s,
                    offset: Offset(0, 6 * s),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: disabled ? null : onDone,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  if (!disabled)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1.6 + (shimmerValue * 3.2),
                              -1.0,
                            ),
                            end: Alignment(
                              -0.6 + (shimmerValue * 3.2),
                              1.0,
                            ),
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16 * s),
                    child: Center(
                      child: Text(
                        label,
                        style: VFTheme.textStyle(
                          context,
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    /* final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18594A), Color(0xFF2E856E)],
        ),
        borderRadius: borderRadius,
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF18594A).withValues(alpha: 0.25),
                  blurRadius: 24 * s,
                  offset: Offset(0, 6 * s),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: disabled ? null : onDone,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                if (!disabled)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(
                            -1.6 + (shimmer.value * 3.2),
                            -1.0,
                          ),
                          end: Alignment(
                            -0.6 + (shimmer.value * 3.2),
                            1.0,
                          ),
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16 * s),
                  child: Center(
                    child: Text(
                      'Hoàn tất',
                      style: VFTheme.textStyle(
                        context,
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ); */
    final button = buildButton(0);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: disabled ? 0.4 : 1,
            child: disabled
                ? button
                : AnimatedBuilder(
                    animation: shimmer,
                    builder: (context, _) {
                      return buildButton(shimmer
                          .value); /*
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF18594A), Color(0xFF2E856E)],
                  ),
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18594A).withValues(alpha: 0.25),
                      blurRadius: 24 * s,
                      offset: Offset(0, 6 * s),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: borderRadius,
                    onTap: onDone,
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -1.6 + (shimmer.value * 3.2),
                                    -1.0,
                                  ),
                                  end: Alignment(
                                    -0.6 + (shimmer.value * 3.2),
                                    1.0,
                                  ),
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0.35, 0.5, 0.65],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16 * s),
                            child: Center(
                              child: Text(
                                'Hoàn tất',
                                style: VFTheme.textStyle(
                                  context,
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ); */
                    },
                  ),
          ),
        ),
        SizedBox(height: 10 * s),
        Text(
          disabled
              ? 'Đánh giá buổi tập để tiếp tục'
              : 'Hẹn gặp lại buổi sau! 👋',
          style: VFTheme.textStyle(
            context,
            size: 11,
            weight: FontWeight.w600,
            color: const Color(0xFFB5B3AC),
          ),
        ),
        if (DateTime.now().millisecondsSinceEpoch < 0)
          Text(
            disabled
                ? 'Đánh giá buổi tập để tiếp tục'
                : 'Hẹn gặp lại buổi sau! 👋',
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w600,
              color: const Color(0xFFB5B3AC),
            ),
          ),
        if (DateTime.now().millisecondsSinceEpoch < 0)
          Text(
            'Hẹn gặp lại buổi sau! 👋',
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w600,
              color: const Color(0xFFB5B3AC),
            ),
          ),
      ],
    );
  }
}

class _OverallDifficultySection extends StatelessWidget {
  const _OverallDifficultySection({
    required this.lastDifficulty,
    required this.selected,
    required this.onTap,
  });

  final String? lastDifficulty;
  final String? selected;
  final ValueChanged<String> onTap;

  String _prompt(String? lastDifficulty) {
    switch (lastDifficulty) {
      case 'light':
        return 'Lần trước bạn thấy nhẹ. Hôm nay thì sao?';
      case 'medium':
        return 'Lần trước bạn thấy vừa sức. Hôm nay thì sao?';
      case 'heavy':
        return 'Lần trước bạn thấy nặng. Hôm nay thì sao?';
      default:
        return 'Buổi này thế nào?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    const options = [
      (id: 'light', label: 'Nhẹ', emoji: '😌'),
      (id: 'medium', label: 'Vừa', emoji: '💪'),
      (id: 'heavy', label: 'Nặng', emoji: '🥵'),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 18 * s, 18 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFE5E2DB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CẢM GIÁC BUỔI TẬP',
            style: VFTheme.textStyle(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: const Color(0xFFB5B3AC),
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            _prompt(lastDifficulty),
            style: VFTheme.textStyle(
              context,
              size: 16,
              weight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
              height: 1.35,
            ),
          ),
          SizedBox(height: 14 * s),
          Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) SizedBox(width: 8 * s),
                Expanded(
                  child: _DifficultyOption(
                    emoji: options[i].emoji,
                    label: options[i].label,
                    selected: selected == options[i].id,
                    locked: selected != null && selected != options[i].id,
                    onTap: () => onTap(options[i].id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      opacity: locked ? 0.3 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.04 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16 * s),
            onTap: (locked || selected) ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(vertical: 14 * s),
              decoration: BoxDecoration(
                color: selected ? null : const Color(0xFFF8F6F1),
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF18594A), Color(0xFF2E856E)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16 * s),
                border: Border.all(
                  color:
                      selected ? Colors.transparent : const Color(0xFFE5E2DB),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF18594A).withValues(alpha: 0.18),
                          blurRadius: 16 * s,
                          offset: Offset(0, 5 * s),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4 * s,
                          offset: Offset(0, 1.5 * s),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: TextStyle(fontSize: 22 * s),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    label,
                    style: VFTheme.textStyle(
                      context,
                      size: 12,
                      weight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF5A5A52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSkeletonPainter extends CustomPainter {
  // NOTE: wire up to captured best-rep landmark data.
  static const List<List<double>> _boneSegments = [
    [255, 95, 255, 140],
    [255, 140, 235, 155],
    [235, 155, 220, 175],
    [255, 140, 270, 160],
    [270, 160, 260, 185],
    [255, 140, 255, 200],
    [255, 200, 230, 260],
    [230, 260, 215, 320],
    [255, 200, 275, 260],
    [275, 260, 265, 320],
    [265, 320, 255, 330],
    [215, 320, 205, 330],
  ];

  // NOTE: wire up to captured best-rep landmark data.
  static const List<List<double>> _joints = [
    [255, 95, 8],
    [255, 140, 5],
    [235, 155, 4],
    [220, 175, 4],
    [270, 160, 4],
    [260, 185, 4],
    [255, 200, 5],
    [230, 260, 4],
    [215, 320, 4],
    [275, 260, 4],
    [265, 320, 4],
    [255, 330, 3],
    [205, 330, 3],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final xScale = size.width / 375;
    final yScale = size.height / 420;
    final stroke = 2.5 * math.min(xScale, yScale);
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF34D399), Color(0xFF18594A)],
    ).createShader(Offset.zero & size);

    for (final segment in _boneSegments) {
      final start = Offset(segment[0] * xScale, segment[1] * yScale);
      final end = Offset(segment[2] * xScale, segment[3] * yScale);

      final glowPaint = Paint()
        ..color = const Color(0xFF34D399).withValues(alpha: 0.22)
        ..strokeWidth = stroke * 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(start, end, glowPaint);

      final bonePaint = Paint()
        ..shader = gradient
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, bonePaint);
    }

    for (final joint in _joints) {
      final center = Offset(joint[0] * xScale, joint[1] * yScale);
      final radius = joint[2] * math.min(xScale, yScale);

      final glowPaint = Paint()
        ..color = const Color(0xFF34D399).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(
        center,
        radius + (1.5 * math.min(xScale, yScale)),
        glowPaint,
      );

      final jointPaint = Paint()
        ..color = const Color(0xFF34D399).withValues(alpha: 0.6);
      canvas.drawCircle(center, radius, jointPaint);
    }

    final arcRect = Rect.fromCircle(
      center: Offset(245 * xScale, 290 * yScale),
      radius: 25 * math.min(xScale, yScale),
    );
    final arcPaint = Paint()
      ..color = const Color(0xFF34D399).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * math.min(xScale, yScale);
    canvas.drawArc(arcRect, 0.0, math.pi / 2.5, false, arcPaint);

    final anglePainter = TextPainter(
      text: TextSpan(
        text: '94°',
        style: GoogleFonts.dmSans(
          fontSize: 11 * math.min(xScale, yScale),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF34D399).withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    anglePainter.paint(
      canvas,
      Offset((248 * xScale) - (anglePainter.width / 2), 295 * yScale),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _accent(int score) => score >= 80
    ? const Color(0xFF4ADE80)
    : score > 55
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF87171);

Color _accentSoft(int score) {
  if (score >= 80) return const Color(0xFF2E856E);
  if (score > 55) return const Color(0xFFC4841D);
  return const Color(0xFFD4553A);
}

String _scoreHeadline(int score) {
  if (score >= 80) return 'Xuất sắc!';
  if (score >= 50) return 'Tốt lắm!';
  return 'Cần cải thiện thêm';
}

String _heroSubtitle({
  required int score,
  required SessionComparison? comparison,
  required bool isFirstSession,
}) {
  if (comparison != null) {
    switch (comparison.type) {
      case ComparisonType.personalBestFormScore:
        return 'Kỷ lục form mới của bạn!';
      case ComparisonType.personalBestFault:
        return comparison.isPainLinked
            ? 'Buổi đỉnh nhất ở vùng bạn đang tập trung'
            : 'Bạn vừa đạt mức cao nhất ở chỉ số đang theo dõi';
      case ComparisonType.improvementStreak:
        return comparison.isPainLinked
            ? 'Chuỗi tiến bộ ở vùng bạn đang tập trung.'
            : 'Chuỗi tiến bộ của bạn vẫn đang dài hơn';
      case ComparisonType.aboveAverage:
        return comparison.secondaryLine ??
            'Bạn đang vượt mức trung bình của mình';
      case ComparisonType.deltaPositive:
        return comparison.primaryLine;
      case ComparisonType.formSolid:
        return 'Form hôm nay ổn đó, cứ giữ nhịp này nhé';
      case ComparisonType.consistencyStreak:
        return 'Đều đặn quan trọng hơn hoàn hảo';
      case ComparisonType.sessionComplete:
        return 'Buổi tập xong rồi, hẹn gặp buổi sau nhé';
      case ComparisonType.none:
        break;
    }
  }

  if (isFirstSession) {
    if (score >= 80) return 'Buổi đầu rất chắc, mình thực sự có nền tảng tốt!';
    if (score >= 50) return 'Buổi đầu ổn rồi, mình đã có điểm khởi đầu tốt.';
    return 'Buổi đầu xong rồi, từ đây mình cải thiện theo từng buổi nhé.';
  }

  if (score >= 80) return 'Form hôm nay chắc lắm, cứ giữ nhịp này nhé.';
  if (score >= 50) return 'Form ổn rồi, buổi sau mình cố thêm một chút nhé.';
  return 'Còn điểm cần cải thiện, nhưng mình đã biết hướng để sửa rồi.';
}

String _heroStreakValue(int streakDays) {
  if (streakDays <= 0) return '1 ngày';
  return '$streakDays ngày';
}

String _issueObservation(DetectedEvidence issue) => switch (issue.issueId) {
      'ankle_mobility' => 'AI nhận thấy gót chân nhấc khỏi sàn ở nhiều rep.',
      'ankle_mobility_restriction' =>
        'AI nhận thấy cả cổ chân và thân trên mất ổn định khi xuống sâu.',
      'hip_flexor_overactivity' =>
        'AI nhận thấy thân trên đổ về phía trước khi xuống sâu.',
      'limited_mobility' => 'AI nhận thấy độ sâu chưa đạt ngưỡng chuẩn.',
      _ => 'AI nhận thấy một điểm cần cải thiện.',
    };

String _formatHeroDate(DateTime date) {
  return '${date.day} Thg ${date.month}, ${date.year}';
}

String _formatReportWork(PostExerciseData report) {
  if (report.isSecondBased) {
    final good = report.goodSeconds ?? 0;
    final total = report.totalSeconds ?? 0;
    return '${_formatSeconds(good)}/${_formatSeconds(total)}';
  }

  return '${report.totalGoodReps ?? 0}/${report.totalReps ?? 0} reps';
}

String _formatSeconds(double seconds) {
  final rounded = seconds.round();
  if (rounded < 60) return '${rounded}s';

  final minutes = rounded ~/ 60;
  final remainder = rounded % 60;
  if (remainder == 0) return '${minutes}m';
  return '${minutes}m ${remainder}s';
}

String _formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
