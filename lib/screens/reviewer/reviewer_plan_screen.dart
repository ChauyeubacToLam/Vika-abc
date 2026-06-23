import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vika/models/exercise_lookup.dart';
import '../../services/recommendation/models/plan.dart';
import '../../services/recommendation/recommendation_service.dart';
import '../onboarding/v5/v5_primitives.dart';
import '../onboarding/v5/v5_theme.dart';

/// Read-only plan reveal shown to an Apple reviewer after they enter the demo
/// access code on S13, before they land on the seeded home.
///
/// It ONLY reads the seeded user's active plan via
/// [RecommendationService.fetchLatestActivePlanSnapshotForCurrentUser] — it
/// never generates, persists, or mutates anything, and never touches the
/// seeded profile. Chrome is in ENGLISH (audience: the reviewer); exercise
/// and phase names come straight from the plan data and stay Vietnamese.
///
/// Design: "The Arc". A full-bleed dark stage hero (matching the app's primary
/// tabs) opens with an italic display thesis and a phase-arc ribbon; below, the
/// weeks read as one editorial journey — grouped under numbered phase headers
/// and threaded by a per-phase spine, with week one as a dark hero card.
class ReviewerPlanScreen extends StatefulWidget {
  const ReviewerPlanScreen({super.key, this.planFutureOverride});

  /// Test-only seam to render the screen without hitting Supabase. Production
  /// always reads the seeded active plan via [RecommendationService].
  @visibleForTesting
  final Future<PlanSnapshot?> Function()? planFutureOverride;

  @override
  State<ReviewerPlanScreen> createState() => _ReviewerPlanScreenState();
}

class _ReviewerPlanScreenState extends State<ReviewerPlanScreen> {
  late final Future<PlanSnapshot?> _planFuture;

  @override
  void initState() {
    super.initState();
    // READ ONLY — fetch the seeded active plan. No generate, no persist.
    _planFuture = (widget.planFutureOverride ??
        RecommendationService().fetchLatestActivePlanSnapshotForCurrentUser)();
  }

  void _enterApp() {
    // Land on the seeded MainShell. The fresh AppEntryGate sees a signed-in,
    // onboarding-complete session and routes straight to home.
    Navigator.of(context).pushReplacementNamed(
      '/',
      arguments: const {'onboardingComplete': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Material ancestor: gives every Text a proper DefaultTextStyle. Without
      // it a bare ColoredBox/Stack route paints the yellow "missing Material"
      // debug underlines. (V5 onboarding screens get this from the navigator's
      // shared Scaffold; this standalone route must supply its own.)
      child: Material(
        color: V5.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<PlanSnapshot?>(
                future: _planFuture,
                builder: (context, snap) {
                  final loading =
                      snap.connectionState == ConnectionState.waiting;
                  return _ScrollBody(
                    loading: loading,
                    progress: _deriveProgress(snap.data),
                    bottomInset: bottomInset,
                  );
                },
              ),
            ),
            V5PillCTA(
              label: 'Enter app',
              enabled: true,
              onTap: _enterApp,
              bottom: 28 + bottomInset,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollBody extends StatelessWidget {
  const _ScrollBody({
    required this.loading,
    required this.progress,
    required this.bottomInset,
  });

  final bool loading;
  final _Progress progress;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final hasPlan = progress.weeks.isNotEmpty;
    final phases = _groupPhases(progress.weeks);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(loading: loading, progress: progress),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 96),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(V5.yellow),
                  ),
                ),
              ),
            )
          else if (!hasPlan)
            const Padding(
              padding: EdgeInsets.fromLTRB(V5.gutter, 28, V5.gutter, 0),
              child: _EmptyNote(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(V5.gutter, 26, V5.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < phases.length; i++) ...[
                    if (i > 0) const SizedBox(height: 30),
                    _PhaseSection(
                      phase: phases[i],
                      index: i,
                      progress: progress,
                    ),
                  ],
                ],
              ),
            ),
          SizedBox(height: 120 + bottomInset),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero — full-bleed dark stage, bleeds to the top edge
// ─────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.loading, required this.progress});

  final bool loading;
  final _Progress progress;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final hasPlan = progress.weeks.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: V5.heroGradient),
        child: Stack(
          children: [
            // Atmospheric layers — warm glow top-right, amber bottom-left,
            // deterministic film grain. Matches the app's stage-hero canvas.
            Positioned(
              top: -90,
              right: -70,
              child: V5AmbientGlow(
                size: const Size(260, 260),
                opacity: 0.20,
                color: V5.yellow,
              ),
            ),
            Positioned(
              bottom: -70,
              left: -80,
              child: V5AmbientGlow(
                size: const Size(220, 220),
                opacity: 0.10,
                color: V5.yellowSpark,
              ),
            ),
            const Positioned.fill(child: V5Texture(opacity: 0.05)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                V5.gutter,
                topInset + 18,
                V5.gutter,
                26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VIKA',
                        style: V5
                            .eyebrow(context, color: V5.invInk)
                            .copyWith(fontSize: 12, letterSpacing: 4),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(V5.radiusFull),
                          border: Border.all(color: V5.heroBorderHi),
                        ),
                        child: Text(
                          'READ-ONLY',
                          style: V5
                              .eyebrow(context, color: V5.invInkSoft)
                              .copyWith(letterSpacing: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const V5Sparkle(size: 11),
                      const SizedBox(width: 8),
                      Text(
                        'Reviewer preview',
                        style: V5
                            .eyebrow(context, color: V5.yellow)
                            .copyWith(letterSpacing: 1.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loading ? 'Loading the\nsample plan…' : 'The plan,\nend to end.',
                    style: V5.headline(context, color: V5.invInk).copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.02,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loading
                        ? 'Fetching the seeded training plan.'
                        : hasPlan
                            ? 'A read-only look at the seeded ${progress.total}-week '
                                'journey. Nothing is generated or saved.'
                            : 'The demo account has no active plan to preview.',
                    style: V5.bodySm(context, color: V5.invInkSoft),
                  ),
                  if (hasPlan) ...[
                    const SizedBox(height: 22),
                    _PhaseRibbon(progress: progress),
                    const SizedBox(height: 14),
                    Text(
                      'Week ${progress.currentWeek} of ${progress.total}'
                      '${progress.allDone ? '  ·  complete' : ''}',
                      style: V5
                          .eyebrow(context, color: V5.invInkSoft)
                          .copyWith(letterSpacing: 1.2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The arc thesis, visualized as progress: one tick per week, split into phase
/// segments. Done weeks read as filled, the current week glows, weeks still
/// ahead stay faint — so it mirrors exactly where the plan actually is.
class _PhaseRibbon extends StatelessWidget {
  const _PhaseRibbon({required this.progress});

  final _Progress progress;

  @override
  Widget build(BuildContext context) {
    final phases = _groupPhases(progress.weeks);
    return Row(
      children: [
        for (var p = 0; p < phases.length; p++) ...[
          if (p > 0) const SizedBox(width: 10),
          Expanded(
            flex: phases[p].weeks.length,
            child: Row(
              children: [
                for (var i = 0; i < phases[p].weeks.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _Tick(
                      isCurrent: phases[p].weeks[i].weekNumber ==
                          progress.currentWeek,
                      isDone: progress.doneWeeks
                          .contains(phases[p].weeks[i].weekNumber),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.isCurrent, required this.isDone});

  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: isCurrent
            ? V5.yellow
            : isDone
                ? V5.yellow.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: V5.yellow.withValues(alpha: 0.55),
                  blurRadius: 9,
                ),
              ]
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phase section — numbered header + spined week list
// ─────────────────────────────────────────────────────────────

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({
    required this.phase,
    required this.index,
    required this.progress,
  });

  final _Phase phase;
  final int index;
  final _Progress progress;

  @override
  Widget build(BuildContext context) {
    final first = phase.weeks.first.weekNumber;
    final last = phase.weeks.last.weekNumber;
    final range = first == last ? 'W$first' : 'W$first–$last';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Structural header — the numbered marker encodes real plan structure.
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: V5.ink,
                shape: BoxShape.circle,
              ),
              child: phase.isRecovery
                  ? const Icon(Icons.spa_rounded, size: 16, color: V5.yellow)
                  : Text(
                      '${index + 1}',
                      style: V5.text(
                        context,
                        size: 14,
                        weight: FontWeight.w800,
                        color: V5.yellow,
                        height: 1,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    phase.isRecovery
                        ? 'RECOVERY'
                        : 'PHASE ${(index + 1).toString().padLeft(2, '0')}',
                    style: V5
                        .eyebrow(context, color: V5.yellowDeep)
                        .copyWith(letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phase.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V5.title(context, color: V5.ink),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: V5.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(V5.radiusFull),
                border: Border.all(color: V5.border),
              ),
              child: Text(
                range,
                style: V5
                    .eyebrow(context, color: V5.inkSoft)
                    .copyWith(letterSpacing: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Spined week list — one continuous rail through this phase.
        for (var i = 0; i < phase.weeks.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 34,
                  child: CustomPaint(
                    painter: _SpinePainter(
                      drawTop: i > 0,
                      drawBottom: i < phase.weeks.length - 1,
                      isCurrent: phase.weeks[i].weekNumber ==
                          progress.currentWeek,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < phase.weeks.length - 1 ? 10 : 0,
                    ),
                    child: phase.weeks[i].weekNumber == progress.currentWeek
                        ? _CurrentWeekCard(
                            week: phase.weeks[i],
                            nextSessionIndex: progress.nextSessionIndex,
                          )
                        : _WeekRow(
                            week: phase.weeks[i],
                            isDone: progress.doneWeeks
                                .contains(phase.weeks[i].weekNumber),
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical rail + node, drawn per row so consecutive rows form a continuous
/// spine. The node sits near the top so it aligns with each card's "WEEK X".
class _SpinePainter extends CustomPainter {
  _SpinePainter({
    required this.drawTop,
    required this.drawBottom,
    required this.isCurrent,
  });

  final bool drawTop;
  final bool drawBottom;
  final bool isCurrent;

  static const double _nodeY = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final rail = Paint()
      ..color = V5.ink.withValues(alpha: 0.14)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (drawTop) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, _nodeY), rail);
    }
    if (drawBottom) {
      canvas.drawLine(Offset(cx, _nodeY), Offset(cx, size.height), rail);
    }

    if (isCurrent) {
      canvas.drawCircle(
        Offset(cx, _nodeY),
        7,
        Paint()..color = V5.yellow.withValues(alpha: 0.22),
      );
      canvas.drawCircle(Offset(cx, _nodeY), 4.5, Paint()..color = V5.yellow);
    } else {
      canvas.drawCircle(
        Offset(cx, _nodeY),
        3.5,
        Paint()
          ..color = V5.ink.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(cx, _nodeY),
        3.5,
        Paint()
          ..color = V5.bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpinePainter old) =>
      old.drawTop != drawTop ||
      old.drawBottom != drawBottom ||
      old.isCurrent != isCurrent;
}

// ─────────────────────────────────────────────────────────────
// Current week — dark hero card showing the actual next session
// ─────────────────────────────────────────────────────────────

class _CurrentWeekCard extends StatelessWidget {
  const _CurrentWeekCard({required this.week, required this.nextSessionIndex});

  final WeekPlan week;
  final int nextSessionIndex;

  @override
  Widget build(BuildContext context) {
    final session = _sessionByIndex(week, nextSessionIndex);
    final slots = (session?.slots ?? const <SlotAssignment>[]).take(4).toList();
    final narrative = week.isDeloadWeek
        ? 'Lighter loads — let the body recover.'
        : 'Pick up right where you left off.';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: V5.heroGradient,
        borderRadius: BorderRadius.circular(V5.radiusLg),
        border: Border.all(color: V5.heroBorder),
        boxShadow: V5.elevation2,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: V5AmbientGlow(
              size: const Size(160, 160),
              opacity: 0.16,
              color: V5.yellow,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'WEEK ${week.weekNumber}',
                    style: V5
                        .eyebrow(context, color: V5.invInkSoft)
                        .copyWith(letterSpacing: 1.6),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: V5.yellow,
                      borderRadius: BorderRadius.circular(V5.radiusFull),
                    ),
                    child: Text(
                      'CURRENT',
                      style: V5
                          .eyebrow(context, color: V5.yellowInk)
                          .copyWith(letterSpacing: 1.0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                narrative,
                style: V5
                    .titleSm(context, color: V5.invInk)
                    .copyWith(height: 1.25),
              ),
              const SizedBox(height: 14),
              const V5Divider(dark: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'UP NEXT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V5
                          .eyebrow(context, color: V5.yellow)
                          .copyWith(letterSpacing: 1.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${week.sessions.length} '
                    '${week.sessions.length == 1 ? 'session' : 'sessions'}/wk',
                    style: V5.caption(context, color: V5.invInkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (slots.isEmpty)
                Text('—', style: V5.bodySm(context, color: V5.invInkSoft))
              else
                for (final slot in slots) ...[
                  _ExerciseLine(slot: slot, dark: true),
                  const SizedBox(height: 7),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Other weeks — quiet cream rows
// ─────────────────────────────────────────────────────────────

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week, required this.isDone});

  final WeekPlan week;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final names = _firstSessionSlots(week)
        .map((s) => _exerciseLabel(s.exerciseId))
        .toList();
    final shown = names.take(3).join('  ·  ');
    final extra = names.length > 3 ? '  +${names.length - 3}' : '';
    // Done weeks recede; weeks still ahead keep the warm accent.
    final badgeBg = isDone
        ? V5.ink.withValues(alpha: 0.05)
        : week.isDeloadWeek
            ? V5.bgSoft
            : V5.yellowSoft;
    final nameColor = isDone ? V5.inkFaint : V5.inkSoft;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusMd),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: isDone
                ? Icon(Icons.check_rounded, size: 18, color: V5.inkSoft)
                : Text(
                    '${week.weekNumber}',
                    style: V5.text(
                      context,
                      size: 16,
                      weight: FontWeight.w800,
                      color: week.isDeloadWeek ? V5.inkSoft : V5.yellowDeep,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'WEEK ${week.weekNumber}',
                      style: V5
                          .eyebrow(context, color: V5.inkFaint)
                          .copyWith(letterSpacing: 1.2),
                    ),
                    if (isDone) ...[
                      const SizedBox(width: 7),
                      Text(
                        'DONE',
                        style: V5
                            .eyebrow(context, color: V5.inkFaint)
                            .copyWith(letterSpacing: 1.2),
                      ),
                    ] else if (week.isDeloadWeek) ...[
                      const SizedBox(width: 7),
                      Text(
                        'DELOAD',
                        style: V5
                            .eyebrow(context, color: V5.yellowDeep)
                            .copyWith(letterSpacing: 1.0),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${week.sessions.length}',
                      style: V5.caption(context, color: V5.inkFaint),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  shown.isEmpty ? '—' : '$shown$extra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.bodySm(context, color: nameColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.slot, required this.dark});

  final SlotAssignment slot;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? V5.invInk : V5.ink;
    final fgSoft = dark ? V5.invInkSoft : V5.inkSoft;
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: V5.yellow,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _exerciseLabel(slot.exerciseId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V5.text(
              context,
              size: 13.5,
              weight: FontWeight.w700,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatVolume(slot.volume), style: V5.caption(context, color: fgSoft)),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusMd),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: Text(
        'You can still enter the app to explore the seeded account.',
        style: V5.bodySm(context, color: V5.inkSoft),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Data helpers — read-only shaping of the plan, no Vietnamese chrome
// ─────────────────────────────────────────────────────────────

class _Phase {
  const _Phase({
    required this.name,
    required this.isRecovery,
    required this.weeks,
  });

  final String name;
  final bool isRecovery;
  final List<WeekPlan> weeks;
}

List<_Phase> _groupPhases(List<WeekPlan> weeks) {
  final grouped = <int, List<WeekPlan>>{};
  for (final week in weeks) {
    grouped.putIfAbsent(week.phaseNumber, () => <WeekPlan>[]).add(week);
  }
  final keys = grouped.keys.toList()..sort();
  return [
    for (final key in keys)
      _Phase(
        name: grouped[key]!.first.phaseName,
        isRecovery: grouped[key]!.every((w) => w.isDeloadWeek),
        weeks: grouped[key]!,
      ),
  ];
}

/// Where the seeded plan actually stands — derived from the snapshot's
/// completion state so the preview matches the home/plan tabs exactly (current
/// week, the real next session, and which weeks are already done).
class _Progress {
  const _Progress({
    required this.weeks,
    required this.currentWeek,
    required this.nextSessionIndex,
    required this.doneWeeks,
  });

  final List<WeekPlan> weeks;

  /// Week number holding the first uncompleted session. Falls back to the last
  /// week when the whole plan is finished.
  final int currentWeek;

  /// Session index of the next uncompleted session within [currentWeek].
  final int nextSessionIndex;

  /// Week numbers whose every session is already logged complete.
  final Set<int> doneWeeks;

  int get total => weeks.length;
  bool get allDone => weeks.isNotEmpty && doneWeeks.length == weeks.length;
}

_Progress _deriveProgress(PlanSnapshot? snapshot) {
  final weeks = snapshot?.plan.weeks ?? const <WeekPlan>[];
  final completion = snapshot?.completionMap ?? const <int, Set<int>>{};
  final doneWeeks = <int>{
    for (final w in weeks)
      if (_isWeekDone(w, completion[w.weekNumber])) w.weekNumber,
  };

  // currentPosition is (weekNumber, nextSessionIndex), or null once the plan
  // is fully complete — then anchor on the final week's last session.
  final pos = snapshot?.currentPosition;
  int currentWeek;
  int nextSessionIndex;
  if (pos != null) {
    currentWeek = pos.$1;
    nextSessionIndex = pos.$2;
  } else if (weeks.isNotEmpty) {
    final last = weeks.last;
    currentWeek = last.weekNumber;
    nextSessionIndex =
        last.sessions.isEmpty ? 0 : last.sessions.last.sessionIndex;
  } else {
    currentWeek = 0;
    nextSessionIndex = 0;
  }

  return _Progress(
    weeks: weeks,
    currentWeek: currentWeek,
    nextSessionIndex: nextSessionIndex,
    doneWeeks: doneWeeks,
  );
}

bool _isWeekDone(WeekPlan week, Set<int>? done) {
  if (week.sessions.isEmpty || done == null) return false;
  return week.sessions.every((s) => done.contains(s.sessionIndex));
}

SessionPlan? _sessionByIndex(WeekPlan week, int sessionIndex) {
  for (final session in week.sessions) {
    if (session.sessionIndex == sessionIndex) return session;
  }
  return week.sessions.isEmpty ? null : week.sessions.first;
}

List<SlotAssignment> _firstSessionSlots(WeekPlan week) {
  if (week.sessions.isEmpty) return const <SlotAssignment>[];
  return week.sessions.first.slots;
}

/// Vietnamese exercise display name from the plan's exercise id. Mirrors the
/// resolution used on S15's journey reveal so the two read identically.
String _exerciseLabel(String id) {
  final definition = lookupExerciseDefinition(id);
  if (definition != null) return definition.name;
  return id
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatVolume(VolumePrescription volume) {
  final target = volume.reps != null
      ? '${volume.reps} rep'
      : volume.seconds != null
          ? '${volume.seconds}s'
          : '';
  return '${volume.sets} hiệp${target.isEmpty ? '' : ' x $target'}';
}
