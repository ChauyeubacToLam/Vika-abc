// ProgramSessionLedger — §SỔ BUỔI: the selected block's sessions as a
// magazine-style editorial spread laid directly on the cream canvas. NO card
// chrome — typography, a left "stat gutter", and hairlines do the structural
// work (matching HomeVitalsSpread, the app's editorial benchmark). This avoids
// the "stacked cards" look while staying visually rich.
//
// Left gutter marker per status · right column = the session:
//   DONE      big italic FORM numeral (color-coded) + "PHONG ĐỘ"  → title,
//             difficulty, coach recap; expands to per-exercise form bars
//   NEXT      a gold play disc → gold eyebrow, larger title, exercise preview,
//             coach note, quiet start (the loud halo CTA lives in the hero)
//   UPCOMING  a faint ring → muted title + count
//   RETEST    a flag disc → the end-of-program milestone, completion-locked
//
// Status is completion-only; there are no dates. Form score + a small coach
// note are preserved per the brief; yellow stays reserved (here: the form
// stat numeral, the AI dot, the play marker, the section underline).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/library_mock.dart';
import '../../../data/program_mock.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/responsive.dart';
import '../../../theme/vf_theme.dart';
import '../../ivory/atoms.dart';
import '../plan_typography.dart';
import 'program_atoms.dart';

Color _formColor(int? form, VikaColors c) {
  if (form == null) return c.inkGhost;
  if (form >= 80) return c.yellow; // a stat numeral — a sanctioned yellow use
  if (form < 70) return c.attention;
  return c.ink;
}

class ProgramSessionLedger extends StatelessWidget {
  const ProgramSessionLedger({
    super.key,
    required this.block,
    required this.expandedIndex,
    required this.onToggleExpand,
    required this.onStartNext,
    this.retest,
    this.retestUnlocked = false,
    this.onStartRetest,
  });

  final ProgramBlock block;
  final int? expandedIndex;
  final ValueChanged<int> onToggleExpand;
  final VoidCallback onStartNext;

  /// When non-null, the end-of-program retest is appended as the final entry
  /// (the screen passes it only for the last block).
  final ProgramRetest? retest;
  final bool retestUnlocked;
  final VoidCallback? onStartRetest;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);

    // Each item knows whether it's the elevated NEXT panel. Flat editorial
    // entries are separated by the page's hairline rule; the bordered panel
    // gets clear space instead, so a stray line never butts against its edge.
    final items = <({Widget widget, bool panel})>[
      for (final s in block.sessions)
        (widget: _entryFor(s), panel: s.status == ProgramStatus.current),
      if (retest != null)
        (
          widget: _RetestEntry(
            retest: retest!,
            unlocked: retestUnlocked,
            onStart: onStartRetest,
          ),
          panel: false,
        ),
    ];

    final entries = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        final adjacentToPanel = items[i - 1].panel || items[i].panel;
        entries.add(adjacentToPanel
            ? const SizedBox(height: 4)
            : Container(height: 1, color: c.border));
      }
      entries.add(items[i].widget);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgramSectionMark(
          label: 'SỔ BUỔI · KHỐI ${block.blockNumber}',
          trailing: '${block.sessionsDone.toString().padLeft(2, '0')} / '
              '${block.sessionsTotal.toString().padLeft(2, '0')}',
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: entries,
          ),
        ),
      ],
    );
  }

  Widget _entryFor(PlanSession s) {
    return switch (s.status) {
      ProgramStatus.done => _DoneEntry(
          session: s,
          expanded: expandedIndex == s.index,
          onTap: () => onToggleExpand(s.index),
        ),
      ProgramStatus.current =>
        _NextEntry(session: s, onStart: onStartNext),
      ProgramStatus.upcoming => _UpcomingEntry(session: s),
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared entry scaffold — full width (no left gutter). Status reads
// inline via the header dot + the eyebrow; nothing is skewed right.
// ═══════════════════════════════════════════════════════════════

class _Entry extends StatelessWidget {
  const _Entry({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: child,
    );
    if (onTap == null) return padded;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: padded,
    );
  }
}

/// Inline status dot that opens each entry's header — replaces the old 56px
/// marker gutter. Tiny, so the eyebrow sits right beside it.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final ProgramStatus status;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    switch (status) {
      case ProgramStatus.done:
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            border:
                Border.all(color: c.ink.withValues(alpha: 0.14), width: 1),
          ),
        );
      case ProgramStatus.current:
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.yellow.withValues(alpha: 0.5), blurRadius: 7),
            ],
          ),
        );
      case ProgramStatus.upcoming:
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.borderHi, width: 1.4),
          ),
        );
    }
  }
}

/// The eyebrow line that opens every entry: status dot + label, with an
/// optional trailing widget (form stat / count) pinned right.
class _EntryHeader extends StatelessWidget {
  const _EntryHeader({
    required this.status,
    required this.label,
    required this.labelColor,
    this.trailing,
  });

  final ProgramStatus status;
  final String label;
  final Color labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StatusDot(status: status),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: beVietnamPro(
              size: 10.5,
              weight: FontWeight.w800,
              letterSpacing: 1.6,
              color: labelColor,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DONE — full-width recap with an inline form stat, expands to tiles
// ═══════════════════════════════════════════════════════════════

class _DoneEntry extends StatelessWidget {
  const _DoneEntry({
    required this.session,
    required this.expanded,
    required this.onTap,
  });

  final PlanSession session;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return _Entry(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EntryHeader(
            status: ProgramStatus.done,
            label: session.label.toUpperCase(),
            labelColor: c.inkSoft,
            trailing: _FormStat(form: session.formScore),
          ),
          const SizedBox(height: 12),
          Text(
            session.title.isEmpty ? session.label : session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: beVietnamPro(
              size: r.sp(20),
              weight: FontWeight.w800,
              letterSpacing: -0.6,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              if (session.difficulty != null)
                DifficultyPill(difficulty: session.difficulty!),
              if (session.durationLabel.isNotEmpty)
                Text(
                  session.durationLabel,
                  style: beVietnamPro(
                    size: 12,
                    weight: FontWeight.w600,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ProgramCoachNote(text: session.coachNote, soft: true, size: 12.5),
          const SizedBox(height: 12),
          _ExpandCue(count: session.exerciseCount, expanded: expanded),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _Expansion(session: session)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Compact inline form stat (right of the DONE header) — color-coded italic
/// numeral + tiny label. Replaces the old left drop-cap.
class _FormStat extends StatelessWidget {
  const _FormStat({required this.form});
  final int? form;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'PHONG ĐỘ',
          style: beVietnamPro(
            size: 8,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
            color: c.inkFaint,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          form?.toString() ?? '—',
          style: frauncesItalic(
            size: 30,
            weight: FontWeight.w800,
            letterSpacing: -1.6,
            height: 0.9,
            color: _formColor(form, c),
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ],
    );
  }
}

class _ExpandCue extends StatelessWidget {
  const _ExpandCue({required this.count, required this.expanded});
  final int count;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Text(
          expanded ? 'Thu gọn' : '$count bài · xem chi tiết',
          style: beVietnamPro(
            size: 12,
            weight: FontWeight.w700,
            letterSpacing: -0.1,
            color: c.inkSoft,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: c.inkFaint),
        ),
      ],
    );
  }
}

class _Expansion extends StatelessWidget {
  const _Expansion({required this.session});
  final PlanSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ex in session.exercises) _ExerciseFormRow(exercise: ex),
        ],
      ),
    );
  }
}

class _ExerciseFormRow extends StatelessWidget {
  const _ExerciseFormRow({required this.exercise});
  final SessionExercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final f = exercise.formScore;
    final tone = _formColor(f, c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: _exerciseTileDecoration(c),
        child: Row(
          children: [
            SessionExerciseThumb(
              asset: exerciseThumbnailForId(exercise.exerciseId),
              size: 48,
              radius: 13,
              showAi: exercise.hasAi,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: beVietnamPro(
                      size: 14,
                      weight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Slim form bar — the recap of how the rep quality scored.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 5,
                      color: c.border,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: f == null ? 0 : (f.clamp(0, 100)) / 100,
                        child: Container(color: tone),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Form score as a contained stat — color-coded, the one number
            // that matters for a completed exercise.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  f?.toString() ?? '—',
                  style: frauncesItalic(
                    size: 22,
                    weight: FontWeight.w800,
                    letterSpacing: -1.0,
                    height: 0.9,
                    color: f == null ? c.inkGhost : tone,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ĐIỂM',
                  style: beVietnamPro(
                    size: 7.5,
                    weight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NEXT — the focal entry: the full breakdown of today's session.
// The single launch action lives in the hero's halo CTA, so this
// entry carries NO button (it was the duplicate "second play").
// ═══════════════════════════════════════════════════════════════

class _NextEntry extends StatelessWidget {
  const _NextEntry({required this.session, required this.onStart});
  final PlanSession session;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final aiCount = session.exercises.where((e) => e.hasAi).length;
    final metaBits = <String>[
      if (session.durationLabel.isNotEmpty) '~${session.durationLabel}',
      '${session.exerciseCount} bài',
      if (aiCount > 0) '$aiCount có AI',
    ];
    // The one focal session is an elevated, self-contained card — the active
    // block reads as a distinct premium object against the flat editorial
    // done/upcoming entries around it. Everything for today lives in here:
    // the breakdown of exercises and, at the end, the start button.
    return _Entry(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(18),
          // Same 1px c.border hairline the section header + dividers use, so
          // the panel belongs to the Plan's editorial language instead of
          // floating like a catalog card. No drop shadow — the page is flat.
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EntryHeader(
              status: ProgramStatus.current,
              label: 'TIẾP THEO · ${session.label.toUpperCase()}',
              labelColor: c.yellow,
            ),
            const SizedBox(height: 12),
            Text(
              session.title.isEmpty ? session.label : session.title,
              style: frauncesItalic(
                size: r.sp(27),
                weight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1.0,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metaBits.join('  ·  '),
              style: beVietnamPro(
                size: 12.5,
                weight: FontWeight.w600,
                letterSpacing: -0.1,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(height: 16),
            for (final ex in session.exercises) _PreviewRow(exercise: ex),
            const SizedBox(height: 8),
            Container(height: 1, color: c.border),
            const SizedBox(height: 12),
            ProgramCoachNote(text: session.coachNote, size: 13),
            const SizedBox(height: 16),
            _StartCue(label: 'Bắt đầu ${session.label}', onTap: onStart),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.exercise});
  final SessionExercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: _exerciseTileDecoration(c),
        child: Row(
          children: [
            SessionExerciseThumb(
              asset: exerciseThumbnailForId(exercise.exerciseId),
              size: 52,
              radius: 13,
              showAi: exercise.hasAi,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exercise.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: beVietnamPro(
                  size: 15,
                  weight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: c.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _VolumeChip(label: exercise.volumeLabel),
          ],
        ),
      ),
    );
  }
}

/// Shared exercise-chip surface — a soft warm inset (powder) so each exercise
/// reads as a distinct item inside the session card without stacking a second
/// shadow against the card's own elevation.
BoxDecoration _exerciseTileDecoration(VikaColors c) => BoxDecoration(
      color: c.powder,
      borderRadius: BorderRadius.circular(14),
    );

/// Right-anchored prescription pill, e.g. "3 × 12". Tabular figures keep the
/// numerals aligned tile to tile.
class _VolumeChip extends StatelessWidget {
  const _VolumeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: beVietnamPro(
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: -0.1,
          color: c.inkSoft,
          fontFeatures: VikaIvoryMain.tabularFigures,
        ),
      ),
    );
  }
}

/// Quiet start affordance inside the NEXT entry — the loud halo CTA is the
/// hero's; this is the subordinate launch point.
class _StartCue extends StatefulWidget {
  const _StartCue({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_StartCue> createState() => _StartCueState();
}

class _StartCueState extends State<_StartCue> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // A substantial filled pill — ink body with a yellow knob. The hero owns
    // the loud yellow halo CTA; this caps the session card so starting reads
    // contextually at the end of the breakdown.
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(20, 0, 7, 0),
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: beVietnamPro(
                    size: 15,
                    weight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.invInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: c.yellowInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// UPCOMING — receded
// ═══════════════════════════════════════════════════════════════

class _UpcomingEntry extends StatelessWidget {
  const _UpcomingEntry({required this.session});
  final PlanSession session;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return _Entry(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EntryHeader(
            status: ProgramStatus.upcoming,
            label: session.label.toUpperCase(),
            labelColor: c.inkFaint,
            trailing: Text(
              '${session.exerciseCount} bài · Sắp tới',
              style: beVietnamPro(
                size: 11,
                weight: FontWeight.w700,
                letterSpacing: 0.2,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            session.title.isEmpty ? session.label : session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: beVietnamPro(
              size: r.sp(16),
              weight: FontWeight.w700,
              letterSpacing: -0.4,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          ProgramCoachNote(
            text: session.coachNote,
            soft: true,
            size: 12.5,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RETEST — the end-of-program milestone, folded in as the final entry
// ═══════════════════════════════════════════════════════════════

class _RetestEntry extends StatelessWidget {
  const _RetestEntry({
    required this.retest,
    required this.unlocked,
    this.onStart,
  });

  final ProgramRetest retest;
  final bool unlocked;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return _Entry(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.yellowGhost,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_rounded, size: 14, color: c.yellow),
              ),
              const SizedBox(width: 10),
              Text(
                'CHẶNG CUỐI',
                style: beVietnamPro(
                  size: 10.5,
                  weight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: c.yellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            retest.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: frauncesItalic(
              size: r.sp(22),
              weight: FontWeight.w800,
              letterSpacing: -0.9,
              height: 1.0,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          ProgramCoachNote(text: retest.coachNote, soft: true, size: 12.5),
          const SizedBox(height: 14),
          if (unlocked)
            _StartCue(
              label: 'Bắt đầu ${retest.title.toLowerCase()}',
              onTap: onStart,
            )
          else
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: c.inkFaint),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Mở khi hoàn tất Phục hồi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: beVietnamPro(
                      size: 12.5,
                      weight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: c.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

