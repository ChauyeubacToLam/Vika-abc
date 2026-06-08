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
import '../services/recommendation/recommendation_service.dart';
import '../services/session_persistence.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/progress/body_heat_map.dart';
import '../widgets/progress/milestone_rail.dart';
import '../widgets/progress/period_tabs.dart';
import '../widgets/progress/progress_stage_hero.dart';
import '../widgets/progress/progress_streak_card.dart';
import '../widgets/progress/exercise_insight_grid.dart';
import '../widgets/progress/score_gauge_card.dart';
import '../widgets/progress/score_trend_chart.dart';
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

  /// Real ĐIỂM FORM / ĐƯỜNG TIẾN BỘ summary for the active period.
  /// Null = loading (show placeholder); a loaded record with `to == null`
  /// = no sessions in this period (empty state).
  ({
    int? to,
    int? from,
    int? delta,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  })? _formSummary;

  /// Real BÀI TẬP NỔI BẬT ranked insights for the active period, best-first.
  /// Null = loading; empty = nothing qualified yet (guided empty shown).
  List<RankInsightHeadline>? _insights;

  /// Real hero phase/week label, derived from the active plan snapshot
  /// (the SAME source the Plan tab uses). Null until resolved; once resolved
  /// it stays null when there's no active plan (guided-empty label shown).
  String? _phaseLabel;
  bool _planResolved = false;

  /// Real TUẦN NÀY MỘT NHÌN weekly summary over a rolling 7-day window.
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

  /// Real CHUỖI LIÊN TIẾP daily completion bars (last 14 days, oldest-first).
  /// Null = loading.
  List<bool>? _streakBars;

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
    unawaited(_loadFormSummary(_period));
    unawaited(_loadInsights(_period));
    unawaited(_loadPhaseLabel());
    unawaited(_loadWeekly());
    unawaited(_loadMilestones());
    unawaited(_loadStreakBars());
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
    unawaited(_loadFormSummary(_period));
    unawaited(_loadInsights(_period));
    unawaited(_loadPhaseLabel());
    unawaited(_loadWeekly());
    unawaited(_loadMilestones());
    unawaited(_loadStreakBars());
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

  /// Loads the real form summary for [period]. Stale responses (the user
  /// switched period before this resolved) are discarded.
  Future<void> _loadFormSummary(PeriodTab period) async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted || period != _period) return;
      setState(() => _formSummary = _mockFormSummary(period));
      return;
    }
    final summary = await _sessions.progressFormSummary(period);
    if (!mounted || period != _period) return;
    setState(() => _formSummary = summary);
  }

  /// Loads the real ranked insights for [period]. Stale responses (the user
  /// switched period before this resolved) are discarded.
  Future<void> _loadInsights(PeriodTab period) async {
    // Preview renders mock directly in _buildInsightsSection; skip the fetch.
    if (_previewWithMock) return;
    final insights = await _sessions.rankedInsights(period);
    if (!mounted || period != _period) return;
    setState(() => _insights = insights);
  }

  /// Loads the hero phase/week label from the active plan snapshot — the SAME
  /// source the Plan tab uses (RecommendationService). Stays null (guided
  /// empty) when there is no active plan.
  Future<void> _loadPhaseLabel() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() {
        _planResolved = true;
        _phaseLabel = 'PHASE 2 · 18 / 28 BUỔI · TUẦN 4 / 7';
      });
      return;
    }
    final snapshot =
        await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();
    if (!mounted) return;
    setState(() {
      _planResolved = true;
      _phaseLabel = _derivePhaseLabel(snapshot);
    });
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

  Future<void> _loadWeekly() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _weekly = _mockWeekly);
      return;
    }
    final weekly = await _sessions.weeklySummary();
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

  Future<void> _loadStreakBars() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _streakBars = progressMockStreakBars);
      return;
    }
    final bars = await _sessions.streakBars();
    if (!mounted) return;
    setState(() => _streakBars = bars);
  }

  // ── Mock preview builders (only used while [_previewWithMock] is on) ──

  /// Mock ĐIỂM FORM gauge + trend for [period], built from progress_mock.
  ({
    int? to,
    int? from,
    int? delta,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  }) _mockFormSummary(PeriodTab period) {
    final key = switch (period) {
      PeriodTab.week => 'week',
      PeriodTab.month => 'month',
      PeriodTab.program => 'program',
    };
    final h = progressMockHeadline[key]!;
    final trend = progressMockScoreTrend[key]!;
    final now = DateTime.now();
    return (
      to: h.to,
      from: h.from,
      delta: h.from != null ? h.to - h.from! : null,
      trend: trend,
      trendDates: [
        for (var i = 0; i < trend.length; i++)
          now.subtract(Duration(days: (trend.length - 1 - i) * 2)),
      ],
      fact: h.coach,
    );
  }

  /// Mock TUẦN NÀY MỘT NHÌN weekly summary (5 buổi · 2h12' · form 74, +deltas).
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
      // Drop to the loading placeholder so the gauge re-mounts and
      // re-animates when the new period's data arrives.
      _formSummary = null;
      _insights = null;
    });
    unawaited(_loadFormSummary(period));
    unawaited(_loadInsights(period));
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

  // Honest period date-stamp anchored to today (no fabricated fixed dates).
  String _weekLabel() {
    final now = DateTime.now();
    String d(DateTime t) => '${t.day} / ${t.month}';
    return switch (_period) {
      PeriodTab.week =>
        'TUẦN NÀY · ${d(now.subtract(const Duration(days: 6)))} – ${d(now)}',
      PeriodTab.month =>
        'TỪ ${d(now.subtract(const Duration(days: 30)))} · 30 NGÀY QUA',
      PeriodTab.program => 'CẢ LỘ TRÌNH · TÍNH ĐẾN ${d(now)}',
    };
  }

  String _activePeriodLabel() => switch (_period) {
        PeriodTab.week => 'Tuần',
        PeriodTab.month => 'Tháng',
        PeriodTab.program => 'Cả lộ trình',
      };

  /// Signed delta string: '+5', '0', '-3'. The minus is carried by the
  /// number itself; only non-negatives get a leading '+'.
  String _signedDelta(int d) => '${d >= 0 ? '+' : ''}$d';

  /// Trend section-header meta, e.g. '+5 ĐIỂM' / '-3 ĐIỂM'. Empty trend
  /// yields '' (defensive — the trend section is skipped when empty).
  String _trendMeta(List<int> trend) {
    if (trend.isEmpty) return '';
    return '${_signedDelta(trend.last - trend.first)} ĐIỂM';
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Real ĐIỂM FORM / ĐƯỜNG TIẾN BỘ data; only the coach copy stays static.
    final formSummary = _formSummary;
    final loadingForm = formSummary == null;
    final hasForm = formSummary != null && formSummary.to != null;
    // The trend line only reads as real with 3+ sessions (progressive reveal).
    final hasTrend = formSummary != null && formSummary.trend.length >= 3;
    final profile = _profile ?? widget.userProfile;
    final userInitial = profile?.initial ?? 'N';
    final streakDays =
        _previewWithMock ? progressMockStreakDays : (profile?.streakDays ?? 0);
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
                    weekLabel: _weekLabel(),
                  ),
                  const SizedBox(height: 24),

                  // 1. ĐIỂM FORM — score gauge card (wired to real data).
                  // Renders at >= 1 session (to != null); from/delta stay null
                  // until the 3-session baseline, and the card shows the score
                  // alone with a quiet hint.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: hasForm
                        ? ScoreGaugeCard(
                            data: HeadlineForPeriod(
                              to: formSummary.to!,
                              from: formSummary.from,
                              delta: formSummary.delta != null
                                  ? _signedDelta(formSummary.delta!)
                                  : null,
                              // Real period label (1e); no mock import.
                              label: _gaugeLabel(),
                              // A factual trajectory one-liner (NOT coaching,
                              // NOT the session coach), derived from the real
                              // trend + delta in progressFormSummary.
                              coach: formSummary.fact,
                            ),
                          )
                        : _GaugePlaceholder(loading: loadingForm),
                  ),
                  const SizedBox(height: 40),

                  // 2. TUẦN NÀY MỘT NHÌN — weekly summary band (real data).
                  _buildWeeklySection(c, streakDays),
                  const SizedBox(height: 40),

                  // 3. ĐƯỜNG TIẾN BỘ — score trend chart (wired to real data).
                  // Gated on 3+ sessions (a trend needs enough points to read).
                  if (hasTrend) ...[
                    _SectionHeader(
                      eyebrow: 'ĐƯỜNG TIẾN BỘ',
                      meta: _trendMeta(formSummary.trend),
                      intro:
                          'Mỗi điểm tô đậm là một buổi. Đường đi lên là form đã ổn.',
                    ),
                    const SizedBox(height: 14),
                    // Axis labels are real dates from the session timestamps
                    // backing the trend (start / mid / end), bucketed local.
                    ScoreTrendChart(
                      points: formSummary.trend,
                      startLabel: _fmtDayMonth(
                          formSummary.trendDates.first.toLocal()),
                      midLabel: _fmtDayMonth(formSummary
                          .trendDates[formSummary.trendDates.length ~/ 2]
                          .toLocal()),
                      endLabel: _fmtDayMonth(
                          formSummary.trendDates.last.toLocal()),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // 4. CƠ THỂ — tappable pain self-report (capture-only).
                  _SectionHeader(
                    eyebrow: 'CƠ THỂ',
                    meta: (_painReports == null || _painReports!.isEmpty)
                        ? null
                        : '${_painReports!.length} VÙNG',
                    intro:
                        'Chạm vào vùng đang đau để Vika ghi lại. Bạn cập nhật bất cứ lúc nào.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _painReports == null
                        ? const _PainPlaceholder()
                        : BodyPainReporter(
                            reports: _painReports!,
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
                    eyebrow: 'BÀI TẬP NỔI BẬT',
                    meta: _insightsMeta(),
                    intro: 'Những bài tiến nhanh nhất trong giai đoạn.',
                  ),
                  const SizedBox(height: 16),
                  _buildInsightsSection(),
                  const SizedBox(height: 40),

                  // 6. CỘT MỐC — tiered milestone rail (real unlock state).
                  _SectionHeader(
                    eyebrow: 'CỘT MỐC',
                    meta: _milestoneMeta(),
                    intro:
                        'Những cột mốc bạn đã chạm tới. Càng đi xa, huy hiệu càng giá trị.',
                  ),
                  const SizedBox(height: 14),
                  _buildMilestonesSection(c),
                  const SizedBox(height: 40),

                  // 7. CHUỖI LIÊN TIẾP — streak card (real completion history;
                  // streak day count is already live).
                  _SectionHeader(
                    eyebrow: 'CHUỖI LIÊN TIẾP',
                    meta: '$streakDays NGÀY',
                    intro:
                        'Mỗi cột là một ngày. Cột vàng đậm là buổi đã ghi nhận.',
                  ),
                  const SizedBox(height: 14),
                  _buildStreakSection(c, streakDays),
                  const SizedBox(height: 40),

                  // 8. Closer with back-to-top
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

  /// ĐIỂM FORM gauge eyebrow label, derived from the active period (1e).
  String _gaugeLabel() => switch (_period) {
        PeriodTab.week => '7 NGÀY GẦN NHẤT',
        PeriodTab.month => '30 NGÀY GẦN NHẤT',
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

  Widget _buildWeeklySection(VikaColors c, int streakDays) {
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
      WeeklyStat(
        value: '$streakDays',
        label: 'Ngày liên tiếp',
      ),
    ];
    return WeeklySummaryBand(stats: stats, kicker: 'TUẦN NÀY MỘT NHÌN');
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

  Widget _buildStreakSection(VikaColors c, int streakDays) {
    final bars = _streakBars;
    if (bars == null) {
      return const _SectionEmpty(message: 'Đang tải chuỗi ngày tập…');
    }
    final completedRecently = bars.where((b) => b).length;
    if (streakDays == 0 && completedRecently == 0) {
      return const _SectionEmpty(
        message: 'Chưa có buổi nào trong 14 ngày qua. Tập một buổi '
            'để bắt đầu chuỗi của bạn.',
      );
    }
    // Last 7 of the 14 bars = this week's completed days.
    final last7 = bars.length >= 7 ? bars.sublist(bars.length - 7) : bars;
    final weeklyCompleted = last7.where((b) => b).length;
    final next = SessionPersistence.nextStreakMilestone(streakDays);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ProgressStreakCard(
        days: streakDays,
        bars: bars,
        summary: 'Đã tập $completedRecently ngày trong 14 ngày qua.',
        weeklyCompleted: weeklyCompleted,
        weeklyTotal: 7,
        // No further milestone → pass the current count so the footer hides.
        nextMilestone: next ?? streakDays,
      ),
    );
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
        loading
            ? 'Đang tải điểm form…'
            : 'Chưa có dữ liệu cho giai đoạn này',
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
    // doesn't flash cream-to-dark.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 88, horizontal: 24),
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
      child: Text(
        'Đang tải vùng cơ thể…',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.1,
          color: c.invInkSoft,
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
        loading
            ? 'Đang tải tổng kết tuần…'
            : 'Chưa có buổi nào tuần này. Tập một buổi để Vika '
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
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Text(
        'Đang tải cột mốc…',
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
    this.meta,
    this.intro,
  });

  final String eyebrow;
  final String? meta;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, intro == null ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
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
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Text(
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
            ),
          ],
        ],
      ),
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
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.36),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'V',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1,
                          color: c.yellowInk,
                          height: 1,
                        ),
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
