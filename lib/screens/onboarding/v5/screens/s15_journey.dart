import 'package:flutter/material.dart';

import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import '../../../../services/recommendation/models/plan.dart';
import '../../../../services/recommendation/recommendation_service.dart';
import '../../onboarding_data.dart';
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
  late final PageController _pageController;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _planFuture = _loadPlan();
    _pageController = PageController(viewportFraction: 0.78);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<PlanSnapshot?> _loadPlan() {
    final loader = widget.loadPlan;
    if (loader == null) return Future<PlanSnapshot?>.value(null);
    return loader();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _planFuture = _loadPlan();
    });
    try {
      await _planFuture;
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(widget.data);
    final r = V5Responsive.of(context);
    final veryCompact = r.isVeryShort;
    final bottomInset = r.viewPadding.bottom;
    return V5Screen(
      index: 16,
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
            final weekCards = PageView.builder(
              controller: _pageController,
              padEnds: false,
              itemCount: weeks.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    index == 0 ? 16 : 6,
                    8,
                    6,
                    16,
                  ),
                  child: V5FadeIn(
                    delay: Duration(milliseconds: index * 70),
                    slideY: 8,
                    child: loading
                        ? _WeekCardSkeleton(first: index == 0)
                        : _WeekCard(
                            week: weeks[index],
                            level: p.level,
                            first: index == 0,
                            loading: loading,
                          ),
                  ),
                );
              },
            );

            Widget content({required bool scrollable}) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: V5.gutter),
                    child: V5ScreenHeader(
                      eyebrow: 'Hành trình',
                      title: loading
                          ? 'Vika đang tạo\nlộ trình…'
                          : hasPlan
                              ? '${weeks.length} tuần\nphía trước.'
                              : 'Chưa tải được\nlộ trình.',
                      size: veryCompact
                          ? V5HeaderSize.medium
                          : V5HeaderSize.large,
                    ),
                  ),
                  SizedBox(height: r.pick(cozy: V5.space20, short: V5.space12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: V5.gutter),
                    child: _TimelineStrip(weeks: weeks),
                  ),
                  SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
                  if (scrollable)
                    SizedBox(height: 240, child: weekCards)
                  else
                    Expanded(child: weekCards),
                  if (!loading && !hasPlan)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          V5.gutter, 0, V5.gutter, 12),
                      child: _RetryPanel(
                        onRetry: _retry,
                        busy: _retrying,
                      ),
                    ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                r.chromeTopPadding,
                0,
                r.ctaBottomPadding,
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: veryCompact
                    ? SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: content(scrollable: true),
                      )
                    : content(scrollable: false),
              ),
            );
          },
        ),
        V5PillCTA(
          label: 'Bắt đầu hành trình',
          enabled: true,
          onTap: widget.onNext,
          bottom: 32 + bottomInset,
        ),
      ],
    );
  }

  List<_Week> _weeksFromPlan(Plan plan) {
    return plan.weeks.map((week) {
      final firstSession = week.sessions.isEmpty ? null : week.sessions.first;
      final slots = firstSession?.slots ?? const <SlotAssignment>[];
      final exercises = slots.take(3).map((slot) {
        return '${_exerciseLabel(slot.exerciseId)} · ${_formatVolume(slot.volume)}';
      }).toList();
      return _Week(
        number: week.weekNumber,
        theme: week.phaseName,
        headline: week.isDeloadWeek
            ? 'Giảm tải để cơ thể hồi phục'
            : week.weekNumber == 1
                ? 'Khởi đầu chắc chắn, đúng form ngay từ đầu'
                : 'Nâng dần độ khó cho tuần này',
        feeling: week.isDeloadWeek
            ? 'Tuần này nhẹ hơn để cơ thể được hồi phục trước khi đánh giá tiến độ.'
            : 'Bài tập giữ nguyên, chỉ tăng độ khó để bạn cảm thấy tiến bộ.',
        sessionCount: week.sessions.length,
        exercises:
            exercises.isEmpty ? ['Vika đang chuẩn bị các bài tập'] : exercises,
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
          headline: 'Đang lắp ghép các bài tập phù hợp',
          feeling: 'Vika đang xem xét hồ sơ, vùng bị đau và lịch tập của bạn.',
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

// ─────────────────────────────────────────────────────────────
// Timeline strip — refined progression visualization
// ─────────────────────────────────────────────────────────────

class _TimelineStrip extends StatelessWidget {
  const _TimelineStrip({required this.weeks});

  final List<_Week> weeks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: weeks.asMap().entries.map((entry) {
          final i = entry.key;
          final first = i == 0;
          final last = i == weeks.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: last ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The track + dot.
                  SizedBox(
                    height: 16,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: first
                                ? V5.yellow
                                : V5.yellow.withValues(
                                    alpha: 0.18 +
                                        ((weeks.length - i) / weeks.length) *
                                            0.12,
                                  ),
                            borderRadius: BorderRadius.circular(V5.radiusXs),
                          ),
                        ),
                        if (first)
                          Positioned(
                            right: -3,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: V5.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(color: V5.bg, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: V5.yellow.withValues(alpha: 0.6),
                                    blurRadius: 7,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'T${i + 1}',
                    style: V5
                        .eyebrow(
                          context,
                          color: first ? V5.ink : V5.inkFaint,
                        )
                        .copyWith(letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Retry panel — for failed plan load
// ─────────────────────────────────────────────────────────────

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({
    required this.onRetry,
    this.busy = false,
  });

  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: V5.yellow.withValues(alpha: 0.10),
        border: Border.all(color: V5.yellow.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(V5.radiusMd),
        boxShadow: V5.elevation1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: V5.yellow.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: V5.yellowDeep,
            ),
          ),
          const SizedBox(width: V5.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lộ trình chưa được lưu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.titleSm(context, color: V5.ink),
                ),
                const SizedBox(height: V5.space2),
                Text(
                  'Bạn vẫn xem được lộ trình, nhưng sẽ không được lưu lại.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V5.caption(context, color: V5.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: V5.space8),
          GestureDetector(
            onTap: busy ? null : onRetry,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: busy ? V5.yellow.withValues(alpha: 0.4) : V5.yellow,
                borderRadius: BorderRadius.circular(V5.radiusFull),
                boxShadow: busy ? null : V5.yellowGlow(0.16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        valueColor: AlwaysStoppedAnimation<Color>(V5.yellowInk),
                      ),
                    ),
                    const SizedBox(width: V5.space8),
                  ] else ...[
                    const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: V5.yellowInk,
                    ),
                    const SizedBox(width: V5.space6),
                  ],
                  Text(
                    busy ? 'Đang lưu…' : 'Thử lại',
                    style: V5
                        .eyebrow(context, color: V5.yellowInk)
                        .copyWith(letterSpacing: 1.0),
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

// ─────────────────────────────────────────────────────────────
// Week card — first week is dark hero, others are cream
// ─────────────────────────────────────────────────────────────

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
    final dark = first;
    final fg = dark ? V5.invInk : V5.ink;
    final fgSoft = dark ? V5.invInkSoft : V5.inkSoft;
    // LayoutBuilder so density tracks the card's actual height — not the
    // screen's. The retry panel can squeeze the PageView, and the previous
    // screen-height heuristic missed that and overflowed by 17px.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final dense = cardHeight < 360;
        final veryDense = cardHeight < 300;
        final visibleExercises =
            week.exercises.take(veryDense ? 1 : (dense ? 2 : 3));
        return Container(
          width: 280,
          padding: EdgeInsets.fromLTRB(
            16,
            dense ? 14 : 18,
            16,
            dense ? 14 : 16,
          ),
          decoration: BoxDecoration(
            gradient: dark ? V5.heroGradient : null,
            color: dark ? null : V5.surface,
            borderRadius: BorderRadius.circular(V5.radiusLg),
            border: Border.all(color: dark ? V5.heroBorder : V5.border),
            boxShadow: dark ? V5.elevation2 : V5.elevation1,
          ),
          child: Stack(
            children: [
              if (dark)
                Positioned(
                  top: -80,
                  right: -70,
                  child: V5AmbientGlow(
                    size: const Size(220, 220),
                    opacity: 0.18,
                    color: V5.yellow,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Single-element week badge — just the number, big and
                      // confident. No more "TUẦN" stacked above a digit inside a
                      // tiny circle (it overflowed at week 10+ and looked cramped).
                      Container(
                        width: dense ? 40 : 46,
                        height: dense ? 40 : 46,
                        decoration: BoxDecoration(
                          color: dark ? V5.yellow : V5.yellowSoft,
                          shape: BoxShape.circle,
                          border: dark
                              ? null
                              : Border.all(
                                  color: V5.yellow.withValues(alpha: 0.32),
                                ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${week.number}',
                          style: V5.text(
                            context,
                            size: dense ? 17 : 19,
                            weight: FontWeight.w800,
                            color: dark ? V5.yellowInk : V5.yellowDeep,
                            letterSpacing: -0.6,
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(width: dense ? V5.space10 : V5.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TUẦN ${week.number}',
                              style: V5
                                  .eyebrow(context, color: fgSoft)
                                  .copyWith(letterSpacing: 1.4),
                            ),
                            const SizedBox(height: V5.space2),
                            Text(
                              week.theme,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.titleSm(context, color: fg),
                            ),
                          ],
                        ),
                      ),
                      if (dark)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: V5.yellow,
                            borderRadius: BorderRadius.circular(V5.radiusFull),
                          ),
                          child: Text(
                            loading ? 'ĐANG TẠO' : 'BẮT ĐẦU',
                            style: V5
                                .eyebrow(context, color: V5.yellowInk)
                                .copyWith(letterSpacing: 1.0),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: dense ? V5.space10 : V5.space14),
                  Text(
                    week.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        V5.titleSm(context, color: fg).copyWith(height: 1.22),
                  ),
                  if (!dense) ...[
                    const SizedBox(height: V5.space6),
                    Text(
                      week.feeling,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V5.bodySm(context, color: fgSoft),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: dense ? V5.space8 : V5.space14),
                    child: V5Divider(dark: dark),
                  ),
                  Row(
                    children: [
                      Text(
                        'BÀI TẬP TUẦN NÀY',
                        style: V5.eyebrow(context, color: fgSoft),
                      ),
                      const Spacer(),
                      Text(
                        week.tag,
                        style: V5
                            .eyebrow(
                              context,
                              color: dark ? V5.yellow : V5.yellowDeep,
                            )
                            .copyWith(letterSpacing: 1.0),
                      ),
                    ],
                  ),
                  SizedBox(height: dense ? 6 : 8),
                  // Expanded so the bullet stack absorbs extra height when the
                  // card is roomy AND shrinks (clipping with overflow:clip if
                  // needed) when squeezed by the retry panel above.
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final ex in visibleExercises)
                            Container(
                              margin: EdgeInsets.only(bottom: dense ? 4 : 5),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: dense ? 6 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: dark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : V5.bgSoft,
                                borderRadius:
                                    BorderRadius.circular(V5.radiusSm),
                                border: dark
                                    ? Border.all(color: V5.heroBorderHi)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: V5.yellow.withValues(alpha: 0.18),
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
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ex,
                                      maxLines: dense ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: V5.text(
                                        context,
                                        size: dense ? 10.8 : 11.5,
                                        weight: FontWeight.w700,
                                        color: fg,
                                        letterSpacing: -0.1,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  V5Divider(dark: dark),
                  SizedBox(height: dense ? 8 : 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: dark ? V5.yellow : V5.yellowDeep,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${week.sessionCount} buổi',
                        style: V5
                            .bodySm(context, color: fg)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '~${(week.sessionCount * minutes / 60).toStringAsFixed(1)}h',
                        style: V5.caption(context, color: fgSoft),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loading skeleton — shimmering stand-in week card (V5-local, so the
// onboarding stays self-contained from the main-app theme). Mirrors the
// real _WeekCard so the swap to the loaded plan doesn't jump.
// ─────────────────────────────────────────────────────────────

class _WeekCardSkeleton extends StatelessWidget {
  const _WeekCardSkeleton({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context) {
    final dark = first;
    final divider = dark ? V5.heroBorderHi : V5.border;
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: dark ? V5.heroGradient : null,
        color: dark ? null : V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusLg),
        border: Border.all(color: dark ? V5.heroBorder : V5.border),
        boxShadow: dark ? V5.elevation2 : V5.elevation1,
      ),
      child: _V5Shimmer(
        dark: dark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge + title
            Row(
              children: [
                _V5SkeletonCircle(size: 46, dark: dark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _V5SkeletonBox(width: 70, height: 9, dark: dark),
                      const SizedBox(height: 8),
                      _V5SkeletonBox(width: 120, height: 14, dark: dark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Headline — two lines
            _V5SkeletonBox(height: 13, dark: dark),
            const SizedBox(height: 7),
            _V5SkeletonBox(width: 150, height: 13, dark: dark),
            const SizedBox(height: 14),
            Container(height: 1, color: divider),
            const SizedBox(height: 14),
            // "BÀI TẬP TUẦN NÀY" rail header
            Row(
              children: [
                _V5SkeletonBox(width: 110, height: 9, dark: dark),
                const Spacer(),
                _V5SkeletonBox(width: 48, height: 9, dark: dark),
              ],
            ),
            const SizedBox(height: 10),
            // Exercise pills
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(height: 5),
                      _V5SkeletonBox(
                        height: 32,
                        radius: V5.radiusSm,
                        dark: dark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: 1, color: divider),
            const SizedBox(height: 12),
            // Footer — sessions + duration
            Row(
              children: [
                _V5SkeletonBox(width: 58, height: 12, dark: dark),
                const Spacer(),
                _V5SkeletonBox(width: 32, height: 12, dark: dark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Base + highlight tones for the V5 onboarding skeletons.
({Color base, Color highlight}) _v5Tones(bool dark) {
  if (dark) {
    return (
      base: Color.lerp(V5.ink, Colors.white, 0.16)!,
      highlight: Color.lerp(V5.ink, Colors.white, 0.30)!,
    );
  }
  return (
    base: Color.lerp(V5.surface, V5.ink, 0.09)!,
    highlight: Color.lerp(V5.surface, V5.ink, 0.035)!,
  );
}

class _V5SkeletonBox extends StatelessWidget {
  const _V5SkeletonBox({
    this.width,
    this.height = 12,
    this.radius = 7,
    this.dark = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _v5Tones(dark).base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _V5SkeletonCircle extends StatelessWidget {
  const _V5SkeletonCircle({required this.size, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _v5Tones(dark).base,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Sweeps a soft highlight band across a subtree of [_V5SkeletonBox]es on a
/// gentle ~1.5s loop. Honors the platform reduce-motion setting.
class _V5Shimmer extends StatefulWidget {
  const _V5Shimmer({required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  State<_V5Shimmer> createState() => _V5ShimmerState();
}

class _V5ShimmerState extends State<_V5Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final tones = _v5Tones(widget.dark);
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final slide = -1.0 + _ctrl.value * 3.0;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [tones.base, tones.highlight, tones.base],
            stops: const [0.35, 0.5, 0.65],
            transform: GradientTranslation(bounds.width * slide),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Horizontal translate transform for the shimmer band.
class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
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
  if (definition != null) return definition.displayName;
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
