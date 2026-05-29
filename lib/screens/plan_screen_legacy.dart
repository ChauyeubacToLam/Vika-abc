// LegacyPlanScreen — PRESERVED real-data Plan path (calendar-anchored v2).
//
// This is the prior PlanScreen, kept intact as the canonical reference for
// how the Plan tab loaded real data and launched workouts:
//   • RecommendationService.ensurePlanForCurrentUser(...) → PlanSnapshot
//   • FitnessRetestService.fetchPendingRetestForCurrentUser()
//   • _PlanWeekMapper.fromSnapshot(...) → display models
//   • WorkoutLaunchService.resolveFromSnapshot(...) + Navigator '/exercise'
//   • SessionPersistence.updateStreak() on completion
//
// The live Plan tab now renders the COMPLETION-anchored redesign in
// plan_screen.dart (mock-driven, no dates). When wiring the new screen to
// real data, lift the loading + launch logic from here and write a
// `ProgramPlan` mapper (see program_mock.dart's TODO(wiring) seam) — the new
// design intentionally drops every calendar-derived concept below
// (Monday-of-week anchoring, weekday pinning, date-based "today"/"done").
// This file is not routed; it compiles as a reference only.
//
// ─────────────────────────────────────────────────────────────────────────
//
// Real data wiring (RecommendationService, FitnessRetestService,
// _PlanWeekMapper) preserved verbatim from v1. The rendering layer is
// fully redesigned to match Home's Stage aesthetic:
//
//   ┌─ DARK STAGE HERO (PlanStageHero, bleeds to top edge)
//   │     Adapts to selected week's status (current / done / future)
//   │     CTA on current week is the "Bắt đầu Buổi N" launch
//   │
//   ├─ WEEK RAIL (PlanWeekRail)
//   │     Horizontal scrollable pills, 7 weeks, tap to select
//   │
//   ├─ DAY TIMELINE (PlanDayTimeline)
//   │     Vertical 7-day list for the SELECTED week
//   │     Tap any non-rest day to expand and see its exercise list
//   │     Today is expanded by default; recheck day has diamond marker +
//   │     its own CTA inside the expansion
//   │
//   └─ EditorialCloser
//
// The dark hero defeats MainShell's top SafeArea via
// MediaQuery.removePadding(removeTop: true), then re-applies status-bar
// padding inside itself — same trick as Home.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/plan_mock.dart';
import '../models/exercise_lookup.dart';
import '../screens/exercise/exercise_launch_args.dart';
import '../services/recommendation/fitness_retest_service.dart';
import '../services/recommendation/models/plan.dart' as reco;
import '../services/recommendation/recommendation_service.dart';
import '../services/session_persistence.dart';
import '../services/user_program_service.dart';
import '../services/user_profile_service.dart';
import '../services/workout_launch_service.dart';
import '../theme/app_colors.dart';
import '../utils/orientation_lock.dart';
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/plan_day_timeline.dart';
import '../widgets/plan/plan_stage_hero.dart';
import 'plan_retest_screen.dart';

class LegacyPlanScreen extends StatefulWidget {
  const LegacyPlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final UserProgramData? program;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<LegacyPlanScreen> createState() => _LegacyPlanScreenState();
}

class _LegacyPlanScreenState extends State<LegacyPlanScreen> {
  final _service = RecommendationService();
  final _retests = FitnessRetestService();
  late Future<_PlanScreenData> _planDataFuture;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _planDataFuture = _loadPlanData();
  }

  Future<_PlanScreenData> _loadPlanData() async {
    final snapshot = await _service.ensurePlanForCurrentUser(
      trigger: 'onboarding',
    );
    if (snapshot == null)
      return const _PlanScreenData(snapshot: null, pendingRetest: null);
    final pendingRetest =
        await _retests.fetchPendingRetestForCurrentUser(snapshot);
    return _PlanScreenData(
      snapshot: snapshot,
      pendingRetest: pendingRetest,
    );
  }

  void _reload() {
    setState(() {
      _planDataFuture = _loadPlanData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      color: c.bg,
      child: FutureBuilder<_PlanScreenData>(
        future: _planDataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data?.snapshot;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _PlanShellMessage(
              title: 'Đang tải lộ trình',
              body: 'Vika đang lấy kế hoạch mới nhất từ tài khoản của bạn.',
              bottomPadding: widget.bottomPadding,
            );
          }

          if (data == null || data.plan.weeks.isEmpty) {
            return _PlanShellMessage(
              title: 'Chưa có lộ trình',
              body:
                  'Vika chưa lưu được kế hoạch. Thử lại để tạo lộ trình từ thuật toán mới.',
              actionLabel: 'Thử lại',
              onAction: _reload,
              bottomPadding: widget.bottomPadding,
            );
          }

          return _PlanContent(
            key: ValueKey(
              '${data.plan.recommendationId}:'
              '${snapshot.data?.pendingRetest?.recommendationId ?? 'ready'}',
            ),
            snapshot: data,
            pendingRetest: snapshot.data?.pendingRetest,
            bottomPadding: widget.bottomPadding,
            onReload: _reload,
            onProfileChanged: widget.onProfileChanged,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONTENT — selected-week state + new composition
// ═══════════════════════════════════════════════════════════════

class _PlanContent extends StatefulWidget {
  const _PlanContent({
    super.key,
    required this.snapshot,
    required this.pendingRetest,
    required this.bottomPadding,
    required this.onReload,
    this.onProfileChanged,
  });

  final PlanSnapshot snapshot;
  final PendingFitnessRetest? pendingRetest;
  final double bottomPadding;
  final VoidCallback onReload;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<_PlanContent> createState() => _PlanContentState();
}

class _PlanContentState extends State<_PlanContent> {
  final _launches = WorkoutLaunchService();
  late final List<PlanWeek> _weeks;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _weeks = _PlanWeekMapper.fromSnapshot(
      widget.snapshot,
      pendingRetest: widget.pendingRetest,
    );
    final currentIndex =
        _weeks.indexWhere((w) => w.status == WeekStatus.current);
    _selectedIndex = currentIndex == -1 ? 0 : currentIndex;
  }

  void _selectWeek(int i) {
    if (i == _selectedIndex) return;
    setState(() => _selectedIndex = i);
  }

  reco.WeekPlan get _selectedRecoWeek =>
      widget.snapshot.plan.weeks[_selectedIndex];

  PlanWeek get _selectedWeek => _weeks[_selectedIndex];

  bool get _isShowingCurrentWeek => _selectedWeek.status == WeekStatus.current;

  void _startCurrentSession() {
    unawaited(_startWeek(_selectedRecoWeek));
  }

  Future<void> _startWeek(reco.WeekPlan week) async {
    final target = await _launches.resolveFromSnapshot(
      widget.snapshot,
      week: week,
    );
    if (!mounted) return;
    final first = target?.firstLaunchArgs;
    if (first != null) {
      await _runWorkoutSequence(first);
      if (!mounted) return;
      widget.onReload();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Bài tập này chưa có màn hình camera trong app.'),
        ),
      );
  }

  Future<void> _runWorkoutSequence(ExerciseLaunchArgs first) async {
    ExerciseLaunchArgs? next = first;
    var completedFinalSlot = false;
    while (mounted && next != null) {
      final result = await Navigator.of(context).pushNamed(
        '/exercise',
        arguments: next,
      );
      if (!mounted) return;
      if (result is Map && result['next'] is ExerciseLaunchArgs) {
        next = result['next'] as ExerciseLaunchArgs;
      } else {
        completedFinalSlot = result is Map && result['completed'] == true;
        next = null;
      }
    }
    if (completedFinalSlot) {
      await SessionPersistence().updateStreak();
      final profile = await UserProfileService().fetchCurrentProfile();
      if (profile != null) widget.onProfileChanged?.call(profile);
    }
  }

  Future<void> _startRetest() async {
    final pending = widget.pendingRetest;
    if (pending == null) return;
    final completed = await Navigator.of(context).pushNamed(
      '/plan-retest',
      arguments: PlanRetestLaunchArgs(pending: pending),
    );
    if (!context.mounted || completed != true) return;
    widget.onReload();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      // Defeat MainShell's top SafeArea so the dark hero bleeds into the
      // status bar area, same as Home.
      context: context,
      removeTop: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlanStageHero(
              weeks: _weeks,
              selectedIndex: _selectedIndex,
              onSelectWeek: _selectWeek,
              onStartCurrentSession: _startCurrentSession,
              userInitial: 'N',
            ),
            PlanDayTimeline(
              days: _selectedWeek.days,
              weekStatus: _selectedWeek.status,
              weekNumber: _selectedWeek.num,
              phaseName: _selectedWeek.name,
              onStartSession:
                  _isShowingCurrentWeek ? _startCurrentSession : null,
              onStartRetest: widget.pendingRetest == null ? null : _startRetest,
            ),
            EditorialCloser(
              section: 'LỘ TRÌNH',
              tagline: '${_weeks.length} tuần · ${_selectedWeek.name}.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHELL MESSAGE — loading / empty states
// ═══════════════════════════════════════════════════════════════

class _PlanShellMessage extends StatelessWidget {
  const _PlanShellMessage({
    required this.title,
    required this.body,
    required this.bottomPadding,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPadding + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1.2,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: c.inkSoft,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: c.yellow,
                  foregroundColor: c.yellowInk,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DATA + MAPPER — kept verbatim from v1
// ═══════════════════════════════════════════════════════════════

class _PlanScreenData {
  const _PlanScreenData({
    required this.snapshot,
    required this.pendingRetest,
  });

  final PlanSnapshot? snapshot;
  final PendingFitnessRetest? pendingRetest;
}

class _PlanWeekMapper {
  const _PlanWeekMapper._();

  static List<PlanWeek> fromSnapshot(
    PlanSnapshot snapshot, {
    PendingFitnessRetest? pendingRetest,
  }) {
    final plan = snapshot.plan;
    final currentWeek = snapshot.currentWeekNumber;
    final anchor = snapshot.startedAt ?? snapshot.generatedAt ?? DateTime.now();
    final weekOneStart = _mondayOfWeek(_localDay(anchor));
    final lastWeekNumber = plan.weeks.isEmpty ? 0 : plan.weeks.last.weekNumber;

    return plan.weeks.map((week) {
      final status = week.weekNumber < currentWeek
          ? WeekStatus.done
          : week.weekNumber == currentWeek
              ? WeekStatus.current
              : WeekStatus.future;
      final weekStart = weekOneStart.add(
        Duration(days: (week.weekNumber - 1) * 7),
      );
      final days = _daysForWeek(
        week: week,
        status: status,
        weekStart: weekStart,
        scheduleDayIndexes: snapshot.scheduleDayIndexes,
        hasPendingRetest:
            pendingRetest != null && week.weekNumber == lastWeekNumber,
      );
      final completed = days.where((d) => d.status == DayStatus.done).length;

      return PlanWeek(
        num: week.weekNumber,
        name: week.phaseName,
        dates: '${_shortDate(weekStart)} – '
            '${_shortDate(weekStart.add(const Duration(days: 6)))}',
        status: status,
        sessions: week.sessions.length,
        completed: completed,
        bodyFocus: week.isDeloadWeek ? 'Phục hồi' : _bodyFocus(week),
        focus: _focusLine(week),
        body: _usesHipFocus(week) ? BodyRegion.hip : BodyRegion.none,
        avgForm: status == WeekStatus.done ? 78 : null,
        recap: week.isDeloadWeek
            ? 'Tuần giảm tải đã hoàn tất. Cơ thể có khoảng nghỉ trước khi kiểm tra tiến độ.'
            : 'Tuần này hoàn tất. Bài tập giữ ổn định để bạn xây nền thật chắc.',
        bestDay: completed > 0
            ? days.firstWhere((d) => d.status == DayStatus.done).weekday
            : null,
        coachLine: week.isDeloadWeek
            ? 'Tuần này nhẹ hơn có chủ đích. Giữ form sạch, thở đều và để cơ thể hồi lại.'
            : 'Bài tập giữ quen thuộc, mục tiêu tăng vừa đủ để bạn thấy tiến bộ mà không bị quá sức.',
        chapterLine: week.isDeloadWeek
            ? 'Một tuần nhẹ hơn để cơ thể hấp thụ tiến bộ trước bài kiểm tra lại.'
            : 'Bài tập tiếp tục từ nền hiện tại, với mục tiêu tăng dần theo thuật toán.',
        unlockNote: week.isDeloadWeek
            ? 'Mở sau khi hoàn tất các tuần phát triển.'
            : 'Mở khoá khi bạn đi đến tuần này.',
        days: days,
      );
    }).toList(growable: false);
  }

  static List<PlanDay> _daysForWeek({
    required reco.WeekPlan week,
    required WeekStatus status,
    required DateTime weekStart,
    required List<int> scheduleDayIndexes,
    required bool hasPendingRetest,
  }) {
    final sessionDayIndexes =
        _sessionDayIndexes(week.sessions.length, scheduleDayIndexes);
    var sessionCursor = 0;

    return [
      for (var i = 0; i < 7; i++)
        if (hasPendingRetest && i == 6)
          _retestDay(
            date: weekStart.add(Duration(days: i)),
          )
        else if (sessionDayIndexes.contains(i))
          _sessionDay(
            week: week,
            session: week.sessions[sessionCursor++],
            status: _dayStatusFor(
              weekStatus: status,
              date: weekStart.add(Duration(days: i)),
            ),
            date: weekStart.add(Duration(days: i)),
          )
        else
          PlanDay(
            weekday: _weekdayShortForDate(weekStart.add(Duration(days: i))),
            weekdayLong: _weekdayLongForDate(
              weekStart.add(Duration(days: i)),
            ),
            date: _shortDate(weekStart.add(Duration(days: i))),
            status: DayStatus.rest,
          ),
    ];
  }

  static PlanDay _retestDay({
    required DateTime date,
  }) {
    return PlanDay(
      weekday: _weekdayShortForDate(date),
      weekdayLong: _weekdayLongForDate(date),
      date: _shortDate(date),
      status: DayStatus.recheck,
      title: 'Kiểm tra lại thể lực',
      duration: '5 phút',
      count: 2,
      coach:
          'Làm lại bài kiểm tra ngắn. Sau khi xong, bạn vẫn có thể tập tiếp hôm nay.',
      exercises: const [
        PlanExercise(
          name: 'Squat assessment',
          volumeLabel: 'Đo lực chân',
          hasAi: true,
          form: 0,
        ),
        PlanExercise(
          name: 'Wall push-up assessment',
          volumeLabel: 'Đo lực thân trên',
          hasAi: true,
          form: 0,
        ),
      ],
    );
  }

  static PlanDay _sessionDay({
    required reco.WeekPlan week,
    required reco.SessionPlan session,
    required DayStatus status,
    required DateTime date,
  }) {
    final count = session.slots.length;
    final exercises = session.slots
        .map(
          (slot) => PlanExercise(
            name: _exerciseLabel(slot.exerciseId),
            volumeLabel: _volumeLabel(slot.volume),
            exerciseId: slot.exerciseId,
            hasAi: lookupExerciseDefinition(slot.exerciseId) != null,
            form: 78,
          ),
        )
        .toList(growable: false);
    final sessionNum = session.sessionIndex + 1;

    return PlanDay(
      weekday: _weekdayShortForDate(date),
      weekdayLong: _weekdayLongForDate(date),
      date: _shortDate(date),
      status: status,
      title: week.isDeloadWeek
          ? 'Phục hồi nhẹ'
          : sessionNum == 1
              ? 'Buổi mở tuần'
              : 'Buổi ${sessionNum.toString().padLeft(2, '0')}',
      duration: '${(count * 5).clamp(12, 35)} phút',
      count: count,
      form: status == DayStatus.done ? 78 : null,
      coach: week.isDeloadWeek
          ? 'Giữ nhẹ, chậm và chắc. Đây là tuần hồi phục có chủ đích.'
          : 'Mục tiêu hôm nay: hoàn thành đủ số rep/giây với form ổn định.',
      exercises: exercises,
    );
  }

  static DayStatus _dayStatusFor({
    required WeekStatus weekStatus,
    required DateTime date,
  }) {
    return switch (weekStatus) {
      WeekStatus.done => DayStatus.done,
      WeekStatus.future => DayStatus.planned,
      WeekStatus.current => _isSameLocalDay(date, DateTime.now())
          ? DayStatus.today
          : DayStatus.planned,
    };
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static List<int> _sessionDayIndexes(
    int sessionCount,
    List<int> scheduleDayIndexes,
  ) {
    final scheduleDays = scheduleDayIndexes
        .where((day) => day >= 0 && day <= 6)
        .toSet()
        .toList()
      ..sort();
    if (scheduleDays.length >= sessionCount) {
      return scheduleDays.take(sessionCount).toList(growable: false);
    }

    return switch (sessionCount) {
      <= 0 => const <int>[],
      1 => const [0],
      2 => const [0, 3],
      3 => const [0, 2, 4],
      4 => const [0, 1, 3, 5],
      5 => const [0, 1, 2, 3, 4],
      _ => const [0, 1, 2, 3, 4, 5],
    };
  }

  static DateTime _localDay(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _mondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  static String _shortDate(DateTime date) => '${date.day}/${date.month}';

  static String _weekdayShortForDate(DateTime date) {
    const values = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final index = date.weekday - DateTime.monday;
    return values[index.clamp(0, values.length - 1)];
  }

  static String _weekdayLongForDate(DateTime date) {
    const values = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final index = date.weekday - DateTime.monday;
    return values[index.clamp(0, values.length - 1)];
  }

  static String _bodyFocus(reco.WeekPlan week) {
    final ids = week.sessions
        .expand((session) => session.slots)
        .map((slot) => slot.slotName)
        .join(' ');
    if (ids.contains('yoga') || ids.contains('mobility')) return 'Dẻo dai';
    if (ids.contains('core')) return 'Cốt lõi';
    if (ids.contains('lower')) return 'Chân & hông';
    if (ids.contains('upper')) return 'Thân trên';
    return week.phaseName;
  }

  static String _focusLine(reco.WeekPlan week) {
    final firstSlot = week.sessions.isEmpty || week.sessions.first.slots.isEmpty
        ? null
        : week.sessions.first.slots.first;
    if (firstSlot == null) return 'Giữ nhịp tập ổn định';
    return '${_exerciseLabel(firstSlot.exerciseId)} · '
        '${_volumeLabel(firstSlot.volume)}';
  }

  static bool _usesHipFocus(reco.WeekPlan week) {
    final ids = week.sessions
        .expand((session) => session.slots)
        .map((slot) => '${slot.slotName} ${slot.exerciseId}')
        .join(' ');
    return ids.contains('lower') ||
        ids.contains('hip') ||
        ids.contains('glute') ||
        ids.contains('squat');
  }

  static String _exerciseLabel(String id) {
    final definition = lookupExerciseDefinition(id);
    if (definition != null) return definition.name;
    return switch (id) {
      'squat_bw' => 'Squat',
      'wall_pushup' || 'wall_pushup_assessment' => 'Wall Push-Up',
      'glute_bridge_bw' => 'Glute Bridge',
      'mcgill_curl_up' => 'Curl-Up',
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

  static String _volumeLabel(reco.VolumePrescription volume) {
    final target = volume.reps != null
        ? '${volume.reps} rep'
        : volume.seconds != null
            ? '${volume.seconds} giây'
            : '';
    if (target.isEmpty) return '${volume.sets} hiệp';
    return '${volume.sets} x $target';
  }
}
