// ProgressScreen — the Tiến bộ tab. Premium Ivory v2 (cinematic).
//
// Architecture (top to bottom):
//   1. Dark stage hero — full-bleed, atmospheric, period tabs embedded
//   2. Score gauge card — circular arc + 74/100 + delta + coach quote
//   3. Weekly summary band — 4 editorial stats with delta notes
//   4. Score trend chart — line chart with grid + "today" dot
//   5. Body heat map — silhouette + 2×2 area cards
//   6. Ranked exercise insights — top-3 with sparklines (expandable)
//   7. Personal records rail — horizontal PR cards with "MỚI" pulse
//   8. Streak card — weekly mini-summary + milestone hint
//   9. Closer with back-to-top
//
// Sticky pill bar slides in after scroll past the hero (matches Library).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../data/milestones.dart';
import '../data/progress_mock.dart';
import '../models/exercise_lookup.dart';
import '../models/pain_regions.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/session_persistence.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/ivory/skeleton.dart';
import '../widgets/progress/body_heat_map.dart';
import '../widgets/progress/milestone_rail.dart';
import '../widgets/progress/period_tabs.dart';
import '../widgets/progress/progress_stage_hero.dart';
import '../widgets/progress/exercise_insight_grid.dart';
import '../widgets/progress/score_gauge_card.dart';
import '../widgets/progress/score_trend_chart.dart';
import '../widgets/progress/streak_week_strip.dart';
import '../widgets/progress/weekly_summary_band.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.bottomPadding,
    this.refreshListenable,
    this.userProfile,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final Listenable? refreshListenable;
  final AppUserProfile? userProfile;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _profileService = UserProfileService();
  final _sessions = SessionPersistence();
  final _recommendations = RecommendationService();
  PeriodTab _period = PeriodTab.program;
  final ScrollController _scrollController = ScrollController();
  bool _showStickyBar = false;
  bool _showDownFab = false;
  AppUserProfile? _profile;
  bool _loadingProfile = false;
  bool _profileReloadQueued = false;

  /// Real ĐIỂM FORM gauge summary, SCOPED to the active period pill (week /
  /// phase / program). Drives the gauge's average + coach only — the trend
  /// list is no longer rendered from here (the chart reads [_programSummary]).
  /// Null = loading (placeholder); a loaded record with `average == null` =
  /// no sessions in this scope (empty state).
  ({
    int? average,
    FormTrendDirection direction,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  })? _formSummary;

  /// Real ĐƯỜNG TIẾN BỘ trajectory, FIXED to whole-program scope (NOT the
  /// period pill). A program week caps at 3 sessions, so a week-scoped trend
  /// sits at/under the 3-session reveal gate and reads thin; the trajectory
  /// only reads over the full span. Loaded once when the plan resolves. Same
  /// record shape as [_formSummary]. Null = loading.
  ({
    int? average,
    FormTrendDirection direction,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  })? _programSummary;

  /// Real BÀI TẬP NỔI BẬT ranked insights, FIXED to whole-program scope (same
  /// reasoning as [_programSummary] — week scope is too thin to rank). Loaded
  /// once when the plan resolves, NOT on tab change. Null = loading; empty =
  /// nothing qualified yet (guided empty shown).
  List<RankInsightHeadline>? _insights;

  /// Real hero phase/week label, derived from the active plan snapshot
  /// (the SAME source the Plan tab uses). Null until resolved; once resolved
  /// it stays null when there's no active plan (guided-empty label shown).
  String? _phaseLabel;
  bool _planResolved = false;

  /// The active plan snapshot, RETAINED (not just its label string) so the
  /// period feeds can scope by program position — the active week, the active
  /// phase's weeks, or the whole plan. Null when there's no active plan.
  PlanSnapshot? _snapshot;

  /// Real TỔNG QUAN TUẦN NÀY weekly summary for the current program week.
  /// Null = loading.
  ({
    int sessions,
    int totalSeconds,
    int? avgForm,
    int? sessionsDelta,
    int? secondsDelta,
    int? avgFormDelta,
  })? _weekly;

  /// Real CỘT MỐC milestones (full catalog with unlock state resolved). Null
  /// = loading. Never empty — locked rungs render as targets to chase.
  List<Milestone>? _milestones;

  /// Real weekly activity for the "Chuỗi" strip — anchored at the user's first
  /// active week, growing forward, capped at 12 (oldest-first, last = current
  /// week). Null = loading; empty = no activity yet.
  List<bool>? _streakWeekBars;

  /// Active pain self-reports keyed by body_region. Null = loading
  /// (show the silhouette placeholder); empty map = nothing reported yet.
  Map<String, PainMark>? _painReports;

  /// Raw `profiles.gender` for the silhouette. Null/unknown defaults to male.
  String? _gender;

  /// Scroll offset past which the sticky pill bar fades in.
  static const double _stickyBarThreshold = 240;

  /// Within this many px of the bottom the "Xuống cuối" FAB hides — there's
  /// nowhere left to jump.
  static const double _fabEdge = 140;

  /// Preview toggle: drive EVERY Progress section from mock data so the full
  /// design is visible without any logged sessions. When true the loaders set
  /// mock state instead of hitting Supabase. False = show only real,
  /// data-derived content (the guided-empty states return below the threshold).
  ///
  /// `final` (not `const`) on purpose: the untaken preview branches must stay
  /// live code, not dead-code-eliminated, so the toggle flips cleanly.
  static final bool _previewWithMock = false;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _profile = widget.userProfile;
    widget.refreshListenable?.addListener(_handleRefreshNudge);
    _scrollController.addListener(_onScroll);
    // The form + insights + weekly feeds scope by program position, so they're
    // driven from the plan snapshot (loaded here) rather than fired independently.
    unawaited(_loadPlan());
    unawaited(_loadMilestones());
    unawaited(_loadStreakWeekBars());
    unawaited(_loadPainReports());
    unawaited(_loadGender());
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _profile = widget.userProfile;
    }
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_handleRefreshNudge);
      widget.refreshListenable?.addListener(_handleRefreshNudge);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_handleRefreshNudge);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRefreshNudge() {
    unawaited(_loadProfile());
    unawaited(_loadPlan());
    unawaited(_loadMilestones());
    unawaited(_loadStreakWeekBars());
    unawaited(_loadPainReports());
    unawaited(_loadGender());
  }

  /// Loads active pain self-reports into [_painReports]. Maps each row's
  /// source so interpreter-'confirmed' areas read differently from plain
  /// self-reports in the UI.
  Future<void> _loadPainReports() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _painReports = _mockPainReports);
      return;
    }
    final reports = await _sessions.getActivePainReports();
    if (!mounted) return;
    setState(() {
      _painReports = {
        for (final r in reports)
          r.region: PainMark(
            intensity: r.intensity,
            confirmed: r.source == 'confirmed',
            notes: r.notes,
          ),
      };
    });
  }

  Future<void> _loadGender() async {
    final gender = await _profileService.fetchGender();
    if (!mounted) return;
    setState(() => _gender = gender);
  }

  /// Capture-only: persist a self-report, then refresh the silhouette.
  Future<void> _reportPain(String region, int intensity, String? notes) async {
    await _sessions.reportPainArea(region, intensity, notes: notes);
    await _loadPainReports();
  }

  /// Capture-only: resolve (never delete) a report, then refresh.
  Future<void> _resolvePain(String region) async {
    await _sessions.resolvePainArea(region);
    await _loadPainReports();
  }

  Future<void> _loadProfile() async {
    if (_loadingProfile) {
      _profileReloadQueued = true;
      return;
    }
    _loadingProfile = true;
    try {
      final profile = await _profileService.fetchCurrentProfile();
      if (!mounted || profile == null) return;
      setState(() => _profile = profile);
      widget.onProfileChanged?.call(profile);
    } finally {
      _loadingProfile = false;
      if (_profileReloadQueued && mounted) {
        _profileReloadQueued = false;
        unawaited(_loadProfile());
      }
    }
  }

  /// Loads the active plan snapshot — the SAME source the Plan tab uses
  /// (RecommendationService) — RETAINING it so the period feeds can scope by
  /// program position, then derives the hero label and kicks off the form +
  /// insights feeds. Stays null (guided empty) when there is no active plan.
  Future<void> _loadPlan() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() {
        _planResolved = true;
        _phaseLabel = 'PHASE 2 · 18 / 28 BUỔI · TUẦN 4 / 7';
      });
      unawaited(_loadFormSummary(_period));
      unawaited(_loadProgramSummary());
      unawaited(_loadInsights());
      unawaited(_loadWeekly());
      return;
    }
    final snapshot =
        await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _planResolved = true;
      _phaseLabel = _derivePhaseLabel(snapshot);
    });
    // Now that the scope is known, load the feeds. The gauge ([_formSummary])
    // is scoped to the active pill and re-loads on tab change; the trajectory
    // chart ([_programSummary]), insights, and weekly band are FIXED-scope and
    // load here once.
    unawaited(_loadFormSummary(_period));
    unawaited(_loadProgramSummary());
    unawaited(_loadInsights());
    unawaited(_loadWeekly());
  }

  /// Program-position scope for [period] from the retained snapshot:
  ///   week    → the active plan week
  ///   phase   → every week sharing the active week's phaseNumber
  ///   program → null weekNumbers (the whole plan)
  /// Null when there's no active plan to scope to (guided empty shown).
  ({String recommendationId, List<int>? weekNumbers})? _scopeFor(
      PeriodTab period) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) return null;
    final weeks = snapshot.plan.weeks;
    final recId = snapshot.plan.recommendationId;
    // currentWeek falls back to the last week once the plan is complete.
    final currentWeek = snapshot.currentWeek ?? weeks.last;
    return switch (period) {
      PeriodTab.week => (
          recommendationId: recId,
          weekNumbers: [currentWeek.weekNumber],
        ),
      PeriodTab.phase => (
          recommendationId: recId,
          weekNumbers: [
            for (final w in weeks)
              if (w.phaseNumber == currentWeek.phaseNumber) w.weekNumber,
          ],
        ),
      PeriodTab.program => (recommendationId: recId, weekNumbers: null),
    };
  }

  /// Loads the real form summary for [period], scoped to the active plan.
  /// Stale responses (the user switched period before this resolved) are
  /// discarded. No active plan → an empty record (guided empty), never a flash.
  Future<void> _loadFormSummary(PeriodTab period) async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted || period != _period) return;
      setState(() => _formSummary = _mockFormSummary(period));
      return;
    }
    final scope = _scopeFor(period);
    if (scope == null) {
      if (!mounted || period != _period) return;
      setState(() => _formSummary = const (
            average: null,
            direction: FormTrendDirection.none,
            trend: <int>[],
            trendDates: <DateTime>[],
            fact: '',
          ));
      return;
    }
    final summary = await _sessions.progressFormSummary(
      scope.recommendationId,
      scope.weekNumbers,
    );
    if (!mounted || period != _period) return;
    setState(() => _formSummary = summary);
  }

  /// Loads the FIXED whole-program trajectory into [_programSummary] (drives
  /// the ĐƯỜNG TIẾN BỘ chart). Independent of the period pill — uses the
  /// program scope always. No active plan → an empty record (guided empty).
  Future<void> _loadProgramSummary() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _programSummary = _mockFormSummary(PeriodTab.program));
      return;
    }
    final scope = _scopeFor(PeriodTab.program);
    if (scope == null) {
      if (!mounted) return;
      setState(() => _programSummary = const (
            average: null,
            direction: FormTrendDirection.none,
            trend: <int>[],
            trendDates: <DateTime>[],
            fact: '',
          ));
      return;
    }
    final summary = await _sessions.progressFormSummary(
      scope.recommendationId,
      scope.weekNumbers, // null = whole program
    );
    if (!mounted) return;
    setState(() => _programSummary = summary);
  }

  /// Loads the FIXED whole-program ranked insights into [_insights]. Independent
  /// of the period pill (week scope is too thin to rank) — uses the program
  /// scope always, loaded once when the plan resolves.
  Future<void> _loadInsights() async {
    // Preview renders mock directly in _buildInsightsSection; skip the fetch.
    if (_previewWithMock) return;
    final scope = _scopeFor(PeriodTab.program);
    if (scope == null) {
      if (!mounted) return;
      setState(() => _insights = const <RankInsightHeadline>[]);
      return;
    }
    final insights = await _sessions.rankedInsights(
      scope.recommendationId,
      scope.weekNumbers, // null = whole program
    );
    if (!mounted) return;
    setState(() => _insights = insights);
  }

  /// 'PHASE p · done / total BUỔI · TUẦN w / W' from the engine snapshot, or
  /// null when there's no active plan to summarise.
  String? _derivePhaseLabel(PlanSnapshot? snapshot) {
    if (snapshot == null || snapshot.plan.weeks.isEmpty) return null;
    final weeks = snapshot.plan.weeks;
    var totalSessions = 0;
    var doneSessions = 0;
    for (final w in weeks) {
      totalSessions += w.sessions.length;
      final done = snapshot.completionMap[w.weekNumber] ?? const <int>{};
      doneSessions +=
          w.sessions.where((s) => done.contains(s.sessionIndex)).length;
    }
    // currentWeek falls back to the last week once the plan is complete.
    final currentWeek = snapshot.currentWeek ?? weeks.last;
    return 'PHASE ${currentWeek.phaseNumber} · '
        '$doneSessions / $totalSessions BUỔI · '
        'TUẦN ${currentWeek.weekNumber} / ${weeks.length}';
  }

  /// Loads the TỔNG QUAN TUẦN NÀY band for the CURRENT program week, scoped to
  /// the retained snapshot (same source as the form/insights feeds). The band
  /// is always the current week (NOT tab-driven). No snapshot / no plan → the
  /// empty record (existing guided empty).
  Future<void> _loadWeekly() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _weekly = _mockWeekly);
      return;
    }
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) {
      if (!mounted) return;
      setState(() => _weekly = const (
            sessions: 0,
            totalSeconds: 0,
            avgForm: null,
            sessionsDelta: null,
            secondsDelta: null,
            avgFormDelta: null,
          ));
      return;
    }
    // currentWeek falls back to the last week once the plan is complete.
    final currentWeek = snapshot.currentWeek ?? snapshot.plan.weeks.last;
    final weekly = await _sessions.weeklySummary(
      snapshot.plan.recommendationId,
      currentWeek.weekNumber,
    );
    if (!mounted) return;
    setState(() => _weekly = weekly);
  }

  Future<void> _loadMilestones() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _milestones = _mockMilestones());
      return;
    }
    final milestones = await _sessions.milestones();
    if (!mounted) return;
    setState(() => _milestones = milestones);
  }

  Future<void> _loadStreakWeekBars() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _streakWeekBars = progressMockStreakWeekBars);
      return;
    }
    final bars = await _sessions.streakWeekBars();
    if (!mounted) return;
    setState(() => _streakWeekBars = bars);
  }

  // ── Mock preview builders (only used while [_previewWithMock] is on) ──

  /// Mock ĐIỂM FORM gauge + trend for [period], built from progress_mock.
  ({
    int? average,
    FormTrendDirection direction,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  }) _mockFormSummary(PeriodTab period) {
    final key = switch (period) {
      PeriodTab.week => 'week',
      // Reuse the existing 'month' preview bucket for the renamed phase tab —
      // preview-only mock data, not part of the real program-scoped path.
      PeriodTab.phase => 'month',
      PeriodTab.program => 'program',
    };
    final h = progressMockHeadline[key]!;
    final trend = progressMockScoreTrend[key]!;
    final now = DateTime.now();
    return (
      average: h.average,
      // The gauge no longer renders a direction chip; the program chart owns
      // trajectory. `none` keeps the record shape without implying a chip.
      direction: FormTrendDirection.none,
      trend: trend,
      trendDates: [
        for (var i = 0; i < trend.length; i++)
          now.subtract(Duration(days: (trend.length - 1 - i) * 2)),
      ],
      fact: h.coach,
    );
  }

  /// Mock TỔNG QUAN TUẦN NÀY weekly summary (5 buổi · 2h12' · form 74, +deltas).
  static const ({
    int sessions,
    int totalSeconds,
    int? avgForm,
    int? sessionsDelta,
    int? secondsDelta,
    int? avgFormDelta,
  }) _mockWeekly = (
    sessions: 5,
    totalSeconds: 7920,
    avgForm: 74,
    sessionsDelta: 1,
    secondsDelta: 720,
    avgFormDelta: 3,
  );

  /// Mock CỘT MỐC unlock state — a realistic mix of opened + locked rungs.
  List<Milestone> _mockMilestones() {
    bool unlocked(Milestone m) =>
        (m.category == MilestoneCategory.streak && m.threshold <= 7) ||
        (m.category == MilestoneCategory.sessions && m.threshold <= 10) ||
        (m.category == MilestoneCategory.form && m.threshold <= 80) ||
        (m.category == MilestoneCategory.consistency &&
            m.threshold == kConsistencyWeek);
    return [
      for (final m in milestoneCatalog) unlocked(m) ? m.asUnlocked('22/5') : m,
    ];
  }

  /// Mock CƠ THỂ pain self-reports across a few regions.
  static const Map<String, PainMark> _mockPainReports = {
    'knee': PainMark(intensity: 3),
    'lower_back': PainMark(intensity: 2, confirmed: true),
    'shoulder_neck': PainMark(intensity: 2),
  };

  /// 'd/M' from a local DateTime, for record date stamps + trend axis ticks.
  String _fmtDayMonth(DateTime d) => '${d.day}/${d.month}';

  void _onPeriodChanged(PeriodTab period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      // Only the gauge rescopes. Drop it to the loading placeholder so it
      // re-mounts and re-animates with the new scope's average. The trajectory
      // chart + insights are fixed whole-program, so they stay put (no flash).
      _formSummary = null;
    });
    unawaited(_loadFormSummary(period));
  }

  void _onScroll() {
    final pos = _scrollController.position;
    final offset = pos.pixels;
    final shouldShow = offset > _stickyBarThreshold;

    // "Xuống cuối" FAB — only while heading down (the sticky bar up top already
    // covers going back to the top). Scrolling up hides it; near the bottom
    // there's nowhere left to jump, so it hides there too. On idle the last
    // state persists so the user can still tap after the flick settles.
    var showDown = _showDownFab;
    switch (pos.userScrollDirection) {
      case ScrollDirection.reverse:
        showDown = offset < pos.maxScrollExtent - _fabEdge;
      case ScrollDirection.forward:
        showDown = false;
      case ScrollDirection.idle:
        break;
    }

    if (shouldShow != _showStickyBar || showDown != _showDownFab) {
      setState(() {
        _showStickyBar = shouldShow;
        _showDownFab = showDown;
      });
    }
  }

  void _onStickyBarTap() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
    );
  }

  /// Program-relative eyebrow for [period], derived from the retained plan
  /// snapshot — replaces the old calendar (now − N days) date stamps. Drives
  /// both the hero period stamp and the ĐIỂM FORM gauge eyebrow. Falls back to
  /// neutral copy (no fabricated dates) when there's no active plan.
  ///
  ///   week    → TUẦN {abs} · {PHASE} · TUẦN {inPhase}/{phaseLen}
  ///   phase   → {PHASE} · TUẦN {firstWk}-{lastWk}  (or TUẦN {wk} if single)
  ///   program → TOÀN CHƯƠNG TRÌNH · {totalWeeks} TUẦN
  String _periodEyebrow(PeriodTab period) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) {
      return switch (period) {
        PeriodTab.week => 'TUẦN NÀY',
        PeriodTab.phase => 'GIAI ĐOẠN NÀY',
        PeriodTab.program => 'TOÀN CHƯƠNG TRÌNH',
      };
    }
    final weeks = snapshot.plan.weeks;
    final currentWeek = snapshot.currentWeek ?? weeks.last;
    final phaseName = currentWeek.phaseName.toUpperCase();
    final phaseWeeks = [
      for (final w in weeks)
        if (w.phaseNumber == currentWeek.phaseNumber) w.weekNumber,
    ]..sort();
    final firstWk =
        phaseWeeks.isEmpty ? currentWeek.weekNumber : phaseWeeks.first;
    final lastWk =
        phaseWeeks.isEmpty ? currentWeek.weekNumber : phaseWeeks.last;
    final phaseLen = phaseWeeks.isEmpty ? 1 : phaseWeeks.length;
    final inPhaseIdx = phaseWeeks.indexOf(currentWeek.weekNumber);
    final inPhase = inPhaseIdx < 0 ? 1 : inPhaseIdx + 1;
    return switch (period) {
      PeriodTab.week =>
        'TUẦN ${currentWeek.weekNumber} · $phaseName · TUẦN $inPhase/$phaseLen',
      PeriodTab.phase => firstWk == lastWk
          ? '$phaseName · TUẦN $firstWk'
          : '$phaseName · TUẦN $firstWk-$lastWk',
      PeriodTab.program => 'TOÀN CHƯƠNG TRÌNH · ${weeks.length} TUẦN',
    };
  }

  /// Huge faint chapter mark for the hero, data-bound to program position:
  ///   week    → 'T{currentWeek.weekNumber}'
  ///   phase   → 'G{currentWeek.phaseNumber}'
  ///   program → 'P{distinct phaseNumber count across the plan}'
  /// No active plan → the old static 'T1'/'G1'/'P1' fallback.
  String _heroWatermark(PeriodTab period) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) {
      return switch (period) {
        PeriodTab.week => 'T1',
        PeriodTab.phase => 'G1',
        PeriodTab.program => 'P1',
      };
    }
    final weeks = snapshot.plan.weeks;
    final currentWeek = snapshot.currentWeek ?? weeks.last;
    return switch (period) {
      PeriodTab.week => 'T${currentWeek.weekNumber}',
      PeriodTab.phase => 'G${currentWeek.phaseNumber}',
      PeriodTab.program =>
        'P${weeks.map((w) => w.phaseNumber).toSet().length}',
    };
  }

  String _activePeriodLabel() => switch (_period) {
        PeriodTab.week => 'Tuần',
        PeriodTab.phase => 'Giai đoạn',
        PeriodTab.program => 'Cả lộ trình',
      };

  /// Signed delta string: '+5', '0', '-3'. The minus is carried by the
  /// number itself; only non-negatives get a leading '+'.
  String _signedDelta(int d) => '${d >= 0 ? '+' : ''}$d';

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // ĐIỂM FORM gauge is SCOPED to the active pill; the ĐƯỜNG TIẾN BỘ chart is
    // FIXED to whole-program.
    final formSummary = _formSummary;
    final loadingForm = formSummary == null;
    final hasForm = formSummary != null && formSummary.average != null;
    // The trajectory chart reads the FIXED program summary, gated on 3+
    // sessions across the whole program (progressive reveal).
    final programSummary = _programSummary;
    final hasTrend = programSummary != null && programSummary.trend.length >= 3;
    final profile = _profile ?? widget.userProfile;
    final userInitial = profile?.initial ?? 'N';
    final streakWeeks = _previewWithMock
        ? progressMockStreakWeeks
        : (profile?.streakWeeks ?? 0);
    final phaseLabel = !_planResolved
        ? 'ĐANG TẢI…'
        : (_phaseLabel ?? 'CHƯA CÓ LỘ TRÌNH');

    return Container(
      color: c.bg,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProgressStageHero(
                    period: _period,
                    onPeriodChanged: _onPeriodChanged,
                    userInitial: userInitial,
                    avatarUrl: profile?.avatarUrl,
                    phaseLabel: phaseLabel,
                    weekLabel: _periodEyebrow(_period),
                    watermark: _heroWatermark(_period),
                  ),
                  const SizedBox(height: 24),

                  // 1. ĐIỂM FORM — score gauge card, SCOPED to the active pill.
                  // Headline is the scope AVERAGE (renders at >= 1 session); no
                  // trend/direction chip — the gauge is a scoped average, full
                  // stop. All trajectory lives in the fixed program chart below.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: hasForm
                        ? ScoreGaugeCard(
                            data: HeadlineForPeriod(
                              average: formSummary.average!,
                              // Short scope tag (TUẦN NÀY / GIAI ĐOẠN NÀY /
                              // TOÀN CHƯƠNG TRÌNH); the hero carries the detail.
                              label: _gaugeLabel(),
                              // A factual trajectory one-liner (NOT coaching,
                              // NOT the session coach), derived from the real
                              // slope + average in progressFormSummary.
                              coach: formSummary.fact,
                            ),
                          )
                        : _GaugePlaceholder(loading: loadingForm),
                  ),
                  const SizedBox(height: 40),

                  // 2. TỔNG QUAN TUẦN NÀY — weekly summary band (real data).
                  _buildWeeklySection(c),
                  const SizedBox(height: 40),

                  // 3. ĐƯỜNG TIẾN BỘ — score trend chart, FIXED whole-program
                  // (reads [_programSummary], NOT the period pill). Gated on 3+
                  // sessions across the whole program. The TOÀN CHƯƠNG TRÌNH tag
                  // makes the fixed scope legible next to the scoped gauge above.
                  if (hasTrend) ...[
                    _SectionHeader(
                      index: '01',
                      eyebrow: 'ĐƯỜNG TIẾN BỘ',
                      meta: 'TOÀN CHƯƠNG TRÌNH',
                      intro:
                          'Mỗi điểm tô đậm là một buổi. Đường đi lên là form đã ổn.',
                    ),
                    const SizedBox(height: 14),
                    // Axis labels are real dates from the session timestamps
                    // backing the trend (start / mid / end), bucketed local.
                    ScoreTrendChart(
                      points: programSummary.trend,
                      startLabel: _fmtDayMonth(
                          programSummary.trendDates.first.toLocal()),
                      midLabel: _fmtDayMonth(programSummary
                          .trendDates[programSummary.trendDates.length ~/ 2]
                          .toLocal()),
                      endLabel: _fmtDayMonth(
                          programSummary.trendDates.last.toLocal()),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // 4. CƠ THỂ — tappable pain self-report (capture-only).
                  _SectionHeader(
                    index: '02',
                    eyebrow: 'CƠ THỂ',
                    meta: (_painReports == null || _painReports!.isEmpty)
                        ? null
                        : '${_painReports!.length} VÙNG',
                    intro:
                        'Chạm vào vùng đang đau để Vika ghi lại. Cập nhật bất cứ lúc nào.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _painReports == null
                        ? const _PainPlaceholder()
                        : BodyPainReporter(
                            reports: _painReports!,
                            // Intended mapping: female silhouette ONLY for
                            // 'female'. 'male', 'other', and 'prefer_not_to_say'
                            // (and null/unknown) all render the male body map.
                            gender: _gender == 'female'
                                ? BodyGender.female
                                : BodyGender.male,
                            onReport: _reportPain,
                            onResolve: _resolvePain,
                          ),
                  ),
                  const SizedBox(height: 14),
                  // Safety disclaimer — pinned at the bottom of the section.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Đây là ghi chú của riêng bạn, không phải chẩn đoán. '
                      'Nếu cơn đau dữ dội hoặc kéo dài, bạn nên đi khám bác sĩ nhé.',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        letterSpacing: 0.1,
                        color: c.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 5. BÀI TẬP NỔI BẬT — 2-up visual ranking cards, wired to the
                  // real per-exercise ranker (SessionPersistence.rankedInsights).
                  _SectionHeader(
                    index: '03',
                    eyebrow: 'BÀI TẬP NỔI BẬT',
                    meta: _insightsMeta(),
                    intro: 'Những bài tiến nhanh nhất trong cả lộ trình.',
                  ),
                  const SizedBox(height: 16),
                  _buildInsightsSection(),
                  const SizedBox(height: 40),

                  // 6. CỘT MỐC — tiered milestone rail (real unlock state).
                  _SectionHeader(
                    index: '04',
                    eyebrow: 'CỘT MỐC',
                    meta: _milestoneMeta(),
                    intro:
                        'Những cột mốc bạn đã chạm tới. Càng đi xa, huy hiệu càng giá trị.',
                  ),
                  const SizedBox(height: 14),
                  _buildMilestonesSection(c),
                  const SizedBox(height: 40),

                  // 7. CHUỖI — weekly streak tier + 12-week activity strip. The
                  // trailing filled run IS the streak, so it lives here under
                  // the same "Chuỗi" the duration label names.
                  _SectionHeader(
                    index: '05',
                    eyebrow: 'CHUỖI',
                    intro: 'Số tuần bạn hoạt động liên tiếp.',
                  ),
                  const SizedBox(height: 14),
                  _buildStreakStripSection(c, streakWeeks),
                  const SizedBox(height: 40),

                  // Closer with back-to-top
                  _Closer(onBackToTop: _onStickyBarTap),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _StickyPillBar(
              visible: _showStickyBar,
              activeLabel: _activePeriodLabel(),
              onTap: _onStickyBarTap,
            ),
            _ScrollDownFab(
              visible: _showDownFab,
              bottomInset: widget.bottomPadding,
              onTap: _scrollToBottom,
            ),
          ],
        ),
      ),
    );
  }

  /// ĐIỂM FORM gauge eyebrow — a SHORT scope tag (the hero already carries the
  /// detailed week/phase stamp, so the gauge names its scope without echoing
  /// that long string verbatim).
  String _gaugeLabel() => switch (_period) {
        PeriodTab.week => 'TUẦN NÀY',
        PeriodTab.phase => 'GIAI ĐOẠN NÀY',
        PeriodTab.program => 'TOÀN CHƯƠNG TRÌNH',
      };

  /// Seconds → "Xh YY'" / "Xh" / "ZZ'" (e.g. 2h12', 13h, 45').
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return "$minutes'";
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : "${hours}h${rem.toString().padLeft(2, '0')}'";
  }

  // ── Section builders (real data + progressive reveal / guided empties) ──

  Widget _buildWeeklySection(VikaColors c) {
    final weekly = _weekly;
    if (weekly == null) {
      return const _BandPlaceholder(loading: true);
    }
    if (weekly.sessions == 0) {
      return const _BandPlaceholder(loading: false);
    }
    final stats = <WeeklyStat>[
      WeeklyStat(
        value: '${weekly.sessions}',
        label: 'Buổi tập',
        // Compact token — the trend chip carries the caret + sign.
        deltaNote: weekly.sessionsDelta != null
            ? _signedDelta(weekly.sessionsDelta!)
            : null,
        deltaPositive: (weekly.sessionsDelta ?? 0) >= 0,
      ),
      WeeklyStat(
        value: _formatDuration(weekly.totalSeconds),
        label: 'Thời gian',
      ),
      WeeklyStat(
        value: weekly.avgForm != null ? '${weekly.avgForm}' : '—',
        label: 'Form TB',
        deltaNote: weekly.avgFormDelta != null
            ? '${_signedDelta(weekly.avgFormDelta!)}đ'
            : null,
        deltaPositive: (weekly.avgFormDelta ?? 0) >= 0,
      ),
    ];
    return WeeklySummaryBand(stats: stats, kicker: 'TỔNG QUAN TUẦN NÀY');
  }

  /// CHUỖI section body: the "Streak Reel" — a warm-dark lit panel holding the
  /// glowing golden timeline ribbon (anchored at the first active week, capped
  /// at 12). The bright trailing run equals [streakWeeks] (shared active-week
  /// definition), so it reads honestly as the streak with no relabel. A
  /// brand-new user (no activity) gets the guided empty rather than dead cells.
  Widget _buildStreakStripSection(VikaColors c, int streakWeeks) {
    final bars = _streakWeekBars;
    if (bars == null) {
      return const _SectionEmpty(message: 'Đang tải chuỗi tuần…');
    }
    if (streakWeeks == 0 && !bars.any((active) => active)) {
      return const _SectionEmpty(
        message: 'Chưa có tuần nào hoạt động. Tập một buổi để bắt đầu '
            'chuỗi của bạn.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreakWeekStrip(weeks: bars, streakWeeks: streakWeeks),
    );
  }

  /// '{n} BÀI' once insights load with something to rank, else null (loading
  /// or guided-empty — a count would mislead).
  String? _insightsMeta() {
    if (_previewWithMock) return '${progressMockInsights.length} BÀI';
    final insights = _insights;
    if (insights == null || insights.isEmpty) return null;
    return '${insights.length} BÀI';
  }

  Widget _buildInsightsSection() {
    // Preview: show the mock ranking so the cards are visible during design
    // review. Real path stays below (used once the flag is flipped off).
    if (_previewWithMock) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ExerciseInsightGrid(insights: progressMockInsights),
      );
    }
    final insights = _insights;
    if (insights == null) {
      return const _SectionEmpty(message: 'Đang xếp hạng bài tập…');
    }
    if (insights.isEmpty) {
      return const _SectionEmpty(
        message: 'Chưa đủ dữ liệu để xếp hạng. Tập thêm vài buổi '
            'rồi quay lại nhé.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ExerciseInsightGrid(
        insights: [
          for (var i = 0; i < insights.length; i++)
            _insightToMock(insights[i], i),
        ],
      ),
    );
  }

  /// Maps one ranked headline → the card's `ExerciseInsightMock`. Display name
  /// resolves via the exercise catalog (falls back to the raw id). Form and
  /// fault tiers format their metric / stat differently; the per-session
  /// [RankInsightHeadline.series] drives the bar chart.
  ExerciseInsightMock _insightToMock(RankInsightHeadline h, int index) {
    final idx = (index + 1).toString().padLeft(2, '0');
    final name = lookupExerciseDefinition(h.exerciseId)?.name ?? h.exerciseId;

    if (h.tier == InsightTier.form) {
      final delta = h.toValue - h.fromValue;
      return ExerciseInsightMock(
        idx: idx,
        name: name,
        metric: 'Điểm form',
        directionHint: 'Càng cao càng tốt',
        improvement: 'Form tăng $delta',
        stat: '+$delta',
        lowerIsBetter: false,
        from: '${h.fromValue}',
        to: '${h.toValue}',
        chart: h.series,
      );
    }

    // Pain / generic fault tiers: fault rate as % of reps, falling = better.
    final delta = h.fromValue - h.toValue;
    return ExerciseInsightMock(
      idx: idx,
      name: name,
      metric: h.metricLabel ?? 'Lỗi',
      directionHint: 'Càng thấp càng tốt',
      improvement: 'Lỗi giảm $delta%',
      stat: '−$delta%',
      lowerIsBetter: true,
      from: '${h.fromValue}%',
      to: '${h.toValue}%',
      chart: h.series,
    );
  }

  /// '{n} ĐÃ MỞ' once milestones load and any rung is unlocked, else null.
  String? _milestoneMeta() {
    final milestones = _milestones;
    if (milestones == null) return null;
    final unlocked = milestones.where((m) => m.unlocked).length;
    return unlocked == 0 ? null : '$unlocked ĐÃ MỞ';
  }

  Widget _buildMilestonesSection(VikaColors c) {
    final milestones = _milestones;
    if (milestones == null) {
      return const _RailPlaceholder();
    }
    // Never empty — the rail always shows locked rungs as chase targets.
    return MilestoneRail(milestones: milestones);
  }

}

// ═══════════════════════════════════════════════════════════════
// GAUGE PLACEHOLDER — muted stand-in shown in the ScoreGaugeCard slot
// while the form summary loads, or when the selected period has no
// sessions yet. Premium Ivory tokens only.
// ═══════════════════════════════════════════════════════════════

class _GaugePlaceholder extends StatelessWidget {
  const _GaugePlaceholder({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    if (loading) {
      // Shimmer a stand-in gauge while the form summary loads.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: c.border),
        ),
        child: const Shimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonCircle(size: 128),
              SizedBox(height: 22),
              SkeletonBox(width: 150, height: 12),
              SizedBox(height: 10),
              SkeletonBox(width: 96, height: 12),
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Text(
        'Chưa có dữ liệu cho giai đoạn này',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.1,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAIN PLACEHOLDER — muted stand-in in the silhouette slot while the
// active pain reports load. Premium Ivory tokens only.
// ═══════════════════════════════════════════════════════════════

class _PainPlaceholder extends StatelessWidget {
  const _PainPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Dark stage that previews the loaded instrument, so loading → loaded
    // doesn't flash cream-to-dark. Inverted shimmer over a silhouette block.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.6, 1),
          colors: [c.bgInverse, c.bgInverseHi],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.28),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Shimmer(
        inverted: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonBox(width: 104, height: 208, radius: 52, inverted: true),
            SizedBox(height: 22),
            SkeletonBox(width: 150, height: 12, inverted: true),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WEEKLY BAND PLACEHOLDER — stand-in in the WeeklySummaryBand slot
// while it loads, or a guided empty when no session landed this week.
// ═══════════════════════════════════════════════════════════════

class _BandPlaceholder extends StatelessWidget {
  const _BandPlaceholder({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    if (loading) {
      // Shimmer three metric stand-ins inside the band's hairline frame.
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: const Shimmer(
          child: Row(
            children: [
              Expanded(child: _BandMetricSkeleton()),
              SizedBox(width: 18),
              Expanded(child: _BandMetricSkeleton()),
              SizedBox(width: 18),
              Expanded(child: _BandMetricSkeleton()),
            ],
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'Chưa có buổi nào tuần này. Tập một buổi để Vika '
            'tổng kết tuần cho bạn.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.5,
          letterSpacing: -0.1,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

/// A label + numeral pair used inside the loading weekly band.
class _BandMetricSkeleton extends StatelessWidget {
  const _BandMetricSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonBox(width: 52, height: 10),
        SizedBox(height: 12),
        SkeletonBox(width: 64, height: 24, radius: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RAIL PLACEHOLDER — muted stand-in in the PR rail slot while the
// records load.
// ═══════════════════════════════════════════════════════════════

class _RailPlaceholder extends StatelessWidget {
  const _RailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: const Shimmer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RailRungSkeleton(),
            _RailRungSkeleton(),
            _RailRungSkeleton(),
            _RailRungSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// A single milestone-rung stand-in: medallion + short label.
class _RailRungSkeleton extends StatelessWidget {
  const _RailRungSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonCircle(size: 46),
        SizedBox(height: 12),
        SkeletonBox(width: 44, height: 9),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION EMPTY — generic guided empty card for a section with no
// data yet. Quiet, never a fabricated number.
// ═══════════════════════════════════════════════════════════════

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.5,
          letterSpacing: -0.1,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER — eyebrow + accent bar + rule + meta + intro.
// Mirrors the Library section grammar so the two tabs read as one
// publication.
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    this.index,
    this.meta,
    this.intro,
  });

  final String eyebrow;

  /// Running chapter folio, e.g. '01'. A drop-folio italic numeral seated on a
  /// gold tick, echoing the insight-card ghost numerals and hero watermark —
  /// the editorial spine that threads the page into one bound volume. Null
  /// falls back to a plain gold accent bar.
  final String? index;
  final String? meta;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, intro == null ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (index != null)
            _ChapterFolio(index: index!)
          else
            Container(
              width: 5,
              height: 22,
              decoration: BoxDecoration(
                color: c.yellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Container(height: 1, color: c.border)),
                    if (meta != null) ...[
                      const SizedBox(width: 14),
                      Text(
                        meta!.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: c.inkFaint,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ],
                  ],
                ),
                if (intro != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    intro!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                      color: c.inkSoft,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Drop-folio chapter index — a tabular italic numeral over a short gold tick.
/// Sits where the old 5px accent bar was, giving each chapter a numbered plate.
class _ChapterFolio extends StatelessWidget {
  const _ChapterFolio({required this.index});
  final String index;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          index,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 25,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.6,
            height: 1.0,
            color: c.ink,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(1),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.45),
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCROLL-DOWN FAB — "Xuống cuối" pill that slides up from the
// bottom-right while heading down a long page, mirroring Hồ sơ.
// ═══════════════════════════════════════════════════════════════

class _ScrollDownFab extends StatelessWidget {
  const _ScrollDownFab({
    required this.visible,
    required this.bottomInset,
    required this.onTap,
  });

  final bool visible;
  final double bottomInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Positioned(
      right: 16,
      bottom: bottomInset + 16,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.4),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                height: 44,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: c.isDark ? 0.5 : 0.24),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xuống cuối',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.2,
                        color: c.invInk,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 15,
                        color: c.yellowInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STICKY PILL BAR — slides in after the user scrolls past the
// stage hero. Carries brand mark + active-period label.
// ═══════════════════════════════════════════════════════════════

class _StickyPillBar extends StatelessWidget {
  const _StickyPillBar({
    required this.visible,
    required this.activeLabel,
    required this.onTap,
  });

  final bool visible;
  final String activeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.4),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, topInset + 10, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.bg.withValues(alpha: 0.96),
                  c.bg.withValues(alpha: 0.78),
                  c.bg.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: c.bgRaised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.borderHi, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.36),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/branding/Logo.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'TIẾN BỘ',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: c.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Khoẻ hơn rõ rệt.',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.3,
                              color: c.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: c.ink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeLabel,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                              color: c.invInk,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 14,
                            color: c.invInkSoft,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CLOSER — editorial sign-off + back-to-top pill.
// ═══════════════════════════════════════════════════════════════

class _Closer extends StatelessWidget {
  const _Closer({required this.onBackToTop});
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: c.border)),
              const SizedBox(width: 14),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'VIKA · TIẾN BỘ',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: c.border)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tuần 04 sắp tới.',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Phase 2 mở khoá khi xong tuần 04. Đang gần rồi.',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.inkFaint,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BackToTopButton(onTap: onBackToTop),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackToTopButton extends StatefulWidget {
  const _BackToTopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<_BackToTopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
          height: 40,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lên đầu',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: c.invInk,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: c.yellowInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
