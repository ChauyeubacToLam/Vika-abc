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

import '../../../data/program_mock.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/responsive.dart';
import '../../../theme/vf_theme.dart';
import '../plan_typography.dart';
import 'program_atoms.dart';

/// Left stat-gutter width — sized for a two-digit italic form numeral.
const double _kGutter = 56;

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
    final entries = <Widget>[];
    void add(Widget w) {
      if (entries.isNotEmpty) {
        entries.add(Container(height: 1, color: c.border));
      }
      entries.add(w);
    }

    for (final s in block.sessions) {
      add(_entryFor(s));
    }
    if (retest != null) {
      add(_RetestEntry(
        retest: retest!,
        unlocked: retestUnlocked,
        onStart: onStartRetest,
      ));
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
      ProgramStatus.current => _NextEntry(session: s, onStart: onStartNext),
      ProgramStatus.upcoming => _UpcomingEntry(session: s),
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared entry scaffold — left gutter marker + right body
// ═══════════════════════════════════════════════════════════════

class _Entry extends StatelessWidget {
  const _Entry({
    required this.marker,
    required this.body,
    this.onTap,
    this.vertical = 18,
  });

  final Widget marker;
  final Widget body;
  final VoidCallback? onTap;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _kGutter, child: marker),
          const SizedBox(width: 18),
          Expanded(child: body),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DONE — drop-cap form numeral + recap, expands to per-exercise bars
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
      marker: _DropCapForm(form: session.formScore),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              session.label.toUpperCase(),
              style: beVietnamPro(
                size: 10.5,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.inkSoft,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.title.isEmpty ? session.label : session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: beVietnamPro(
              size: r.sp(18),
              weight: FontWeight.w800,
              letterSpacing: -0.5,
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

class _DropCapForm extends StatelessWidget {
  const _DropCapForm({required this.form});
  final int? form;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          form?.toString() ?? '—',
          style: frauncesItalic(
            size: 42,
            weight: FontWeight.w800,
            letterSpacing: -2.4,
            height: 0.82,
            color: _formColor(form, c),
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PHONG ĐỘ',
          style: beVietnamPro(
            size: 8,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
            color: c.inkFaint,
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
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: c.border),
          const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _AiDot(active: exercise.hasAi),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              exercise.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: beVietnamPro(
                size: 12.5,
                weight: FontWeight.w700,
                letterSpacing: -0.1,
                color: c.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: c.border,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: f == null ? 0 : (f.clamp(0, 100)) / 100,
                  child: Container(color: _formColor(f, c)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 22,
            child: Text(
              f?.toString() ?? '—',
              textAlign: TextAlign.right,
              style: beVietnamPro(
                size: 12.5,
                weight: FontWeight.w800,
                letterSpacing: -0.2,
                color: f == null ? c.inkGhost : c.ink,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NEXT — the focal entry (gold marker + accents, no box)
// ═══════════════════════════════════════════════════════════════

class _NextEntry extends StatefulWidget {
  const _NextEntry({required this.session, required this.onStart});
  final PlanSession session;
  final VoidCallback onStart;

  @override
  State<_NextEntry> createState() => _NextEntryState();
}

class _NextEntryState extends State<_NextEntry> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final session = widget.session;
    final aiCount = session.exercises.where((e) => e.hasAi).length;
    final metaBits = <String>[
      if (session.durationLabel.isNotEmpty) '~${session.durationLabel}',
      '${session.exerciseCount} bài',
      if (aiCount > 0) '$aiCount có AI',
    ];
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onStart();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _Entry(
          vertical: 20,
          marker: const _PlayMarker(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'TIẾP THEO · ${session.label.toUpperCase()}',
                  style: beVietnamPro(
                    size: 10.5,
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.yellow,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                session.title.isEmpty ? session.label : session.title,
                style: frauncesItalic(
                  size: r.sp(24),
                  weight: FontWeight.w800,
                  letterSpacing: -1.0,
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
              const SizedBox(height: 14),
              for (final ex in session.exercises) _PreviewRow(exercise: ex),
              const SizedBox(height: 12),
              ProgramCoachNote(text: session.coachNote, size: 13),
              const SizedBox(height: 16),
              _StartCue(label: 'Bắt đầu ${session.label}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayMarker extends StatelessWidget {
  const _PlayMarker();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.play_arrow_rounded, size: 20, color: c.yellowInk),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _AiDot(active: exercise.hasAi),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: beVietnamPro(
                size: 13,
                weight: FontWeight.w700,
                letterSpacing: -0.1,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            exercise.volumeLabel,
            style: beVietnamPro(
              size: 12,
              weight: FontWeight.w600,
              color: c.inkFaint,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet start affordance inside the NEXT entry — the loud halo CTA is the
/// hero's; this is the subordinate launch point.
class _StartCue extends StatelessWidget {
  const _StartCue({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Text(
          label,
          style: beVietnamPro(
            size: 14,
            weight: FontWeight.w800,
            letterSpacing: -0.2,
            color: c.ink,
          ),
        ),
        const Spacer(),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: c.yellow),
        ),
      ],
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
      marker: const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Align(alignment: Alignment.topLeft, child: _RingMarker()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Text(
                  session.label.toUpperCase(),
                  style: beVietnamPro(
                    size: 10.5,
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const Spacer(),
                Text(
                  '${session.exerciseCount} bài · Sắp tới',
                  style: beVietnamPro(
                    size: 11,
                    weight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
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

class _RingMarker extends StatelessWidget {
  const _RingMarker();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.borderHi, width: 1.4),
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
      vertical: 20,
      onTap: unlocked ? onStart : null,
      marker: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.yellowGhost,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag_rounded, size: 19, color: c.yellow),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'CHẶNG CUỐI',
              style: beVietnamPro(
                size: 10.5,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.yellow,
              ),
            ),
          ),
          const SizedBox(height: 6),
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
            _StartCue(label: 'Bắt đầu ${retest.title.toLowerCase()}')
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

// ═══════════════════════════════════════════════════════════════
// AI DOT — yellow filled dot with faint outer ring
// ═══════════════════════════════════════════════════════════════

class _AiDot extends StatelessWidget {
  const _AiDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    if (!active) {
      return SizedBox(
        width: 12,
        height: 12,
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.inkGhost, width: 1),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 12,
      height: 12,
      child: Center(
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: c.yellow.withValues(alpha: 0.5), width: 1),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: c.yellow, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
