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
import 'package:flutter/services.dart';

import '../data/plan_mock.dart'
    show phaseWeeksMock, planTotalCompleted, planTotalSessions;
import '../data/progress_mock.dart';
import '../services/session_persistence.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/progress/body_heat_map.dart';
import '../widgets/progress/period_tabs.dart';
import '../widgets/progress/personal_records_rail.dart';
import '../widgets/progress/progress_stage_hero.dart';
import '../widgets/progress/progress_streak_card.dart';
import '../widgets/progress/ranked_insights.dart';
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
  PeriodTab _period = PeriodTab.program;
  final ScrollController _scrollController = ScrollController();
  bool _showStickyBar = false;
  AppUserProfile? _profile;
  bool _loadingProfile = false;
  bool _profileReloadQueued = false;

  /// Real ĐIỂM FORM / ĐƯỜNG TIẾN BỘ summary for the active period.
  /// Null = loading (show placeholder); a loaded record with `to == null`
  /// = no sessions in this period (empty state).
  ({int? to, int? from, int? delta, List<int> trend})? _formSummary;

  /// Scroll offset past which the sticky pill bar fades in.
  static const double _stickyBarThreshold = 240;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _profile = widget.userProfile;
    widget.refreshListenable?.addListener(_handleRefreshNudge);
    _scrollController.addListener(_onScroll);
    unawaited(_loadFormSummary(_period));
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
    final summary = await _sessions.progressFormSummary(period);
    if (!mounted || period != _period) return;
    setState(() => _formSummary = summary);
  }

  void _onPeriodChanged(PeriodTab period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      // Drop to the loading placeholder so the gauge re-mounts and
      // re-animates when the new period's data arrives.
      _formSummary = null;
    });
    unawaited(_loadFormSummary(period));
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _stickyBarThreshold;
    if (shouldShow != _showStickyBar) {
      setState(() => _showStickyBar = shouldShow);
    }
  }

  void _onStickyBarTap() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  String _periodKey() => switch (_period) {
        PeriodTab.week => 'week',
        PeriodTab.month => 'month',
        PeriodTab.program => 'program',
      };

  String _weekLabel() => switch (_period) {
        PeriodTab.week => 'TUẦN NÀY · 18 - 24 / 5',
        PeriodTab.month => 'TỪ 21 / 4 · 30 NGÀY QUA',
        PeriodTab.program => 'TỪ 21 / 4 · CẢ LỘ TRÌNH · 4 TUẦN',
      };

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
    final periodKey = _periodKey();
    // Real ĐIỂM FORM / ĐƯỜNG TIẾN BỘ data; label + coach copy stay static.
    final formSummary = _formSummary;
    final loadingForm = formSummary == null;
    final hasForm = formSummary != null && formSummary.to != null;
    final mockHeadline = progressMockHeadline[periodKey]!;
    final trendAxis = progressMockTrendAxis[periodKey]!;
    final totalDone = planTotalCompleted(phaseWeeksMock);
    final totalSessions = planTotalSessions(phaseWeeksMock);
    final phaseLabel =
        'PHASE 1 · $totalDone / $totalSessions BUỔI · TUẦN 3 / 7';
    final profile = _profile ?? widget.userProfile;
    final userInitial = profile?.initial ?? 'N';
    final streakDays = profile?.streakDays ?? progressMockStreakDays;
    final summary = _summaryWithStreak(
      progressMockSummaries[periodKey]!,
      streakDays,
    );

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: hasForm
                        ? ScoreGaugeCard(
                            data: HeadlineForPeriod(
                              to: formSummary.to!,
                              from: formSummary.from!,
                              delta: _signedDelta(formSummary.delta ?? 0),
                              // Keep the existing per-period label + coach copy.
                              label: mockHeadline.label,
                              // TODO(coach): wire dynamic coach copy. Static
                              // stub for now — do not compute coaching text.
                              coach: mockHeadline.coach,
                            ),
                          )
                        : _GaugePlaceholder(loading: loadingForm),
                  ),
                  const SizedBox(height: 40),

                  // 2. TUẦN NÀY MỘT NHÌN — weekly summary band
                  // TODO(wiring): still mock — wire to real session data.
                  WeeklySummaryBand(
                    stats: summary,
                    kicker: 'TUẦN NÀY MỘT NHÌN',
                  ),
                  const SizedBox(height: 40),

                  // 3. ĐƯỜNG TIẾN BỘ — score trend chart (wired to real data).
                  // Skipped entirely when the period has no sessions.
                  if (hasForm) ...[
                    _SectionHeader(
                      eyebrow: 'ĐƯỜNG TIẾN BỘ',
                      meta: _trendMeta(formSummary.trend),
                      intro:
                          'Mỗi điểm tô đậm là một buổi. Đường đi lên là form đã ổn.',
                    ),
                    const SizedBox(height: 14),
                    // TODO(wiring): axis labels are still static per period;
                    // derive real dates from session timestamps later.
                    ScoreTrendChart(
                      points: formSummary.trend,
                      startLabel: trendAxis.$1,
                      midLabel: trendAxis.$2,
                      endLabel: trendAxis.$3,
                    ),
                    const SizedBox(height: 40),
                  ],

                  // 4. CƠ THỂ KHOẺ LÊN — body heat map
                  // TODO(wiring): still mock — wire to real per-region data.
                  _SectionHeader(
                    eyebrow: 'CƠ THỂ KHOẺ LÊN',
                    meta: '${progressMockBodyAreas.length} VÙNG',
                    intro:
                        'Vika theo dõi từng vùng cơ. Vùng nào sáng vàng là vùng đang lên rõ nhất.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const BodyHeatMap(
                      areas: progressMockBodyAreas,
                      gender: BodyGender.male,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 5. BÀI TẬP NỔI BẬT — ranked insights
                  // TODO(wiring): still mock — wire to real per-exercise data.
                  _SectionHeader(
                    eyebrow: 'BÀI TẬP NỔI BẬT',
                    meta: '${progressMockInsights.length} BÀI · 3 ĐẦU TIÊN',
                    intro:
                        'Ba bài tiến nhanh nhất trong giai đoạn. Chạm để xem hết.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RankedInsights(ranked: progressMockInsights),
                  ),
                  const SizedBox(height: 40),

                  // 6. KỶ LỤC CÁ NHÂN — PR rail
                  // TODO(wiring): still mock — wire to real personal records.
                  _SectionHeader(
                    eyebrow: 'KỶ LỤC CÁ NHÂN',
                    meta: '${progressMockRecords.length} KỶ LỤC',
                    intro:
                        'Những đỉnh mới Vika ghi lại trong giai đoạn. Đây là thứ đáng chụp lại.',
                  ),
                  const SizedBox(height: 14),
                  const PersonalRecordsRail(
                    records: progressMockRecords,
                  ),
                  const SizedBox(height: 40),

                  // 7. CHUỖI LIÊN TIẾP — streak card
                  // TODO(wiring): bars/summary still mock — wire to real
                  // completion history (streak day count is already live).
                  _SectionHeader(
                    eyebrow: 'CHUỖI LIÊN TIẾP',
                    meta: '$streakDays NGÀY',
                    intro:
                        'Mỗi cột là một ngày. Cột vàng đậm là buổi đã ghi nhận.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ProgressStreakCard(
                      days: streakDays,
                      bars: progressMockStreakBars,
                      summary: progressMockStreakSummary,
                      nextMilestone: progressMockNextMilestone,
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }

  List<WeeklyStat> _summaryWithStreak(
    List<WeeklyStat> stats,
    int streakDays,
  ) {
    return [
      for (final stat in stats)
        stat.label == 'Ngày liên tiếp'
            ? WeeklyStat(value: '$streakDays', label: stat.label)
            : stat,
    ];
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
