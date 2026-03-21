import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../onboarding_data.dart';
import '../vf_theme.dart';
import 'package:vinafit_mobile/utils/exercise_logger.dart';

class FactsPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  const FactsPage({super.key, required this.data, required this.onNext});

  @override
  State<FactsPage> createState() => _FactsPageState();
}

class _FactsPageState extends State<FactsPage> {
  int _tab = 0;

  // ── Extract per-rep data from logger ──

  List<bool> _repResults(ExerciseLogger logger) {
    return logger.repLogs.map((r) => r.correctForm == true).toList();
  }

  List<int> _repDepths(ExerciseLogger logger, String depthKey) {
    return logger.repLogs
        .map((r) => (r.data[depthKey] as num?)?.round() ?? 0)
        .toList();
  }

  int _goodCount(ExerciseLogger logger) {
    return (logger.setLogs["good_rep_count"] as int?) ?? 0;
  }

  int _totalCount(ExerciseLogger logger) {
    return logger.repLogs.length;
  }

  @override
  Widget build(BuildContext context) {
    final sqLog = widget.data.squatLogger;
    // final wpLog = widget.data.pushUpLogger;

    final sqGood = _goodCount(sqLog);
    final sqTotal = _totalCount(sqLog);
    // final wpGood = wpLog != null ? (wpLog.setLogs["correct_rep"] as int? ?? 0) : 0;
    // final wpTotal = wpLog != null ? wpLog.repLogs.length : 0;
    final totalGood = sqGood; // + wpGood;
    final totalAll = sqTotal; // + wpTotal;

    final sqReps = _repResults(sqLog);
    // final wpReps = wpLog != null ? _repResults(wpLog) : <bool>[];
    final sqDepths = _repDepths(sqLog, "peak_knee_angle");
    // final wpDepths = wpLog != null ? _repDepths(wpLog, "peak_knee_angle") : <int>[];

    final sqHeelFails = (sqLog.setLogs["heel_fails_count"] as int?) ?? 0;
    final sqMinDepth = sqLog.setLogs["min_knee_angle"];
    final sqAvgDescent = sqLog.setLogs["avg_descending_time"];

    // final wpMinDepth = wpLog != null ? wpLog.setLogs["min_knee_angle"] : null;
    // final wpAvgDescent = wpLog != null ? wpLog.setLogs["avg_descending_time"] : null;

    final exercises = [
      _TabData(
        label: 'Squat',
        sub: 'Hạ thân',
        icon: '🏋️',
        accent: VF.brand,
        good: sqGood,
        total: sqTotal,
        reps: sqReps,
        depths: sqDepths.isNotEmpty ? sqDepths : [0],
        bestDepth:
            sqMinDepth != null ? '${(sqMinDepth as num).round()}°' : '--',
        avgTempo: sqAvgDescent != null
            ? '${(sqAvgDescent as num).toStringAsFixed(1)}s'
            : '--',
        heelRise: sqHeelFails > 0 ? '$sqHeelFails/$sqTotal' : null,
        improved: sqDepths.length >= 2 && sqDepths.first > sqDepths.last,
      ),
      /*
      _TabData(
        label: 'Chống đẩy tường',
        sub: 'Thân trên',
        icon: '🧱',
        accent: VF.green,
        good: 0, // wpGood
        total: 1, // wpTotal
        reps: [], // wpReps
        depths: [0], // wpDepths.isNotEmpty ? wpDepths : [0]
        bestDepth: '--', // wpMinDepth != null ? '${(wpMinDepth as num).round()}°' : '--'
        avgTempo: '--', // wpAvgDescent != null ? '${(wpAvgDescent as num).toStringAsFixed(1)}s' : '--'
        heelRise: null,
        improved: false, // wpDepths.length >= 2 && wpDepths.first > wpDepths.last
      ),
      */
    ];

    final ex = exercises[_tab];
    final maxD = ex.depths.reduce(math.max);
    final minD = ex.depths.reduce(math.min);
    final range = (maxD - minD).clamp(1, 999);

    return Column(
      children: [
        // ── Hero ──
        GradHeader(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(children: [
              Text('KẾT QUẢ KIỂM TRA',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$totalGood',
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1)),
                  Text(' / $totalAll',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
              const SizedBox(height: 6),
              Text('reps đúng form',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Hạ thân ',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5))),
                Text('$sqGood/$sqTotal',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                /*
                Text('  ·  ',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3))),
                Text('Thân trên ',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5))),
                Text('\$wpGood/\$wpTotal',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                */
              ]),
            ]),
          ),
        ),

        // ── Tabs ──
        Row(
          children: List.generate(exercises.length, (i) {
            final e = exercises[i];
            final on = _tab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 10),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: on ? e.accent : Colors.transparent,
                            width: 2.5)),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(e.icon, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(e.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: on ? VF.text : VF.textMuted)),
                    ]),
                    const SizedBox(height: 2),
                    Text('${e.good}/${e.total} reps tốt',
                        style: TextStyle(
                            fontSize: 10,
                            color: on ? e.accent : VF.textMuted,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          }),
        ),

        // ── Content ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(children: [
              // Rep strip
              Row(
                children: List.generate(
                    ex.reps.length,
                    (i) => Expanded(
                          child: Container(
                            height: 6,
                            margin: EdgeInsets.only(
                                right: i < ex.reps.length - 1 ? 6 : 0),
                            decoration: BoxDecoration(
                              color: ex.reps[i]
                                  ? VF.green
                                  : VF.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        )),
              ),
              const SizedBox(height: 18),

              // Chart card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: VF.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VF.border),
                  boxShadow: VF.cardShadow,
                ),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Độ sâu từng rep',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: VF.text)),
                        if (ex.improved &&
                            ex.depths.length >= 2 &&
                            ex.depths.first > ex.depths.last)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: VF.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                                '↓ ${ex.depths.first - ex.depths.last}° sâu hơn',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: VF.green)),
                          ),
                      ]),
                  const SizedBox(height: 14),

                  // Bars
                  SizedBox(
                    height: 100,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(ex.depths.length, (i) {
                        final d = ex.depths[i];
                        final pct = range > 0
                            ? 0.25 + ((maxD - d) / range) * 0.65
                            : 0.5;
                        final good = i < ex.reps.length ? ex.reps[i] : false;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: i > 0 ? 5 : 0,
                                right: i < ex.depths.length - 1 ? 5 : 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('$d°',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            good ? ex.accent : VF.textMuted)),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: pct,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                            bottomLeft: Radius.circular(4),
                                            bottomRight: Radius.circular(4)),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: good
                                              ? [
                                                  ex.accent,
                                                  ex.accent
                                                      .withValues(alpha: 0.5)
                                                ]
                                              : [
                                                  VF.border,
                                                  VF.border
                                                      .withValues(alpha: 0.7)
                                                ],
                                        ),
                                        boxShadow: good
                                            ? [
                                                BoxShadow(
                                                    color: ex.accent.withValues(
                                                        alpha: 0.15),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2))
                                              ]
                                            : null,
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

                  // Rep labels
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: VF.border.withValues(alpha: 0.3)))),
                    child: Row(
                      children: List.generate(
                          ex.depths.length,
                          (i) => Expanded(
                                child: Text('Rep ${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: VF.textMuted,
                                        fontWeight: FontWeight.w500)),
                              )),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Stats
              Row(children: [
                _Stat(icon: '🎯', value: ex.bestDepth, label: 'Tốt nhất'),
                const SizedBox(width: 8),
                _Stat(icon: '⏱', value: ex.avgTempo, label: 'Nhịp TB'),
                if (ex.heelRise != null) ...[
                  const SizedBox(width: 8),
                  _Stat(
                      icon: '👟',
                      value: ex.heelRise!,
                      label: 'Gót nhấc',
                      warn: true),
                ],
              ]),

              const Spacer(),
              const Center(
                  child: Text('Đây là điểm xuất phát. Kiểm tra lại sau 2 tuần!',
                      style: TextStyle(fontSize: 11, color: VF.textMuted))),
            ]),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: VFButton(label: 'Tiếp tục', onTap: widget.onNext),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon, value, label;
  final bool warn;
  const _Stat(
      {required this.icon,
      required this.value,
      required this.label,
      this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: warn ? VF.amber.withValues(alpha: 0.2) : VF.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)
        ],
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: warn ? VF.amber : VF.text)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: VF.textMuted, fontWeight: FontWeight.w500)),
      ]),
    ));
  }
}

class _TabData {
  final String label, sub, icon, bestDepth, avgTempo;
  final String? heelRise;
  final Color accent;
  final int good, total;
  final List<bool> reps;
  final List<int> depths;
  final bool improved;
  const _TabData(
      {required this.label,
      required this.sub,
      required this.icon,
      required this.accent,
      required this.good,
      required this.total,
      required this.reps,
      required this.depths,
      required this.bestDepth,
      required this.avgTempo,
      required this.improved,
      this.heelRise});
}
