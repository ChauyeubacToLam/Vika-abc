import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../exercise/squat/squat.dart';
import '../../utils/exercise_logger.dart';
import '../onboarding/vf_theme.dart';
import 'widgets/depth_chart.dart';
import 'widgets/form_score_arc.dart';

class SetSummaryPage extends StatefulWidget {
  const SetSummaryPage({
    super.key,
    required this.logger,
    required this.setIndex,
    required this.isLastSet,
    required this.restDuration,
    required this.onNext,
  });

  final ExerciseLogger logger;
  final int setIndex;
  final bool isLastSet;
  final int restDuration;
  final VoidCallback onNext;

  @override
  State<SetSummaryPage> createState() => _SetSummaryPageState();
}

class _SetSummaryPageState extends State<SetSummaryPage> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.isLastSet ? 0 : widget.restDuration;
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant SetSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restDuration != widget.restDuration ||
        oldWidget.isLastSet != widget.isLastSet) {
      _remaining = widget.isLastSet ? 0 : widget.restDuration;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.isLastSet || _remaining <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
      }
      if (mounted) {
        setState(() {
          _remaining = math.max(0, _remaining - 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _SetSummaryData.fromLogger(widget.logger);
    final media = MediaQuery.of(context);

    return Container(
      color: VF.bg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 26),
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
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SET ${widget.setIndex + 1} HOÀN THÀNH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: VF.jadeGlow.withValues(alpha: 0.42),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${summary.goodReps}',
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 10),
                        child: Text(
                          '/ ${summary.totalReps} reps đúng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: summary.reps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final rep = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: index == summary.reps.length - 1 ? 0 : 5),
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: rep.correctForm
                                  ? VF.jadeGlow
                                  : Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: summary.consistent
                          ? VF.jadeGlow.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: summary.consistent
                            ? VF.jadeGlow.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      summary.consistent
                          ? 'Ổn định · CV ${summary.cv.toStringAsFixed(1)}%'
                          : 'Chưa đều · CV ${summary.cv.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: summary.consistent
                            ? VF.jadeGlow.withValues(alpha: 0.84)
                            : Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  children: [
                    DepthChart(
                      data: summary.depths.asMap().entries.map((entry) {
                        final rep = summary.reps[entry.key];
                        return DepthBarDatum(
                          label: 'R${entry.key + 1}',
                          value: entry.value,
                          good: rep.correctForm,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricMiniCard(
                            label: 'Depth TB',
                            value: '${summary.avgDepth.round()}°',
                            subText: 'Best: ${summary.bestDepth.round()}°',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricMiniCard(
                            label: 'Nhịp TB',
                            value: '${summary.avgTempo.toStringAsFixed(1)}s',
                            subText: 'Xuống + lên',
                          ),
                        ),
                        if (summary.heelFails > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricMiniCard(
                              label: 'Gót nhấc',
                              value: '${summary.heelFails}×',
                              warning: true,
                            ),
                          ),
                        ] else if (summary.shallowReps > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricMiniCard(
                              label: 'Rep nông',
                              value: '${summary.shallowReps}×',
                              subText:
                                  '> ${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]}°',
                              warning: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: VF.amber.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: VF.amber.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: VF.amber.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tips_and_updates_outlined,
                              size: 14,
                              color: VF.amber,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Set tiếp theo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: VF.amber,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  summary.tip,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: VF.textSec,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.fromLTRB(24, 20, 24, media.padding.bottom + 20),
              child: _remaining > 0 && !widget.isLastSet
                  ? Column(
                      children: [
                        FormScoreArc(
                          progress: 1 - (_remaining / widget.restDuration),
                          size: 92,
                          color: VF.accent,
                          trackColor: VF.accent.withValues(alpha: 0.15),
                          strokeWidth: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_remaining',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: VF.text,
                                  height: 1,
                                ),
                              ),
                              const Text(
                                'giây',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: VF.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Nghỉ giữa set',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: VF.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: widget.onNext,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: VF.accent.withValues(alpha: 0.20),
                                width: 1.5,
                              ),
                            ),
                            child: const Text(
                              'Bỏ qua',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: VF.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : VFButton(
                      label: widget.isLastSet
                          ? 'Xem tổng kết'
                          : 'Bắt đầu set tiếp',
                      onTap: widget.onNext,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricMiniCard extends StatelessWidget {
  const _MetricMiniCard({
    required this.label,
    required this.value,
    this.subText,
    this.warning = false,
  });

  final String label;
  final String value;
  final String? subText;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? VF.coral : VF.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: warning ? VF.coral.withValues(alpha: 0.08) : VF.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warning ? VF.coral.withValues(alpha: 0.12) : VF.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: warning ? VF.coral.withValues(alpha: 0.9) : VF.textMuted,
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 2),
            Text(
              subText!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color:
                    warning ? VF.coral.withValues(alpha: 0.68) : VF.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetSummaryData {
  _SetSummaryData({
    required this.reps,
    required this.goodReps,
    required this.totalReps,
    required this.depths,
    required this.avgDepth,
    required this.bestDepth,
    required this.avgTempo,
    required this.heelFails,
    required this.shallowReps,
    required this.cv,
    required this.consistent,
    required this.tip,
  });

  final List<RepLog> reps;
  final int goodReps;
  final int totalReps;
  final List<double> depths;
  final double avgDepth;
  final double bestDepth;
  final double avgTempo;
  final int heelFails;
  final int shallowReps;
  final double cv;
  final bool consistent;
  final String tip;

  factory _SetSummaryData.fromLogger(ExerciseLogger logger) {
    final reps = logger.repLogs;
    final goodReps = (logger.setLogs['good_rep_count'] as num?)?.toInt() ??
        reps.where((rep) => rep.correctForm).length;
    final depths = reps
        .map((rep) => (rep.data['peak_knee_angle'] as num?)?.toDouble() ?? 0)
        .where((depth) => depth > 0)
        .toList();
    final double avgDepth =
        depths.isEmpty ? 0 : depths.reduce((a, b) => a + b) / depths.length;
    final double bestDepth =
        depths.isEmpty ? 0 : depths.reduce((a, b) => a < b ? a : b);
    final tempos = reps
        .map((rep) => _tempoForRep(rep))
        .where((tempo) => tempo > 0)
        .toList();
    final double avgTempo =
        tempos.isEmpty ? 0 : tempos.reduce((a, b) => a + b) / tempos.length;
    final heelFails = (logger.setLogs['heel_fails'] as num?)?.toInt() ??
        (logger.setLogs['heel_fails_count'] as num?)?.toInt() ??
        reps.where((rep) {
          final heel =
              (rep.data['peak_heel_distance'] as num?)?.toDouble() ?? 0;
          return heel > 0;
        }).length;
    final shallowReps = reps.where((rep) {
      final depth = (rep.data['peak_knee_angle'] as num?)?.toDouble();
      return depth != null &&
          depth > SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1];
    }).length;
    final cv = _computeCv(depths);
    final consistent = cv < 8;
    final tip = shallowReps >= 3
        ? 'Tập trung hạ sâu hơn ở set tiếp theo. Mục tiêu là đưa gối về dưới 100°.'
        : heelFails > 0
            ? 'Gót chân có lúc nhấc lên. Hãy ấn gót xuống sàn và hạ chậm hơn.'
            : !consistent
                ? 'Độ sâu chưa đều giữa các rep. Giữ cùng một nhịp xuống cho toàn set.'
                : 'Form đang ổn. Giữ nhịp này và tiếp tục kiểm soát phần đi xuống.';

    return _SetSummaryData(
      reps: reps,
      goodReps: goodReps,
      totalReps: reps.length,
      depths: depths,
      avgDepth: avgDepth,
      bestDepth: bestDepth,
      avgTempo: avgTempo,
      heelFails: heelFails,
      shallowReps: shallowReps,
      cv: cv,
      consistent: consistent,
      tip: tip,
    );
  }

  static double _tempoForRep(RepLog rep) {
    final direct = rep.data['tempo'];
    if (direct is num) {
      return direct.toDouble();
    }
    final descending = (rep.data['descending_time'] as num?)?.toDouble() ?? 0;
    final ascending = (rep.data['ascending_time'] as num?)?.toDouble() ?? 0;
    return descending + ascending;
  }

  static double _computeCv(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) {
      return 0;
    }
    final variance = values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return (math.sqrt(variance) / mean) * 100;
  }
}
