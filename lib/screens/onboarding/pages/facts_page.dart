import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vinafit_mobile/utils/exercise_logger.dart';

import '../onboarding_data.dart';
import '../vf_theme.dart';

class FactsPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const FactsPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final log = data.squatLogger;
    final reps = _repResults(log);
    final depths = _repDepths(log);
    final good = _goodCount(log);
    final total = log.repLogs.length;
    final bestDepthValue = log.setLogs['min_knee_angle'];
    final avgTempoValue = log.setLogs['avg_descending_time'];
    final heelFails = (log.setLogs['heel_fails_count'] as int?) ?? 0;
    final bestDepth =
        bestDepthValue == null ? '--' : '${(bestDepthValue as num).round()}°';
    final avgTempo = avgTempoValue == null
        ? '--'
        : '${(avgTempoValue as num).toStringAsFixed(1)}s';

    return Column(
      children: [
        VFProgressBar(current: 3, total: 7, onBack: onBack),
        Expanded(
          child: VFFitViewport(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Baseline from your first check',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: VF.text,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Giữ phần kết quả này sạch và thực dụng: form score, rep strip, và vài chỉ số đủ để dẫn sang level prediction.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: VF.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                VFPanel(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Squat assessment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: VF.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$good',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: VF.text,
                              height: 0.95,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 7),
                            child: Text(
                              '/ $total reps đúng form',
                              style: const TextStyle(
                                fontSize: 16,
                                color: VF.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: List.generate(
                          reps.length,
                          (i) => Expanded(
                            child: Container(
                              height: 6,
                              margin: EdgeInsets.only(
                                right: i < reps.length - 1 ? 6 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: reps[i]
                                    ? VF.green
                                    : VF.red.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _DepthChart(depths: depths, reps: reps),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Độ sâu tốt nhất',
                        value: bestDepth,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Nhịp trung bình',
                        value: avgTempo,
                      ),
                    ),
                    if (heelFails > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Gót nhấc',
                          value: '$heelFails/$total',
                          emphasized: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: VFButton(label: 'Tiếp tục', onTap: onNext),
        ),
      ],
    );
  }

  static List<bool> _repResults(ExerciseLogger logger) {
    return logger.repLogs.map((r) => r.correctForm == true).toList();
  }

  static List<int> _repDepths(ExerciseLogger logger) {
    final values = logger.repLogs
        .map((r) => (r.data['peak_knee_angle'] as num?)?.round() ?? 0)
        .toList();
    return values.isEmpty ? [0] : values;
  }

  static int _goodCount(ExerciseLogger logger) {
    return (logger.setLogs['good_rep_count'] as int?) ?? 0;
  }
}

class _DepthChart extends StatelessWidget {
  final List<int> depths;
  final List<bool> reps;

  const _DepthChart({required this.depths, required this.reps});

  @override
  Widget build(BuildContext context) {
    final maxDepth = depths.reduce(math.max);
    final minDepth = depths.reduce(math.min);
    final range = (maxDepth - minDepth).clamp(1, 999);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: VF.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VF.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Độ sâu từng rep',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: VF.text,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(depths.length, (index) {
                final depth = depths[index];
                final good = index < reps.length ? reps[index] : false;
                final heightFactor =
                    0.28 + ((maxDepth - depth) / range) * 0.58;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index > 0 ? 5 : 0,
                      right: index < depths.length - 1 ? 5 : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$depth°',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: good ? VF.accent : VF.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: good ? VF.accent : VF.bgDeep,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              depths.length,
              (index) => Expanded(
                child: Text(
                  'Rep ${index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    color: VF.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _StatCard({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: emphasized ? VF.amberSoft : VF.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized ? VF.amber.withValues(alpha: 0.18) : VF.border,
        ),
        boxShadow: emphasized ? null : VF.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: emphasized ? VF.amber : VF.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: VF.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
