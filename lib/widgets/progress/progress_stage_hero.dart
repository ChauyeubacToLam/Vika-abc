// ProgressStageHero — the Tiến bộ tab's full-bleed dark canvas. Matches
// the Home / Plan / Library stage pattern (atmospherics, italic display
// headline, inverted wordmark) so all primary tabs read as one app.
//
// Embeds the period tabs (Tuần / Giai đoạn / Cả lộ trình) INSIDE the dark
// hero — same interactive-in-hero pattern as Library's filter chips.
// Tapping a tab updates the hero's subtitle in place (crossfade) AND
// the cream body below.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/wordmark_header.dart';
import 'period_tabs.dart';

class ProgressStageHero extends StatelessWidget {
  const ProgressStageHero({
    super.key,
    required this.period,
    required this.onPeriodChanged,
    required this.userInitial,
    required this.phaseLabel,
    required this.weekLabel,
    required this.watermark,
    this.avatarUrl,
    this.onAvatarTap,
  });

  final PeriodTab period;
  final ValueChanged<PeriodTab> onPeriodChanged;
  final String userInitial;
  final String? avatarUrl;

  /// e.g. 'PHASE 1 · TUẦN 3 / 7' — small editorial chapter label.
  final String phaseLabel;

  /// e.g. 'TỪ 21 / 4 · 4 TUẦN QUA' — period-aware date stamp.
  final String weekLabel;

  /// Huge faint italic chapter mark painted behind the headline (e.g. 'T5' /
  /// 'G2' / 'P3'). Data-bound to the active week/phase by the caller so the
  /// canvas always reads "this is where you are now"; the hero is stateless
  /// and has no snapshot, so it just renders what it's handed.
  final String watermark;

  final VoidCallback? onAvatarTap;

  String get _subtitle {
    return switch (period) {
      PeriodTab.week => 'Tuần này trong lộ trình. Đây là chặng hiện tại.',
      PeriodTab.phase => 'Cả giai đoạn này. Mỗi tuần một bước. Đây là chương.',
      PeriodTab.program =>
        'Cả lộ trình. Mỗi tuần một chương. Đây là toàn cảnh.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return ClipRRect(
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
            // Atmosphere — same recipe as Home / Plan / Library.
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
            const Positioned.fill(
              child: IgnorePointer(
                child: _GrainTexture(opacity: 0.05),
              ),
            ),
            const Positioned(
              top: 210,
              right: 48,
              child: IgnorePointer(
                child: Opacity(opacity: 0.42, child: _Sparkle(size: 11)),
              ),
            ),
            const Positioned(
              top: 380,
              left: 38,
              child: IgnorePointer(
                child: Opacity(opacity: 0.26, child: _Sparkle(size: 9)),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Stack(
                children: [
                  // Huge italic watermark numeral — e.g. "T5" reads as the
                  // chapter mark of the current week/phase. Very faint, so
                  // it's atmosphere rather than information.
                  Positioned(
                    top: 70,
                    right: -22,
                    child: IgnorePointer(
                      child: Text(
                        watermark,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 200,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -12,
                          height: 1,
                          color: c.invInk.withValues(alpha: 0.05),
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LightStatusBar(),
                      WordmarkHeader(
                        inverted: true,
                        userInitial: userInitial,
                        avatarUrl: avatarUrl,
                        trailingIcon: null,
                        onAvatarTap: onAvatarTap,
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PhasePill(label: phaseLabel),
                            const SizedBox(height: 14),
                            const _Headline(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: c.yellow,
                                    borderRadius: BorderRadius.circular(1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.yellow.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: AnimatedSize(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.topLeft,
                                    child: _AnimatedSwap(
                                      keyId: 'subtitle-${period.name}',
                                      child: Text(
                                        _subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'BeVietnamPro',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.italic,
                                          height: 1.45,
                                          color: c.invInkSoft,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 36),
                              child: Text(
                                weekLabel,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: c.invInkSoft.withValues(alpha: 0.55),
                                  fontFeatures: VikaIvoryMain.tabularFigures,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Inverted period tabs embedded in the dark hero —
                      // the interactive moment, mirroring Library filter
                      // chips and Plan week tabs.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _InvertedPeriodTabs(
                          value: period,
                          onChanged: onPeriodChanged,
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EYEBROW · HEADLINE
// ═══════════════════════════════════════════════════════════════

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: c.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.yellow.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Sparkle(size: 11),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.yellow,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // One-line italic display. "Tiến bộ" is a Vietnamese compound —
    // breaking it across lines reads as broken typography. FittedBox
    // lets the phrase scale down on narrow screens.
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          'Tiến bộ.',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 56,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.8,
            height: 0.95,
            color: c.invInk,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// INVERTED PERIOD TABS — dark surface variant
// ═══════════════════════════════════════════════════════════════

class _InvertedPeriodTabs extends StatelessWidget {
  const _InvertedPeriodTabs({
    required this.value,
    required this.onChanged,
  });
  final PeriodTab value;
  final ValueChanged<PeriodTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          for (final t in PeriodTab.values)
            Expanded(
              child: _InvPill(
                tab: t,
                active: t == value,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(t);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _InvPill extends StatelessWidget {
  const _InvPill({
    required this.tab,
    required this.active,
    required this.onTap,
  });
  final PeriodTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final label = switch (tab) {
      PeriodTab.week => 'Tuần',
      PeriodTab.phase => 'Giai đoạn',
      PeriodTab.program => 'Cả lộ trình',
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.36),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            color: active ? c.yellowInk : c.invInk,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ANIMATED SWAP — crossfade + slide on key change
// ═══════════════════════════════════════════════════════════════

class _AnimatedSwap extends StatelessWidget {
  const _AnimatedSwap({required this.keyId, required this.child});
  final String keyId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(keyId), child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERIC HELPERS — inlined per design-system rule
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
    final rng = math.Random(217);
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
