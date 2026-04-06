import 'package:flutter/material.dart';

import '../../exercise/squat/squat.dart';
import '../../utils/exercise_logger.dart';
import '../onboarding/vf_theme.dart';
import 'widgets/issue_question.dart';
import 'widgets/shareable_card.dart';

class ExecutiveSummaryPage extends StatefulWidget {
  const ExecutiveSummaryPage({
    super.key,
    required this.exerciseName,
    required this.setLoggers,
    required this.totalDuration,
    required this.onDone,
    this.onIssueAnswersChanged,
  });

  final String exerciseName;
  final List<ExerciseLogger> setLoggers;
  final Duration totalDuration;
  final VoidCallback onDone;
  final ValueChanged<Map<String, String>>? onIssueAnswersChanged;

  @override
  State<ExecutiveSummaryPage> createState() => _ExecutiveSummaryPageState();
}

class _ExecutiveSummaryPageState extends State<ExecutiveSummaryPage> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final Map<String, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    final summary = _ExecutiveSummaryData.fromLoggers(
      exerciseName: widget.exerciseName,
      loggers: widget.setLoggers,
      totalDuration: widget.totalDuration,
    );
    final media = MediaQuery.of(context);

    return Container(
      color: VF.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: media.padding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Row(
                  children: [
                    const Text(
                      'HOÀN THÀNH BÀI TẬP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: VF.textMuted,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onDone,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: VF.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VF.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: VF.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: ShareableCard(
                  boundaryKey: _shareBoundaryKey,
                  formScore: summary.formScore,
                  exerciseName: widget.exerciseName,
                  dateText: summary.dateText,
                  metaLine: summary.metaLine,
                  winMessage: summary.winMessage,
                  setScores: summary.setScores,
                ),
              ),
              Container(
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VF.accentSoft.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: VF.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: VF.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'HLV AI của bạn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: VF.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: VF.textSec,
                      height: 1.7,
                    ),
                    children: summary.coachSpans,
                  ),
                ),
              ),
              if (summary.issues.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    children: summary.issues.map((issue) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: issue == summary.issues.last ? 0 : 10,
                        ),
                        child: IssueQuestion(
                          observation: issue.observation,
                          question: issue.question,
                          value: _answers[issue.key],
                          onChanged: (value) {
                            setState(() {
                              _answers[issue.key] = value;
                            });
                            widget.onIssueAnswersChanged?.call(_answers);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                child: const Text(
                  'CHI TIẾT BÀI TẬP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: VF.textMuted,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: summary.metricCards.map((card) {
                    return FractionallySizedBox(
                      widthFactor: 0.5,
                      child: _SummaryMetricCard(card: card),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: VFButton(
                    label: 'Hoàn tất',
                    onTap: widget.onDone,
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

class _IssueData {
  const _IssueData({
    required this.key,
    required this.observation,
    required this.question,
  });

  final String key;
  final String observation;
  final String question;
}

class _MetricCardData {
  const _MetricCardData({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;
}

class _ExecutiveSummaryData {
  _ExecutiveSummaryData({
    required this.formScore,
    required this.setScores,
    required this.winMessage,
    required this.dateText,
    required this.metaLine,
    required this.coachSpans,
    required this.issues,
    required this.metricCards,
  });

  final int formScore;
  final List<int> setScores;
  final String winMessage;
  final String dateText;
  final String metaLine;
  final List<InlineSpan> coachSpans;
  final List<_IssueData> issues;
  final List<_MetricCardData> metricCards;

  factory _ExecutiveSummaryData.fromLoggers({
    required String exerciseName,
    required List<ExerciseLogger> loggers,
    required Duration totalDuration,
  }) {
    final allReps = loggers.expand((logger) => logger.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((rep) => rep.correctForm).length;
    final formScore =
        totalReps == 0 ? 0 : ((totalGood / totalReps) * 100).round();
    final setScores = loggers.map((logger) {
      final reps = logger.repLogs;
      if (reps.isEmpty) {
        return 0;
      }
      final good = (logger.setLogs['good_rep_count'] as num?)?.toInt() ??
          reps.where((rep) => rep.correctForm).length;
      return ((good / reps.length) * 100).round();
    }).toList();

    final improved = setScores.isNotEmpty && setScores.last >= setScores.first;
    final winMessage = improved
        ? 'Form cải thiện rõ rệt từ set đầu đến set cuối'
        : 'Giữ form ổn định xuyên suốt buổi tập';
    final dateText = _formatDate(DateTime.now());
    final metaLine =
        '${loggers.length} sets · $totalReps reps · ${_formatDuration(totalDuration)}';

    final heelFailTotal = loggers.fold<int>(
      0,
      (sum, logger) =>
          sum +
          ((logger.setLogs['heel_fails'] as num?)?.toInt() ??
              (logger.setLogs['heel_fails_count'] as num?)?.toInt() ??
              0),
    );
    final shallowReps = allReps.where((rep) {
      final depth = (rep.data['peak_knee_angle'] as num?)?.toDouble();
      return depth != null &&
          depth > SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1];
    }).length;

    final issues = <_IssueData>[
      if (heelFailTotal > 0)
        const _IssueData(
          key: 'heel',
          observation: 'AI nhận thấy gót chân nâng lên ở set đầu',
          question:
              'Bạn có cảm thấy căng hoặc khó chịu ở mắt cá chân khi ngồi xổm không?',
        ),
      if (shallowReps > 2)
        _IssueData(
          key: 'depth',
          observation: '$shallowReps rep chưa đạt depth mục tiêu',
          question:
              'Bạn có thể ngồi xổm sâu thoải mái mà không mất thăng bằng không?',
        ),
    ];

    final setDepths = loggers.map((logger) {
      final reps = logger.repLogs
          .map((rep) => (rep.data['peak_knee_angle'] as num?)?.toDouble() ?? 0)
          .where((value) => value > 0)
          .toList();
      if (reps.isEmpty) {
        return 0.0;
      }
      return reps.reduce((a, b) => a + b) / reps.length;
    }).toList();
    final allDepths = allReps
        .map((rep) => (rep.data['peak_knee_angle'] as num?)?.toDouble() ?? 0)
        .where((value) => value > 0)
        .toList();
    final bestDepth = allDepths.isEmpty
        ? 0
        : allDepths.reduce((a, b) => a < b ? a : b).round();
    final avgTempo = _avgTempo(allReps);
    final depthTrendText = setDepths.length >= 2
        ? '${setDepths.first.round()}° → ${setDepths.last.round()}°'
        : '${setDepths.firstOrNull?.round() ?? 0}°';

    final coachSpans = <InlineSpan>[
      const TextSpan(text: 'Form của bạn '),
      TextSpan(
        text: improved ? 'cải thiện rõ rệt' : 'đã giữ khá ổn định',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: VF.text,
        ),
      ),
      TextSpan(
        text:
            ' qua ${loggers.length} set. Nhịp tập dần đều hơn và depth ${improved ? 'ổn định hơn' : 'được duy trì khá tốt'}. ',
      ),
      if (heelFailTotal > 0)
        const TextSpan(
          text:
              'Gót chân chỉ còn nhấc nhẹ ở giai đoạn đầu, cho thấy khả năng kiểm soát đã tốt hơn. ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: VF.accent,
          ),
        ),
      const TextSpan(
        text:
            'Buổi tới hãy tiếp tục hạ chậm và giữ đáy lâu hơn một nhịp để khóa form chắc hơn.',
      ),
    ];

    final metricCards = [
      _MetricCardData(
        value: depthTrendText,
        label: 'Depth cải thiện',
        color: VF.accent,
      ),
      _MetricCardData(
        value: '${avgTempo.toStringAsFixed(1)}s TB',
        label: 'Nhịp kiểm soát',
        color: VF.blue,
      ),
      _MetricCardData(
        value: '$totalGood/$totalReps',
        label: 'Reps đúng form',
        color: VF.text,
      ),
      _MetricCardData(
        value: '$bestDepth°',
        label: 'Depth tốt nhất',
        color: VF.text,
      ),
    ];

    return _ExecutiveSummaryData(
      formScore: formScore,
      setScores: setScores,
      winMessage: winMessage,
      dateText: dateText,
      metaLine: metaLine,
      coachSpans: coachSpans,
      issues: issues,
      metricCards: metricCards,
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static double _avgTempo(List<RepLog> reps) {
    final values = reps
        .map((rep) {
          final tempo = rep.data['tempo'];
          if (tempo is num) {
            return tempo.toDouble();
          }
          final down = (rep.data['descending_time'] as num?)?.toDouble() ?? 0;
          final up = (rep.data['ascending_time'] as num?)?.toDouble() ?? 0;
          return down + up;
        })
        .where((value) => value > 0)
        .toList();
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({required this.card});

  final _MetricCardData card;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VF.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: card.color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: card.color == VF.text ? VF.textMuted : card.color,
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
