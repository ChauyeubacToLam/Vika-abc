import 'package:flutter/material.dart';

import 'package:vika/models/exercise_lookup.dart';
import '../../onboarding_data.dart';
import '../../../../services/recommendation/models/plan.dart';
import '../../../../services/recommendation/recommendation_service.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S15Journey extends StatefulWidget {
  const S15Journey({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
    this.loadPlan,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Future<PlanSnapshot?> Function()? loadPlan;

  @override
  State<S15Journey> createState() => _S15JourneyState();
}

class _S15JourneyState extends State<S15Journey> {
  late Future<PlanSnapshot?> _planFuture;

  @override
  void initState() {
    super.initState();
    _planFuture = _loadPlan();
  }

  Future<PlanSnapshot?> _loadPlan() {
    final loader = widget.loadPlan;
    if (loader == null) return Future<PlanSnapshot?>.value(null);
    return loader();
  }

  void _retry() {
    setState(() => _planFuture = _loadPlan());
  }

  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(widget.data);
    return V5Screen(
      index: 15,
      onBack: widget.onBack,
      children: [
        FutureBuilder<PlanSnapshot?>(
          future: _planFuture,
          builder: (context, snapshot) {
            final plan = snapshot.data?.plan;
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final weeks =
                plan == null ? _loadingWeeks(p) : _weeksFromPlan(plan);
            final hasPlan = plan != null;

            return Stack(
              children: [
                Positioned(
                  top: 144,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const V5Eyebrow(label: 'Hành trình'),
                      const SizedBox(height: 10),
                      Text(
                        loading
                            ? 'Đang tạo lộ trình của bạn'
                            : hasPlan
                                ? '${weeks.length} tuần phía trước'
                                : 'Chưa tải được lộ trình',
                        style: V5.text(
                          context,
                          size: 24,
                          weight: FontWeight.w800,
                          color: V5.ink,
                          letterSpacing: -.8,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loading
                            ? 'Vika đang lưu hồ sơ và tạo kế hoạch thật từ thuật toán mới.'
                            : hasPlan
                                ? 'Đây là lộ trình thật đã được lưu cho tài khoản của bạn.'
                                : 'Mạng có thể chưa ổn. Bạn có thể thử lại trước khi bắt đầu.',
                        style: V5.text(
                          context,
                          size: 12,
                          weight: FontWeight.w500,
                          color: V5.inkSoft,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 262,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: weeks.asMap().entries.map((entry) {
                      final i = entry.key;
                      final first = i == 0;
                      return Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(
                            right: i == weeks.length - 1 ? 0 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: first
                                ? V5.yellow
                                : V5.yellow.withValues(
                                    alpha: 0.18 + (i + 1) / weeks.length * 0.15,
                                  ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: first
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: Transform.translate(
                                    offset: const Offset(5, 0),
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: V5.yellow,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: V5.bg,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: V5.yellow.withValues(
                                              alpha: .6,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Positioned(
                  top: 286,
                  left: 0,
                  right: 0,
                  bottom: 108,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: .75),
                    padEnds: false,
                    itemCount: weeks.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          index == 0 ? 16 : 6,
                          8,
                          6,
                          8,
                        ),
                        child: V5FadeIn(
                          delay: Duration(milliseconds: index * 70),
                          slideY: 8,
                          child: _WeekCard(
                            week: weeks[index],
                            level: p.level,
                            first: index == 0,
                            loading: loading,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!loading && !hasPlan)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 108,
                    child: _RetryPanel(onRetry: _retry),
                  ),
              ],
            );
          },
        ),
        V5PillCTA(
          label: 'Sẵn sàng bắt đầu',
          enabled: true,
          onTap: widget.onNext,
        ),
      ],
    );
  }

  List<_Week> _weeksFromPlan(Plan plan) {
    return plan.weeks.map((week) {
      final firstSession = week.sessions.isEmpty ? null : week.sessions.first;
      final slots = firstSession?.slots ?? const <SlotAssignment>[];
      final exercises = slots.take(4).map((slot) {
        return '${_exerciseLabel(slot.exerciseId)} · ${_formatVolume(slot.volume)}';
      }).toList();
      return _Week(
        number: week.weekNumber,
        theme: week.phaseName,
        headline: week.isDeloadWeek
            ? 'Giảm tải để cơ thể hồi phục'
            : week.weekNumber == 1
                ? 'Bắt đầu chắc và đúng form'
                : 'Tăng dần mục tiêu trong tuần này',
        feeling: week.isDeloadWeek
            ? 'Tuần này nhẹ hơn có chủ đích. Cơ thể được hồi lại trước khi kiểm tra tiến độ.'
            : 'Bài tập giữ ổn định, chỉ tăng lượng vừa đủ để bạn thấy tiến bộ mà không bị quá sức.',
        sessionCount: week.sessions.length,
        exercises:
            exercises.isEmpty ? ['Vika đang chuẩn bị bài tập'] : exercises,
        tag: week.isDeloadWeek ? 'Phục hồi' : 'Tuần ${week.weekNumber}',
      );
    }).toList();
  }

  List<_Week> _loadingWeeks(PlanPersonalization p) {
    return [
      for (var week = 1; week <= 7; week++)
        _Week(
          number: week,
          theme: week == 7
              ? 'Phục hồi'
              : week <= 3
                  ? 'Nền tảng'
                  : 'Phát triển',
          headline: 'Đang ghép bài tập phù hợp',
          feeling: 'Vika đang đọc hồ sơ, vùng đau và lịch tập của bạn.',
          sessionCount: p.freq,
          exercises: const [
            'Đang tạo bài tập',
            'Đang đặt mục tiêu',
            'Đang lưu kế hoạch'
          ],
          tag: week == 7 ? 'Giảm tải' : 'Đang tạo',
        ),
    ];
  }
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [V5.cardShadow(0.08)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Lộ trình chưa được lưu. Thử lại để Vika tạo kế hoạch thật.',
              style: V5.text(
                context,
                size: 12,
                weight: FontWeight.w600,
                color: V5.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Thử lại',
              style: V5.text(
                context,
                size: 12,
                weight: FontWeight.w800,
                color: V5.yellowDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Week {
  const _Week({
    required this.number,
    required this.theme,
    required this.headline,
    required this.feeling,
    required this.sessionCount,
    required this.exercises,
    required this.tag,
  });

  final int number;
  final String theme;
  final String headline;
  final String feeling;
  final int sessionCount;
  final List<String> exercises;
  final String tag;
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.level,
    required this.first,
    required this.loading,
  });

  final _Week week;
  final String level;
  final bool first;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final minutes = level == 'advanced'
        ? 50
        : level == 'intermediate'
            ? 35
            : 25;
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: first ? V5.heroGradient : null,
        color: first ? null : V5.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: first ? V5.heroBorder : V5.border),
        boxShadow: [V5.cardShadow(0.08)],
      ),
      child: Stack(
        children: [
          if (first)
            Positioned(
              top: -80,
              right: -70,
              width: 220,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: V5.yellow.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: first ? V5.yellow : V5.yellowSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TUẦN',
                          style: V5.text(
                            context,
                            size: 7,
                            weight: FontWeight.w700,
                            color: first ? V5.yellowInk : V5.yellowDeep,
                            letterSpacing: .4,
                            height: 1,
                          ),
                        ),
                        Text(
                          '${week.number}',
                          style: V5.text(
                            context,
                            size: 13,
                            weight: FontWeight.w800,
                            color: first ? V5.yellowInk : V5.yellowDeep,
                            letterSpacing: -.3,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      week.theme,
                      style: V5.text(
                        context,
                        size: 14,
                        weight: FontWeight.w800,
                        color: first ? V5.invInk : V5.ink,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  if (first)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: V5.yellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        loading ? 'ĐANG TẠO' : 'BẮT ĐẦU ĐÂY',
                        style: V5.text(
                          context,
                          size: 8,
                          weight: FontWeight.w800,
                          color: V5.yellowInk,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                week.headline,
                style: V5.text(
                  context,
                  size: 14,
                  weight: FontWeight.w800,
                  color: first ? V5.invInk : V5.ink,
                  letterSpacing: -.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                week.feeling,
                style: V5.text(
                  context,
                  size: 11,
                  weight: FontWeight.w500,
                  color: first ? V5.invInkSoft : V5.inkSoft,
                  height: 1.5,
                ),
              ),
              Divider(
                height: 28,
                color: first ? Colors.white.withValues(alpha: .08) : V5.border,
              ),
              Row(
                children: [
                  Text(
                    'BÀI TẬP TUẦN NÀY',
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w700,
                      color: first ? V5.invInkSoft : V5.inkSoft,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    week.tag,
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w700,
                      color: first ? V5.yellow : V5.yellowDeep,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...week.exercises.map(
                (ex) => Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color:
                        first ? Colors.white.withValues(alpha: .05) : V5.bgSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: first
                        ? Border.all(color: Colors.white.withValues(alpha: .08))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: V5.yellow.withValues(alpha: .18),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: V5.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ex,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: V5.text(
                            context,
                            size: 12,
                            weight: FontWeight.w700,
                            color: first ? V5.invInk : V5.ink,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Divider(
                color: first ? Colors.white.withValues(alpha: .08) : V5.border,
              ),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: first ? V5.yellow : V5.yellowDeep),
                  const SizedBox(width: 5),
                  Text(
                    '${week.sessionCount} buổi',
                    style: V5.text(
                      context,
                      size: 10,
                      weight: FontWeight.w700,
                      color: first ? V5.invInk : V5.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '~${(week.sessionCount * minutes / 60).toStringAsFixed(1)}h',
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w600,
                      color: first ? V5.invInkSoft : V5.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatVolume(VolumePrescription volume) {
  final target = volume.reps != null
      ? '${volume.reps} rep'
      : volume.seconds != null
          ? '${volume.seconds}s'
          : '';
  return '${volume.sets} hiệp${target.isEmpty ? '' : ' x $target'}';
}

String _exerciseLabel(String id) {
  final definition = lookupExerciseDefinition(id);
  if (definition != null) return definition.name;
  return switch (id) {
    'squat_bw' => 'Squat',
    'wall_pushup' || 'wall_pushup_assessment' => 'Wall Push-Up',
    'glute_bridge_bw' => 'Glute Bridge',
    'warrior_i' => 'Warrior I',
    'standing_forward_fold' => 'Standing Forward Fold',
    'cobra' => 'Cobra',
    _ => id
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' '),
  };
}
