// PlanStageHero — the Plan tab's dark stage, polished to "private
// training journal" feel. Final v3 design.
//
// Replaces the boxy tab navigation with a magazine-style WEEK SCRUBBER:
// phase labels arrayed across the top (PHASE 01: NỀN TẢNG, PHASE 02:
// PHÁT TRIỂN, …), connected dot stations on a continuous line, italic
// tabular week numerals below with an animated yellow underline that
// SLIDES between selections. Feels like a luxury watch face's bezel
// markings rather than a button bar.
//
// Below the scrubber: an AnimatedSwitcher crossfades the descriptive
// section when the user changes weeks. The descriptive section is one
// confident composition — italic display headline as the anchor, compact
// stat row, coach voice card, and a status-aware CTA.
//
// Status-aware CTA design:
//   • CURRENT week → gold halo "Bắt đầu Buổi N"
//   • DONE week    → muted "Đã hoàn tất" with checkmark knob
//   • FUTURE week  → locked "Mở khi đến tuần này" with padlock knob

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/plan_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'wordmark_header.dart';

class PlanStageHero extends StatelessWidget {
  const PlanStageHero({
    super.key,
    required this.weeks,
    required this.selectedIndex,
    required this.onSelectWeek,
    required this.onStartCurrentSession,
    required this.userInitial,
    this.onAvatarTap,
    this.onCalendarTap,
  });

  final List<PlanWeek> weeks;
  final int selectedIndex;
  final ValueChanged<int> onSelectWeek;
  final VoidCallback onStartCurrentSession;
  final String userInitial;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onCalendarTap;

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 250.0;
    if (velocity < -threshold && selectedIndex < weeks.length - 1) {
      HapticFeedback.lightImpact();
      onSelectWeek(selectedIndex + 1);
    } else if (velocity > threshold && selectedIndex > 0) {
      HapticFeedback.lightImpact();
      onSelectWeek(selectedIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final selectedWeek = weeks[selectedIndex];

    return GestureDetector(
      // Horizontal swipe anywhere on the hero navigates weeks. Vertical
      // scroll passes through to the parent ScrollView naturally
      // because GestureDetector only claims the horizontal-drag arena.
      onHorizontalDragEnd: _handleSwipe,
      behavior: HitTestBehavior.translucent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.7, -1),
              end: const Alignment(0.7, 1),
              colors: [c.bgInverse, c.bgInverseHi],
            ),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.22),
                blurRadius: 48,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ─── Atmosphere ──────────────────────────────────────
              Positioned(
                top: -130,
                right: -110,
                child: IgnorePointer(
                  child: _AmbientGlow(
                    size: const Size(420, 420),
                    color: c.yellow,
                    opacity: 0.22,
                  ),
                ),
              ),
              Positioned(
                bottom: -180,
                left: -140,
                child: IgnorePointer(
                  child: _AmbientGlow(
                    size: const Size(440, 380),
                    color: const Color(0xFFCD7C45),
                    opacity: 0.18,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: const _GrainTexture(opacity: 0.05),
                ),
              ),
              const Positioned(
                top: 220,
                right: 58,
                child: IgnorePointer(
                  child: Opacity(opacity: 0.42, child: _Sparkle(size: 11)),
                ),
              ),
              const Positioned(
                top: 420,
                left: 36,
                child: IgnorePointer(
                  child: Opacity(opacity: 0.26, child: _Sparkle(size: 9)),
                ),
              ),

              // ─── Content ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(top: topInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LightStatusBar(),
                    WordmarkHeader(
                      inverted: true,
                      userInitial: userInitial,
                      trailingIcon: Icons.calendar_today_rounded,
                      trailingTooltip: 'Lịch',
                      onTrailingTap: onCalendarTap,
                      onAvatarTap: onAvatarTap,
                    ),
                    const SizedBox(height: 26),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _WeekScrubber(
                        weeks: weeks,
                        selectedIndex: selectedIndex,
                        onSelect: (i) {
                          HapticFeedback.selectionClick();
                          onSelectWeek(i);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    // The descriptive section crossfades AND its height
                    // animates so the layout never jumps.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: animation.drive(
                                Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey('plan-week-$selectedIndex'),
                          child: _WeekDescriptive(
                            week: selectedWeek,
                            onStartCurrentSession: onStartCurrentSession,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WEEK SCRUBBER — phase labels + tappable week chips
// ═══════════════════════════════════════════════════════════════
//
// Each week is a chip with real container affordance: subtle background,
// hairline border, italic numeral inside, status pip below. Selected
// chip is FILLED GOLD — unmistakable, same precious-yellow primary
// treatment as the CTA. Current week (when not selected) gets a gold
// ring + dot so the user can always find "this week" while browsing
// other weeks.
//
// Phase labels above respond to selection — the phase containing the
// selected week brightens to gold, others fade to faint. The chip row
// is broken into phase groups by vertical hairline separators.

class _WeekScrubber extends StatelessWidget {
  const _WeekScrubber({
    required this.weeks,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<PlanWeek> weeks;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final phases = _groupPhases(weeks);
    final selectedPhase = _phaseOf(phases, selectedIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Single dynamic phase header — updates with selection. Replaces
        // the prior 3-distributed labels (which overflowed for narrow
        // phase columns like the single-week deload). Always fits,
        // always readable; the crossfade on phase change makes navigation
        // feel intentional.
        _DynamicPhaseLabel(
          phaseIndex: selectedPhase,
          phaseCount: phases.length,
          phaseName: phases[selectedPhase].name,
        ),
        const SizedBox(height: 14),
        // Chip row — equal-width chips with phase separators.
        Row(
          children: [
            for (var p = 0; p < phases.length; p++) ...[
              for (var ii = 0; ii < phases[p].indices.length; ii++) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _WeekChip(
                      week: weeks[phases[p].indices[ii]],
                      isSelected: phases[p].indices[ii] == selectedIndex,
                      onTap: () => onSelect(phases[p].indices[ii]),
                    ),
                  ),
                ),
              ],
              if (p < phases.length - 1)
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }

  static List<_PhaseGroup> _groupPhases(List<PlanWeek> weeks) {
    final out = <_PhaseGroup>[];
    String? last;
    for (var i = 0; i < weeks.length; i++) {
      if (weeks[i].name != last) {
        out.add(_PhaseGroup(name: weeks[i].name, indices: [i]));
        last = weeks[i].name;
      } else {
        out.last.indices.add(i);
      }
    }
    return out;
  }

  static int _phaseOf(List<_PhaseGroup> phases, int weekIndex) {
    for (var i = 0; i < phases.length; i++) {
      if (phases[i].indices.contains(weekIndex)) return i;
    }
    return 0;
  }
}

class _PhaseGroup {
  _PhaseGroup({required this.name, required this.indices});
  final String name;
  final List<int> indices;
  int get count => indices.length;
}

/// Single dynamic phase header that sits above the chip row. Updates
/// with selection — the user always sees the phase context of whichever
/// week they've picked. AnimatedSwitcher crossfades the label on phase
/// change (the more common case of moving within the same phase has no
/// visual change here — just the chips animate).
///
/// Format: "PHASE 02 / 03 · PHÁT TRIỂN"
///   - "PHASE 02 / 03" — gold, tabular figures
///   - middle bullet — faint
///   - phase name — inverse ink, slightly larger
class _DynamicPhaseLabel extends StatelessWidget {
  const _DynamicPhaseLabel({
    required this.phaseIndex,
    required this.phaseCount,
    required this.phaseName,
  });

  final int phaseIndex; // 0-based
  final int phaseCount;
  final String phaseName;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ),
            ),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey('phase-$phaseIndex'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'PHASE ${(phaseIndex + 1).toString().padLeft(2, '0')} / '
            '${phaseCount.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: c.yellow,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: c.invInkFaint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              phaseName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.invInk,
              ),
            ),
          ),
          const Spacer(),
          // Subtle swipe affordance — small chevron pair fades in
          // suggesting horizontal navigation. Helps discovery of the
          // swipe gesture.
          Icon(
            Icons.swipe_rounded,
            size: 13,
            color: c.invInkFaint,
          ),
        ],
      ),
    );
  }
}

class _WeekChip extends StatefulWidget {
  const _WeekChip({
    required this.week,
    required this.isSelected,
    required this.onTap,
  });

  final PlanWeek week;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_WeekChip> createState() => _WeekChipState();
}

class _WeekChipState extends State<_WeekChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final week = widget.week;
    final isSelected = widget.isSelected;
    final isDone = week.status == WeekStatus.done;
    final isCurrent = week.status == WeekStatus.current;

    // Background tier
    final bg = isSelected
        ? c.yellow
        : isDone
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.025);

    // Border tier — current week always carries a gold ring so the user
    // can locate "this week" even while browsing other selections.
    final Color borderColor;
    final double borderWidth;
    if (isSelected) {
      borderColor = c.yellow;
      borderWidth = 1.5;
    } else if (isCurrent) {
      borderColor = c.yellow.withValues(alpha: 0.7);
      borderWidth = 1.5;
    } else if (isDone) {
      borderColor = Colors.white.withValues(alpha: 0.12);
      borderWidth = 1;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.18);
      borderWidth = 1;
    }

    final numeralColor = isSelected
        ? c.yellowInk
        : isDone
            ? c.invInkSoft
            : isCurrent
                ? c.invInk
                : c.invInkFaint;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 62,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.42),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.22),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                week.num.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.2,
                  height: 0.9,
                  color: numeralColor,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(height: 7),
              _ChipPip(
                isSelected: isSelected,
                isDone: isDone,
                isCurrent: isCurrent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipPip extends StatelessWidget {
  const _ChipPip({
    required this.isSelected,
    required this.isDone,
    required this.isCurrent,
  });

  final bool isSelected;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    if (isDone) {
      return Icon(
        Icons.check_rounded,
        size: 10,
        color: isSelected ? c.yellowInk : c.invInkSoft,
      );
    }
    if (isCurrent) {
      // Gold pulse dot — even when not selected, this helps the user
      // identify "today's week" inside the rail.
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: isSelected ? c.yellowInk : c.yellow,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.55),
                    blurRadius: 5,
                  ),
                ],
        ),
      );
    }
    // Future: hollow ring
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? c.yellowInk.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.32),
          width: 1.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WEEK DESCRIPTIVE — animated content swap
// ═══════════════════════════════════════════════════════════════

class _WeekDescriptive extends StatelessWidget {
  const _WeekDescriptive({
    required this.week,
    required this.onStartCurrentSession,
  });

  final PlanWeek week;
  final VoidCallback onStartCurrentSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(week: week),
          const SizedBox(height: 14),
          _Headline(week: week),
          const SizedBox(height: 16),
          _StatRow(week: week),
          if (week.coachLine != null) ...[
            const SizedBox(height: 20),
            _CoachVoice(quote: week.coachLine!),
          ],
          const SizedBox(height: 24),
          _StatusCta(
            week: week,
            onStartCurrentSession: onStartCurrentSession,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EYEBROW + HEADLINE
// ═══════════════════════════════════════════════════════════════

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.week});
  final PlanWeek week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final status = switch (week.status) {
      WeekStatus.current => 'tuần này',
      WeekStatus.done => 'đã hoàn tất',
      WeekStatus.future => 'sắp tới',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Sparkle(size: 12),
        const SizedBox(width: 10),
        Text(
          'TUẦN ${week.num.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: c.yellow,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '·',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: c.invInkFaint,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.1,
              color: c.invInkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.week});
  final PlanWeek week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final (line1, line2) = switch (week.status) {
      WeekStatus.done => (
          '${week.completed} / ${week.sessions}',
          'buổi đã xong.'
        ),
      WeekStatus.current => _splitFocus(week.bodyFocus, _currentTail(week)),
      WeekStatus.future => _splitFocus(week.name, 'sắp tới.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 48,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.8,
            height: 0.92,
            color: c.invInk,
          ),
        ),
        Text(
          line2,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 48,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.8,
            height: 0.92,
            color: c.invInk,
          ),
        ),
      ],
    );
  }

  static String _currentTail(PlanWeek week) {
    return week.completed < week.sessions ? 'tiếp tục.' : 'đã đủ.';
  }

  static (String, String) _splitFocus(String head, String tail) {
    final h = head.trim();
    final t = tail.trim();
    if (h.contains(' ')) {
      final parts = h.split(' ');
      return (parts.first, '${parts.skip(1).join(' ')} $t'.trim());
    }
    return (h, t);
  }
}

// ═══════════════════════════════════════════════════════════════
// STAT ROW
// ═══════════════════════════════════════════════════════════════

class _StatRow extends StatelessWidget {
  const _StatRow({required this.week});
  final PlanWeek week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final stats = <(IconData, String)>[
      (
        Icons.check_circle_outline_rounded,
        '${week.completed} / ${week.sessions} buổi'
      ),
      if (week.bodyFocus.isNotEmpty) (Icons.gps_fixed_rounded, week.bodyFocus),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          _Stat(icon: stats[i].$1, label: stats[i].$2),
          if (i < stats.length - 1)
            Container(width: 1, height: 14, color: c.borderDark),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.yellow),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COACH VOICE
// ═══════════════════════════════════════════════════════════════

class _CoachVoice extends StatelessWidget {
  const _CoachVoice({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.4,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _CoachMark(yellow: c.yellow, ink: c.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '“$quote”',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.15,
                height: 1.5,
                color: c.invInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachMark extends StatelessWidget {
  const _CoachMark({required this.yellow, required this.ink});
  final Color yellow;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _CoachPainter(yellow: yellow, ink: ink)),
    );
  }
}

class _CoachPainter extends CustomPainter {
  const _CoachPainter({required this.yellow, required this.ink});
  final Color yellow;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    Offset p(double x, double y) => Offset(x * scale, y * scale);
    canvas.drawCircle(p(9, 9), 8.5 * scale, Paint()..color = yellow);
    canvas.drawCircle(
      p(9, 9),
      8.5 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * scale
        ..color = ink,
    );
    final inkPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(p(9, 5.5), 1.1 * scale, Paint()..color = ink);
    canvas.drawLine(p(9, 6.6), p(9, 10), inkPaint);
    canvas.drawLine(p(6.5, 8), p(11.5, 8), inkPaint);
    canvas.drawLine(p(9, 10), p(7.5, 13), inkPaint);
    canvas.drawLine(p(9, 10), p(10.5, 13), inkPaint);
  }

  @override
  bool shouldRepaint(covariant _CoachPainter old) =>
      old.yellow != yellow || old.ink != ink;
}

// ═══════════════════════════════════════════════════════════════
// STATUS-AWARE CTA
// ═══════════════════════════════════════════════════════════════

class _StatusCta extends StatefulWidget {
  const _StatusCta({
    required this.week,
    required this.onStartCurrentSession,
  });

  final PlanWeek week;
  final VoidCallback onStartCurrentSession;

  @override
  State<_StatusCta> createState() => _StatusCtaState();
}

class _StatusCtaState extends State<_StatusCta> {
  bool _pressed = false;

  String _todayTitle() {
    for (final d in widget.week.days) {
      if (d.status == DayStatus.today) return d.title;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final week = widget.week;
    final isCurrent = week.status == WeekStatus.current;
    final todayTitle = _todayTitle();
    final enabled = isCurrent && week.completed < week.sessions;

    final label = switch (week.status) {
      WeekStatus.current => enabled
          ? todayTitle.isNotEmpty
              ? 'Bắt đầu $todayTitle'
              : 'Bắt đầu buổi tiếp theo'
          : 'Tuần đã đủ buổi',
      WeekStatus.done => 'Đã hoàn tất',
      WeekStatus.future => 'Mở khi đến tuần này',
    };

    final bg = enabled ? c.yellow : Colors.white.withValues(alpha: 0.06);
    final border = enabled
        ? null
        : Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.4);
    final fg = enabled ? c.yellowInk : c.invInkSoft;
    final knobBg = enabled ? c.ink : Colors.transparent;
    final knobBorder = enabled
        ? null
        : Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2);
    final knobFg = enabled ? c.yellow : c.invInkSoft;

    final knobIcon = switch (week.status) {
      WeekStatus.current =>
        enabled ? Icons.arrow_forward_rounded : Icons.check_rounded,
      WeekStatus.done => Icons.check_rounded,
      WeekStatus.future => Icons.lock_outline_rounded,
    };

    return GestureDetector(
      onTap: enabled ? widget.onStartCurrentSession : null,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: border,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.38),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.18),
                      blurRadius: 68,
                      offset: const Offset(0, 30),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: fg,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: knobBg,
                  shape: BoxShape.circle,
                  border: knobBorder,
                ),
                child: Icon(knobIcon, size: 19, color: knobFg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERIC HELPERS (inlined)
// ═══════════════════════════════════════════════════════════════

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });
  final Size size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _GrainTexture extends StatelessWidget {
  const _GrainTexture({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GrainPainter(opacity: opacity),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(91);
    final count = (size.width * size.height * 0.0009).round();
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * opacity;
      final tone = rng.nextDouble();
      paint.color =
          (tone > 0.5 ? Colors.white : Colors.black).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.opacity != opacity;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color: c.yellow)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.42, h * 0.58)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.42, h * 0.42)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

class _LightStatusBar extends StatelessWidget {
  const _LightStatusBar();

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox.shrink(),
    );
  }
}
