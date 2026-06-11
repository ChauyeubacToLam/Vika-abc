// StreakWeekStrip — the Progress "Chuỗi" centrepiece. A calm member of the
// page's ledger family (it shares the LedgerFrame shell with every other card),
// distinguished from inside by a gold hero numeral and a molten-gold run — NOT
// by a bespoke frame or maximalist ornament. It earns "expensive" through
// material craft, not density:
//
//   • the shared LedgerFrame (gold catch-light + paper grain + engraved rule)
//   • a GOLD-FOIL hero numeral (metallic shader + emboss) — the streak, in weeks
//   • a RECESSED GROOVE holding the run. Live-streak weeks are MOLTEN GOLD
//     INGOTS (vertical gradient, top specular cap, soft bloom), wired together
//     by a continuous gold FILAMENT. Past-active weeks are AGED-BRONZE ingots
//     (warm metal, never cold ink); rest weeks are debossed ghost ticks. A
//     quiet gold now-marker sits over the current week on a thin plumb line.
//   • a slow SPECULAR SWEEP travels across the gold once it settles.
//   • a single quiet forward-nudge line to the next tier — the milestone story
//     itself lives in the CỘT MỐC section above, not repeated here.
//
// Anchored at the user's first active week, capped at [maxWeeks]. One
// orchestrated reveal (bars spring up baseline-anchored, left→right), then a
// perpetual, restrained shimmer keeps the gold alive. Theme-aware throughout.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/streak_tier.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'ledger_frame.dart';

class StreakWeekStrip extends StatefulWidget {
  const StreakWeekStrip({
    super.key,
    required this.weeks,
    required this.streakWeeks,
    this.maxWeeks = 12,
  });

  /// Oldest-first; the last entry is the current week. Length 1..[maxWeeks].
  final List<bool> weeks;

  /// Consecutive active weeks up to now — the LIVE streak (the gold run).
  final int streakWeeks;

  /// Window cap. When [weeks] is shorter the row is anchored at the user's
  /// first active week (left endpoint reads "TUẦN ĐẦU").
  final int maxWeeks;

  @override
  State<StreakWeekStrip> createState() => _StreakWeekStripState();
}

class _StreakWeekStripState extends State<StreakWeekStrip>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _shimmer;

  // ─ Recessed groove geometry ─
  static const double _trayRadius = 16;
  static const double _pad = 10; // groove inner horizontal inset
  static const double _gap = 6; // between bars
  static const double _markerZone = 22; // space above groove for the marker
  static const double _channelH = 66; // recessed groove height
  static const double _topInset = 12; // bar headroom inside the groove
  static const double _baseInset = 10; // baseline lift off the groove floor

  double get _barMaxH => _channelH - _topInset - _baseInset; // ≈ 44

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..forward();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  // Index where the live streak run begins (== n if the current week is idle).
  int get _liveStart {
    final w = widget.weeks;
    var i = w.length;
    while (i > 0 && w[i - 1]) {
      i--;
    }
    return i;
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final n = widget.weeks.length;
    if (n == 0) return const SizedBox.shrink();

    final anchored = n < widget.maxWeeks;
    final hasStreak = widget.streakWeeks > 0;

    // Same shared shell as every other ledger leaf on the page — the streak is
    // a member of the family now, not a different screen. Its distinction comes
    // from the gold numeral + the molten ingot tray inside, not a bespoke frame.
    return LedgerFrame(
      radius: 28,
      grainSeed: 71,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(c, hasStreak),
          const SizedBox(height: 14),
          _hero(c, hasStreak),
          const SizedBox(height: 26),
          _tray(c, n),
          const SizedBox(height: 13),
          _endpoints(c, n: n, anchored: anchored),
          const SizedBox(height: 20),
          Container(height: 1, color: c.border),
          const SizedBox(height: 16),
          _nextNudge(c),
        ],
      ),
    );
  }

  // ── Eyebrow + thin gold rule ──
  Widget _eyebrow(VikaColors c, bool hasStreak) => Row(
        children: [
          _Spark(color: c.yellow, size: 11),
          const SizedBox(width: 8),
          Text(
            hasStreak ? 'CHUỖI HIỆN TẠI' : 'CHUỖI ĐÃ TẠM DỪNG',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.yellow.withValues(alpha: 0.5), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      );

  // ── Hero: gold-foil italic numeral + unit · tier ──
  Widget _hero(VikaColors c, bool hasStreak) {
    final tier = streakTierLabel(widget.streakWeeks);
    final numeral = '${widget.streakWeeks}';
    const numStyle = TextStyle(
      fontFamily: 'BeVietnamPro',
      fontSize: 78,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      letterSpacing: -4,
      height: 0.78,
      color: Colors.white,
      fontFeatures: VikaIvoryMain.tabularFigures,
    );

    final Widget hero = hasStreak
        ? Stack(
            children: [
              // Emboss shadow under the foil.
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  numeral,
                  style: numStyle.copyWith(
                    color: c.ink.withValues(alpha: c.isDark ? 0.55 : 0.20),
                  ),
                ),
              ),
              // Gold leaf.
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(c.yellow, Colors.white, 0.7)!,
                    c.yellow,
                    Color.lerp(c.yellow, const Color(0xFF8A5A12), 0.45)!,
                    Color.lerp(c.yellow, Colors.white, 0.35)!,
                  ],
                  stops: const [0.0, 0.42, 0.72, 1.0],
                ).createShader(r),
                child: Text(numeral, style: numStyle),
              ),
            ],
          )
        : Text(numeral, style: numStyle.copyWith(color: c.inkFaint));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        hero,
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TUẦN',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  height: 1.0,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 5),
              if (hasStreak)
                _tierChip(c, tier)
              else
                Text(
                  'tập lại để bắt đầu',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    height: 1.0,
                    color: c.inkSoft,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // A small "liên tiếp · {tier}" line with a gold tier seal.
  Widget _tierChip(VikaColors c, String tier) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'liên tiếp',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.0,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(7, 3.5, 8, 3.5),
            decoration: BoxDecoration(
              color: c.yellowGhost,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: c.yellow.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4.5,
                  height: 4.5,
                  decoration:
                      BoxDecoration(color: c.yellow, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  tier,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.0,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── Recessed groove: bars, filament, specular sweep, gem marker ──
  Widget _tray(VikaColors c, int n) {
    final liveStart = _liveStart;
    return SizedBox(
      height: _markerZone + _channelH,
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _shimmer]),
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _TrayPainter(
            weeks: widget.weeks,
            liveStart: liveStart,
            reveal: _reveal.value,
            shimmer: _shimmer.value,
            yellow: c.yellow,
            ink: c.ink,
            inkSoft: c.inkSoft,
            inkGhost: c.inkGhost,
            surface: c.bgRaised,
            isDark: c.isDark,
            markerZone: _markerZone,
            channelH: _channelH,
            trayRadius: _trayRadius,
            pad: _pad,
            gap: _gap,
            topInset: _topInset,
            baseInset: _baseInset,
            barMaxH: _barMaxH,
          ),
        ),
      ),
    );
  }

  // ── Endpoint labels ──
  Widget _endpoints(VikaColors c, {required int n, required bool anchored}) {
    if (n == 1) return Center(child: _nowLabel(c));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(anchored ? 'TUẦN ĐẦU' : '${widget.maxWeeks} TUẦN TRƯỚC',
            style: _axis(c)),
        _nowLabel(c),
      ],
    );
  }

  Widget _nowLabel(VikaColors c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TUẦN NÀY', style: _axis(c).copyWith(color: c.ink)),
          const SizedBox(width: 6),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: c.yellow, shape: BoxShape.circle),
          ),
        ],
      );

  TextStyle _axis(VikaColors c) => TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: c.inkFaint,
      );

  // ── Forward nudge — one quiet line to the next streak tier. (The gem
  // milestone ladder was removed: the CỘT MỐC section above already owns the
  // milestone story, so repeating it here read as two designs.) ──
  Widget _nextNudge(VikaColors c) {
    final s = widget.streakWeeks;
    if (s <= 0) {
      return Text(
        'Tập một buổi tuần này để bắt đầu chuỗi mới.',
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: c.inkSoft,
        ),
      );
    }
    final next = nextStreakMilestoneWeek(s);
    final nextLabel = streakTierLabel(next);
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: c.yellow, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Còn ${next - s} tuần nữa đến mốc "$nextLabel".',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: -0.1,
              color: c.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$s/$next',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: c.ink,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'TUẦN',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: c.inkFaint,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TRAY PAINTER — recessed cream groove + gold bars + sweep + marker
// ═══════════════════════════════════════════════════════════════

class _TrayPainter extends CustomPainter {
  _TrayPainter({
    required this.weeks,
    required this.liveStart,
    required this.reveal,
    required this.shimmer,
    required this.yellow,
    required this.ink,
    required this.inkSoft,
    required this.inkGhost,
    required this.surface,
    required this.isDark,
    required this.markerZone,
    required this.channelH,
    required this.trayRadius,
    required this.pad,
    required this.gap,
    required this.topInset,
    required this.baseInset,
    required this.barMaxH,
  });

  final List<bool> weeks;
  final int liveStart;
  final double reveal;
  final double shimmer;
  final Color yellow;
  final Color ink;
  final Color inkSoft;
  final Color inkGhost;
  final Color surface;
  final bool isDark;
  final double markerZone;
  final double channelH;
  final double trayRadius;
  final double pad;
  final double gap;
  final double topInset;
  final double baseInset;
  final double barMaxH;

  // Per-bar reveal factor: left→right stagger over the first ~half.
  double _grow(int i, int n) {
    final span = n <= 1 ? 0.0 : (i / (n - 1));
    final start = span * 0.5;
    final t = ((reveal - start) / 0.5).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = weeks.length;
    if (n == 0 || size.width <= 1 || size.height <= 1) return;

    // ── Recessed cream groove ──
    final trayRect = Rect.fromLTWH(0, markerZone, size.width, channelH);
    final trayRRect =
        RRect.fromRectAndRadius(trayRect, Radius.circular(trayRadius));

    canvas.drawRRect(
      trayRRect,
      Paint()..color = ink.withValues(alpha: isDark ? 0.18 : 0.045),
    );

    // Inner top shadow — sells the recess.
    canvas.save();
    canvas.clipRRect(trayRRect);
    canvas.drawRect(
      Rect.fromLTWH(0, markerZone, size.width, 14),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, markerZone),
          Offset(0, markerZone + 14),
          [ink.withValues(alpha: 0.07), ink.withValues(alpha: 0)],
        ),
    );
    canvas.restore();

    // Hairline groove edge.
    canvas.drawRRect(
      trayRRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.06),
    );

    // ── Bar slot maths — bars FILL the groove width evenly ──
    final availLeft = pad;
    final availW = size.width - pad * 2;
    final slotW = (availW - (n - 1) * gap) / n;
    if (slotW <= 0) return;
    double slotLeft(int i) => availLeft + i * (slotW + gap);
    double slotCx(int i) => slotLeft(i) + slotW / 2;

    final baseline = markerZone + channelH - baseInset;
    final radius = math.min(slotW * 0.30, 9.0).clamp(0.0, 9.0);

    final goldHi = Color.lerp(yellow, Colors.white, 0.5)!;
    final goldDeep = Color.lerp(yellow, const Color(0xFF7A4D10), 0.4)!;

    bool isLive(int i) => weeks[i] && i >= liveStart;

    // ── Gold filament wiring the live run (drawn behind the bars) ──
    final liveIdx = [for (var i = 0; i < n; i++) if (isLive(i)) i];
    if (liveIdx.length > 1) {
      final visibleLive = liveIdx.where((i) => _grow(i, n) > 0.05).toList();
      if (visibleLive.length > 1) {
        final x0 = slotCx(visibleLive.first);
        final x1 = slotCx(visibleLive.last);
        final fy = baseline + 1.5;
        canvas.drawLine(
          Offset(x0, fy),
          Offset(x1, fy),
          Paint()
            ..color = yellow.withValues(alpha: 0.4)
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawLine(
          Offset(x0, fy),
          Offset(x1, fy),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x0, fy),
              Offset(x1, fy),
              [goldDeep, yellow, goldHi, yellow],
              [0.0, 0.4, 0.7, 1.0],
            )
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Bars ──
    final goldRRects = <RRect>[];
    for (var i = 0; i < n; i++) {
      final grow = _grow(i, n);
      if (grow <= 0.001) continue;
      final active = weeks[i];
      final live = isLive(i);
      final left = slotLeft(i);

      if (!active) {
        // Rest week — a faint ghost stub on the groove floor.
        final stubH = 13.0 * grow;
        final stubRect = Rect.fromLTWH(left, baseline - stubH, slotW, stubH);
        final stub = RRect.fromRectAndRadius(stubRect, Radius.circular(radius));
        canvas.drawRRect(
          stub,
          Paint()..color = inkGhost.withValues(alpha: 0.45),
        );
        canvas.drawRRect(
          stub,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = inkSoft.withValues(alpha: 0.12),
        );
        continue;
      }

      final h = barMaxH * grow;
      final top = baseline - h;
      final barRect = Rect.fromLTWH(left, top, slotW, h);
      final rr = RRect.fromRectAndRadius(barRect, Radius.circular(radius));

      if (live) {
        // Soft cast shadow under the bar (lift off the groove).
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect.shift(const Offset(0, 5)),
            Radius.circular(radius),
          ),
          Paint()
            ..color = yellow.withValues(alpha: 0.34)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        // Molten gold body.
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = ui.Gradient.linear(
              barRect.topCenter,
              barRect.bottomCenter,
              [goldHi, yellow, goldDeep],
              [0.0, 0.42, 1.0],
            ),
        );
        // Top specular cap + left bevel light.
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(
          Rect.fromLTWH(left, top, slotW, h * 0.42),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, top),
              Offset(0, top + h * 0.42),
              [Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0)],
            ),
        );
        canvas.drawRect(
          Rect.fromLTWH(left, top, slotW * 0.24, h),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(left, 0),
              Offset(left + slotW * 0.24, 0),
              [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
            ),
        );
        canvas.restore();
        // Crisp top rim.
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.75
            ..color = goldHi.withValues(alpha: 0.6),
        );
        goldRRects.add(rr);
      } else {
        // Past-active week — an aged-bronze ingot, recessed behind the molten
        // live run. Warm metal (not cold ink) so the tray sits in the same
        // gold family as the rest of the page.
        final bronzeHi = Color.lerp(yellow, ink, 0.42)!;
        final bronzeDeep = Color.lerp(yellow, ink, 0.64)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect.shift(const Offset(0, 3)),
            Radius.circular(radius),
          ),
          Paint()
            ..color = ink.withValues(alpha: 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = ui.Gradient.linear(
              barRect.topCenter,
              barRect.bottomCenter,
              [bronzeHi, bronzeDeep],
            ),
        );
        // Faint top sheen.
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(
          Rect.fromLTWH(left, top, slotW, h * 0.4),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, top),
              Offset(0, top + h * 0.4),
              [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0)],
            ),
        );
        canvas.restore();
      }
    }

    // ── Travelling specular sweep across the gold (after it settles) ──
    if (goldRRects.isNotEmpty && reveal > 0.55) {
      final sv = shimmer;
      final phase = (sv / 0.6).clamp(0.0, 1.0);
      final intensity =
          sv < 0.6 ? math.sin(math.pi * phase) * reveal : 0.0;
      if (intensity > 0.01) {
        // Bounds of the gold run.
        var gl = double.infinity, gr = -double.infinity;
        var gt = double.infinity, gb = -double.infinity;
        for (final r in goldRRects) {
          gl = math.min(gl, r.left);
          gr = math.max(gr, r.right);
          gt = math.min(gt, r.top);
          gb = math.max(gb, r.bottom);
        }
        final band = (gr - gl) * 0.5 + 24;
        final sx = ui.lerpDouble(gl - band, gr + band, phase)!;
        canvas.save();
        final clip = Path();
        for (final r in goldRRects) {
          clip.addRRect(r);
        }
        canvas.clipPath(clip);
        // A tilted bright stripe, additive for a specular pop.
        final stripe = Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(sx - band, gt),
            Offset(sx + band, gb),
            [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.45 * intensity),
              Colors.white.withValues(alpha: 0),
            ],
            [0.36, 0.5, 0.64],
          );
        canvas.drawRect(
          Rect.fromLTRB(gl - band, gt, gr + band, gb),
          stripe,
        );
        canvas.restore();
      }
    }

    // ── Quiet gold now-marker over the current week ──
    final lastLive = weeks[n - 1] && (n - 1) >= liveStart;
    if (lastLive) {
      final markerIn = ((reveal - 0.74) / 0.26).clamp(0.0, 1.0);
      if (markerIn > 0.01) {
        final cx = slotCx(n - 1);
        final my = markerZone * 0.5 - (1 - markerIn) * 8;
        final ingotTop = baseline - barMaxH * _grow(n - 1, n);

        // Plumb line down to the ingot.
        canvas.drawLine(
          Offset(cx, my + 8),
          Offset(cx, ingotTop),
          Paint()
            ..color = yellow.withValues(alpha: 0.5 * markerIn)
            ..strokeWidth = 1.4,
        );

        // Halo.
        canvas.drawCircle(
          Offset(cx, my),
          11,
          Paint()
            ..color = yellow.withValues(alpha: 0.30 * markerIn)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );

        // A simple gold dot — a ring of card colour punches it off the tray,
        // then a gold fill with a small specular highlight. (The faceted gem
        // was retired with the rest of the streak's heavier ornament.)
        canvas.drawCircle(
          Offset(cx, my),
          7,
          Paint()..color = surface.withValues(alpha: markerIn),
        );
        canvas.drawCircle(
          Offset(cx, my),
          5,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx - 5, my - 5),
              Offset(cx + 5, my + 5),
              [goldHi, yellow, goldDeep],
              [0.0, 0.5, 1.0],
            ),
        );
        canvas.drawCircle(
          Offset(cx - 1.4, my - 1.4),
          1.6,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * markerIn),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrayPainter old) =>
      old.reveal != reveal ||
      old.shimmer != shimmer ||
      old.liveStart != liveStart ||
      old.weeks.length != weeks.length;
}

// ═══════════════════════════════════════════════════════════════
// SPARK — the brand's 4-point accent mark
// ═══════════════════════════════════════════════════════════════

class _Spark extends StatelessWidget {
  const _Spark({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _SparkPainter(color: color)),
      );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.color});
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
  bool shouldRepaint(covariant _SparkPainter old) => old.color != color;
}
