// LibraryStageHero — the Library tab's full-bleed dark canvas. Matches
// the Home + Plan stage pattern (atmospherics, italic display headline,
// inverted wordmark) so all three primary tabs read as one cohesive app.
//
// Embeds the filter chips INSIDE the dark hero — same interactive-in-
// hero pattern as Plan's week tabs. Tapping a chip updates the
// hero's eyebrow + subtitle in place (smooth crossfade) AND the cream
// body's rails below. Cause and effect in one glance.
//
// Atmospheric helpers (ambient glow, grain, sparkle) are inlined per
// the design-language rule — main-app widgets don't import from V5.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/wordmark_header.dart';
import 'library_filter_chips.dart';

class LibraryStageHero extends StatelessWidget {
  const LibraryStageHero({
    super.key,
    required this.filters,
    required this.selectedFilterId,
    required this.totalCount,
    required this.onSelectFilter,
    required this.userInitial,
    this.onAvatarTap,
    this.onSearchTap,
  });

  final List<LibraryFilter> filters;
  final String selectedFilterId;

  /// Total catalog count, used in the default eyebrow.
  final int totalCount;

  final ValueChanged<String> onSelectFilter;
  final String userInitial;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;

  LibraryFilter get _selected =>
      filters.firstWhere((f) => f.id == selectedFilterId,
          orElse: () => filters.first);

  String get _eyebrow {
    if (_selected.id == 'all') return 'THƯ VIỆN  ·  $totalCount BÀI';
    final n = _selected.count ?? 0;
    return '${_selected.label.toUpperCase()}  ·  $n BÀI';
  }

  String get _subtitle {
    return switch (_selected.id) {
      'program' =>
        'Lộ trình nhiều tuần. Mỗi tuần một mục tiêu rõ ràng.',
      'collection' =>
        'Bộ sưu tập ngắn. Tập nhanh, gọn, theo mục đích.',
      'exercise' =>
        'Bài tập riêng lẻ. Chọn theo phần thân hoặc cường độ.',
      'ai' =>
        'Camera Vika theo dõi tư thế của bạn theo thời gian thực.',
      'yoga' =>
        'Tư thế yoga để linh hoạt, thư giãn, cân bằng.',
      _ => 'Tìm bài tập, lộ trình, bộ sưu tập theo mục tiêu.',
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
            // Atmosphere — same recipe as Home/Plan
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
              top: 210,
              right: 56,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LightStatusBar(),
                  WordmarkHeader(
                    inverted: true,
                    userInitial: userInitial,
                    trailingIcon: Icons.search_rounded,
                    trailingTooltip: 'Tìm',
                    onTrailingTap: onSearchTap,
                    onAvatarTap: onAvatarTap,
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Eyebrow crossfades on filter change.
                        _AnimatedSwap(
                          keyId: 'eyebrow-${_selected.id}',
                          child: _Eyebrow(label: _eyebrow),
                        ),
                        const SizedBox(height: 14),
                        // Title is static — page identity.
                        const _Headline(),
                        const SizedBox(height: 12),
                        // Subtitle crossfades on filter change. Wrapped
                        // in AnimatedSize so its height change is
                        // animated too (different filter strings have
                        // different line counts).
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          child: _AnimatedSwap(
                            keyId: 'subtitle-${_selected.id}',
                            child: _Subtitle(text: _subtitle),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Inverted filter chips embedded in the dark hero —
                  // the interactive moment, mirroring Plan's week tabs.
                  LibraryFilterChips(
                    filters: filters,
                    selectedId: selectedFilterId,
                    onSelect: onSelectFilter,
                    inverted: true,
                  ),
                  const SizedBox(height: 26),
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
// EYEBROW · HEADLINE · SUBTITLE
// ═══════════════════════════════════════════════════════════════

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Sparkle(size: 12),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: c.yellow,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // One-line italic display. "Khám phá" is a compound — breaking it
    // mid-phrase reads weird in Vietnamese, so the entire phrase stays
    // on one line and FittedBox lets it scale down on narrow screens.
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          'Khám phá.',
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

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: c.invInkSoft,
      ),
    );
  }
}

/// Tiny wrapper that crossfades + slides its [child] when [keyId]
/// changes. Used for the eyebrow and subtitle so they react to filter
/// selection.
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
      child: KeyedSubtree(
        key: ValueKey(keyId),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERIC HELPERS (inlined — no v5_primitives import)
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
    final rng = math.Random(113);
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
