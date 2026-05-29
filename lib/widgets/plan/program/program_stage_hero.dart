// ProgramStageHero — the dark stage for the completion-anchored Plan.
//
// Composition (matches the shipped Stage Hero recipe — bleeds to the top edge,
// 36pt rounded base, warm-dark gradient, yellow + amber ambient glows, seed-91
// film grain, sparkles):
//
//   • inverted WordmarkHeader (trailing "Sổ tập" book icon)
//   • sparkle eyebrow      TUẦN 03 · NỀN TẢNG · đang tập   (block, never a date)
//   • italic display headline (2 lines)
//   • COMPLETION BEZEL     ● ─ ● ─ ◉ ─ ○ ─ ○ ─ ○ ┄ ◌      03 / 07
//       7 block marks, the current one breathing gold; tappable to browse
//   • block stat row       ✓ 1/3 buổi · ⦿ Chân & Core
//   • block coach note     (glass _CoachVoice)
//   • NEXT-UP entry        gold-edged glass: next session + the ONE halo CTA
//
// Completion model: there are NO dates. "TUẦN N" labels the block. Status is
// derived only from completion. The gold halo CTA appears ONLY for the genuine
// next session; browsing a done/upcoming block shows a disabled state instead,
// so the next session stays unmistakable.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/program_mock.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/responsive.dart';
import '../../../theme/vf_theme.dart';
import '../plan_typography.dart';
import '../wordmark_header.dart';
import 'program_atoms.dart';

class ProgramStageHero extends StatefulWidget {
  const ProgramStageHero({
    super.key,
    required this.program,
    required this.selectedIndex,
    required this.onSelectBlock,
    required this.onStartNext,
    this.userInitial = 'N',
    this.onAvatarTap,
    this.onMenuTap,
  });

  final ProgramPlan program;
  final int selectedIndex;
  final ValueChanged<int> onSelectBlock;
  final VoidCallback onStartNext;
  final String userInitial;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMenuTap;

  @override
  State<ProgramStageHero> createState() => _ProgramStageHeroState();
}

class _ProgramStageHeroState extends State<ProgramStageHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 250.0;
    final blocks = widget.program.blocks;
    if (velocity < -threshold && widget.selectedIndex < blocks.length - 1) {
      HapticFeedback.lightImpact();
      widget.onSelectBlock(widget.selectedIndex + 1);
    } else if (velocity > threshold && widget.selectedIndex > 0) {
      HapticFeedback.lightImpact();
      widget.onSelectBlock(widget.selectedIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final program = widget.program;
    final block = program.blocks[widget.selectedIndex];
    final isCurrent = block.status == ProgramStatus.current;
    final nextSession = isCurrent ? block.nextSession : null;

    return GestureDetector(
      onHorizontalDragEnd: _handleSwipe,
      behavior: HitTestBehavior.translucent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
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
                  child: ProgramAmbientGlow(
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
                  child: ProgramAmbientGlow(
                    size: const Size(440, 380),
                    color: const Color(0xFFCD7C45),
                    opacity: 0.18,
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(child: ProgramGrain(opacity: 0.05)),
              ),
              const Positioned(
                top: 230,
                right: 54,
                child: IgnorePointer(
                  child:
                      Opacity(opacity: 0.42, child: ProgramSparkle(size: 11)),
                ),
              ),
              const Positioned(
                top: 430,
                left: 34,
                child: IgnorePointer(
                  child: Opacity(opacity: 0.26, child: ProgramSparkle(size: 9)),
                ),
              ),

              // ─── Content ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(top: topInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ProgramLightStatusBar(),
                    WordmarkHeader(
                      inverted: true,
                      userInitial: widget.userInitial,
                      trailingIcon: Icons.menu_book_rounded,
                      trailingTooltip: 'Sổ tập',
                      onTrailingTap: widget.onMenuTap,
                      onAvatarTap: widget.onAvatarTap,
                    ),
                    SizedBox(height: r.gap(20)),

                    // Eyebrow + headline (crossfade on block change).
                    _crossfade(
                      keyValue: 'head-${widget.selectedIndex}',
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.w(24)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Eyebrow(block: block),
                            SizedBox(height: r.gap(14)),
                            _Headline(block: block),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: r.gap(24)),

                    // Completion bezel — the fixed selector.
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.w(22)),
                      child: _CompletionBezel(
                        blocks: program.blocks,
                        selectedIndex: widget.selectedIndex,
                        currentIndex: program.currentBlockIndex,
                        pulse: _pulse,
                        onSelect: (i) {
                          HapticFeedback.selectionClick();
                          widget.onSelectBlock(i);
                        },
                      ),
                    ),
                    SizedBox(height: r.gap(24)),

                    // Descriptive section (crossfade on block change).
                    AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _crossfade(
                        keyValue: 'desc-${widget.selectedIndex}',
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.w(24)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BlockStatRow(block: block),
                              SizedBox(height: r.gap(16)),
                              // One compact coach line per block (no card chrome).
                              ProgramCoachNote(
                                text: block.coachNote,
                                dark: true,
                                size: r.sp(13),
                                maxLines: 3,
                              ),
                              SizedBox(height: r.gap(20)),
                              if (nextSession != null)
                                _NextCta(
                                  session: nextSession,
                                  onStart: widget.onStartNext,
                                )
                              else
                                _BlockStatusPanel(block: block),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: r.gap(26)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crossfade({required String keyValue, required Widget child}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(keyValue), child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EYEBROW + HEADLINE
// ═══════════════════════════════════════════════════════════════

String _statusWord(ProgramStatus s) => switch (s) {
      ProgramStatus.current => 'đang tập',
      ProgramStatus.done => 'đã hoàn tất',
      ProgramStatus.upcoming => 'sắp tới',
    };

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.block});
  final ProgramBlock block;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return Row(
      children: [
        const ProgramSparkle(size: 13),
        SizedBox(width: r.w(10)),
        Text(
          'TUẦN ${block.blockNumber.toString().padLeft(2, '0')} · '
          '${block.phaseName.toUpperCase()}',
          style: beVietnamPro(
            size: r.sp(11),
            weight: FontWeight.w800,
            letterSpacing: 1.9,
            color: c.yellow,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        SizedBox(width: r.w(10)),
        Text('·',
            style: beVietnamPro(
                size: r.sp(11), weight: FontWeight.w800, color: c.invInkFaint)),
        SizedBox(width: r.w(10)),
        Flexible(
          child: Text(
            _statusWord(block.status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: frauncesItalic(
              size: r.sp(12),
              weight: FontWeight.w700,
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
  const _Headline({required this.block});
  final ProgramBlock block;

  (String, String) _lines() {
    switch (block.status) {
      case ProgramStatus.current:
        if (block.isDeload) return ('Nhẹ lại,', 'hồi sức.');
        if (block.phaseNumber >= 2) return ('Đẩy mạnh,', 'tiến lên.');
        return ('Giữ nhịp,', 'xây nền.');
      case ProgramStatus.done:
        return (
          '${block.sessionsDone} / ${block.sessionsTotal}',
          'buổi đã xong.'
        );
      case ProgramStatus.upcoming:
        if (block.isDeload) return ('Phục hồi,', 'sắp tới.');
        return ('${block.phaseName},', 'sắp tới.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final (line1, line2) = _lines();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: frauncesItalic(
            size: r.sp(46),
            weight: FontWeight.w800,
            letterSpacing: -2.6,
            height: 0.92,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        Text(
          line2,
          style: beVietnamPro(
            size: r.sp(46),
            weight: FontWeight.w800,
            letterSpacing: -2.6,
            height: 0.92,
            color: c.invInk,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BLOCK STAT ROW — completion-only progress + focus
// ═══════════════════════════════════════════════════════════════

class _BlockStatRow extends StatelessWidget {
  const _BlockStatRow({required this.block});
  final ProgramBlock block;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final stats = <(IconData, String)>[
      (
        Icons.check_circle_outline_rounded,
        '${block.sessionsDone}/${block.sessionsTotal} buổi'
      ),
      if (block.focusLabel.isNotEmpty)
        (Icons.gps_fixed_rounded, block.focusLabel),
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
    final r = Responsive.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.yellow),
        SizedBox(width: r.w(7)),
        Text(
          label,
          style: beVietnamPro(
            size: r.sp(13),
            weight: FontWeight.w700,
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
// NEXT CTA — one slim context line + the single halo launch button
// (full next-session detail lives in the session ledger below)
// ═══════════════════════════════════════════════════════════════

class _NextCta extends StatelessWidget {
  const _NextCta({required this.session, required this.onStart});
  final PlanSession session;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final title = session.title.isEmpty ? session.label : session.title;
    final meta = session.durationLabel.isEmpty
        ? title
        : '$title · ~${session.durationLabel}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TIẾP THEO',
              style: beVietnamPro(
                size: r.sp(10),
                weight: FontWeight.w800,
                letterSpacing: 1.9,
                color: c.yellow,
              ),
            ),
            SizedBox(width: r.w(10)),
            Expanded(
              child: Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: beVietnamPro(
                  size: r.sp(12.5),
                  weight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: c.invInkSoft,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.gap(12)),
        ProgramHaloCta(label: 'Bắt đầu ${session.label}', onTap: onStart),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BLOCK STATUS PANEL — disabled state when browsing a non-current block
// ═══════════════════════════════════════════════════════════════

class _BlockStatusPanel extends StatelessWidget {
  const _BlockStatusPanel({required this.block});
  final ProgramBlock block;

  @override
  Widget build(BuildContext context) {
    final isDone = block.status == ProgramStatus.done;
    return ProgramGlassPill(
      label: isDone ? 'Chặng đã hoàn tất' : 'Chưa tới chặng này',
      icon: isDone ? Icons.check_rounded : Icons.lock_outline_rounded,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPLETION BEZEL — 7 block marks + index labels + fraction
// ═══════════════════════════════════════════════════════════════

class _CompletionBezel extends StatelessWidget {
  const _CompletionBezel({
    required this.blocks,
    required this.selectedIndex,
    required this.currentIndex,
    required this.onSelect,
    required this.pulse,
  });

  final List<ProgramBlock> blocks;
  final int selectedIndex;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Animation<double> pulse;

  static const double _station = 26;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final n = blocks.length;
              final step = n > 1 ? (w - _station) / (n - 1) : 0.0;
              final centers = [
                for (var i = 0; i < n; i++) _station / 2 + step * i,
              ];
              final deloadIndex = blocks.indexWhere((b) => b.isDeload);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 26,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ConnectorPainter(
                              centers: centers,
                              deloadIndex: deloadIndex,
                              y: 13,
                              line: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < n; i++)
                              _BezelStation(
                                block: blocks[i],
                                isCurrent: i == currentIndex,
                                pulse: pulse,
                                onTap: () => onSelect(i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < n; i++)
                        SizedBox(
                          width: _station,
                          child: Center(
                            child: Text(
                              blocks[i].blockNumber.toString(),
                              style: beVietnamPro(
                                size: 10,
                                weight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: i == selectedIndex
                                    ? c.yellow
                                    : c.invInkFaint,
                                fontFeatures: VikaIvoryMain.tabularFigures,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        _BezelFraction(
          current: blocks[selectedIndex].blockNumber,
          total: blocks.length,
        ),
      ],
    );
  }
}

class _BezelFraction extends StatelessWidget {
  const _BezelFraction({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: current.toString().padLeft(2, '0'),
                style: beVietnamPro(
                  size: 18,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: c.yellow,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              TextSpan(
                text: ' / ${total.toString().padLeft(2, '0')}',
                style: beVietnamPro(
                  size: 13,
                  weight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: c.invInkFaint,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'KHỐI',
          style: beVietnamPro(
            size: 9,
            weight: FontWeight.w800,
            letterSpacing: 1.8,
            color: c.invInkFaint,
          ),
        ),
      ],
    );
  }
}

class _BezelStation extends StatelessWidget {
  const _BezelStation({
    required this.block,
    required this.isCurrent,
    required this.pulse,
    required this.onTap,
  });

  final ProgramBlock block;
  final bool isCurrent;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _CompletionBezel._station,
        height: 26,
        child: Center(child: _glyph(c)),
      ),
    );
  }

  Widget _glyph(VikaColors c) {
    if (isCurrent) {
      return AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final t = pulse.value;
          return Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.yellow, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: c.yellow.withValues(alpha: 0.30 + 0.30 * t),
                  blurRadius: 5 + 5 * t,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(color: c.yellow, shape: BoxShape.circle),
              ),
            ),
          );
        },
      );
    }
    if (block.status == ProgramStatus.done) {
      return Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: c.yellow,
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.black.withValues(alpha: 0.18), width: 1.2),
        ),
      );
    }
    if (block.isDeload) {
      return SizedBox(
        width: 11,
        height: 11,
        child: CustomPaint(
          painter: _DashedRingPainter(
            color: Colors.white.withValues(alpha: 0.30),
          ),
        ),
      );
    }
    // upcoming hollow ring
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.centers,
    required this.deloadIndex,
    required this.y,
    required this.line,
  });

  final List<double> centers;
  final int deloadIndex;
  final double y;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < centers.length - 1; i++) {
      final x1 = centers[i] + 7;
      final x2 = centers[i + 1] - 7;
      final isDeloadSegment = (i + 1) == deloadIndex;
      if (isDeloadSegment) {
        _dashedLine(canvas, Offset(x1, y), Offset(x2, y), paint);
      } else {
        canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 3.0;
    const gap = 3.0;
    final total = (b.dx - a.dx).abs();
    var drawn = 0.0;
    while (drawn < total) {
      final start = a.dx + drawn;
      final end = math.min(start + dash, b.dx);
      canvas.drawLine(Offset(start, a.dy), Offset(end, a.dy), paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.centers != centers || old.line != line;
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 0.6;
    const segments = 8;
    const sweep = (2 * math.pi) / segments;
    for (var i = 0; i < segments; i++) {
      final start = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}
