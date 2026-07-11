import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

/// S02 — Mirror. A story carousel of pain points presented as full-bleed
/// dark cards the user swipes through. Each card lingers on one quote and
/// invites a single confirming tap. Replaces the old "header + list of
/// choices" layout, which read as a form rather than a moment.
class S02Mirror extends StatefulWidget {
  const S02Mirror({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S02Mirror> createState() => _S02MirrorState();
}

class _S02MirrorState extends State<S02Mirror> {
  static const _stories = <_PainStory>[
    _PainStory(
      id: 'form_uncertainty',
      eyebrow: 'Tập theo video',
      quote: 'Tập theo video, nhưng không biết mình làm có đúng không.',
      visual: _PainVisualKind.mirror,
    ),
    _PainStory(
      id: 'generic_apps',
      eyebrow: 'App tập đại trà',
      quote: 'Tập theo app đại trà, không có lộ trình riêng cho mình.',
      visual: _PainVisualKind.generic,
    ),
    _PainStory(
      id: 'pt_expensive',
      eyebrow: 'PT 1-1',
      quote: 'Mong có người hướng dẫn tập cho đúng, nhưng chi phí PT lại quá cao.',
      visual: _PainVisualKind.cost,
    ),
    _PainStory(
      id: 'solo_demotivation',
      eyebrow: 'Tập một mình',
      quote: 'Tuần đầu đầy nhiệt huyết. Càng về sau càng mất động lực do tập mà không có hiệu quả.',
      visual: _PainVisualKind.fade,
    ),
  ];

  late final PageController _pc;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  bool get _canContinue => widget.data.problemResonance.isNotEmpty;
  int get _markedCount => widget.data.problemResonance.length;

  void _toggle(String id, {required int index}) {
    final wasSelected = widget.data.problemResonance.contains(id);
    setState(() {
      if (wasSelected) {
        widget.data.problemResonance.remove(id);
      } else {
        widget.data.problemResonance.add(id);
      }
      // Keep canonical order matching _stories.
      widget.data.problemResonance = [
        for (final s in _stories)
          if (widget.data.problemResonance.contains(s.id)) s.id,
      ];
    });
    if (!wasSelected && index < _stories.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted || !_pc.hasClients) return;
        _pc.animateToPage(
          index + 1,
          duration: const Duration(milliseconds: 340),
          curve: V5.curve,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);

    return V5Page(
      index: 2,
      onBack: widget.onBack,
      backgroundLayers: const [
        Positioned(
          top: -160,
          left: -120,
          child: V5AmbientGlow(
            size: Size(380, 380),
            opacity: 0.10,
            color: V5.yellow,
          ),
        ),
      ],
      cta: V5PillCTA(
        label: _canContinue
            ? 'Tiếp tục với $_markedCount điều đã chọn'
            : (_index < _stories.length - 1
                ? 'Vuốt để xem tiếp'
                : 'Chọn nếu bạn từng thấy vậy'),
        disabledLabel: 'Chạm để chọn',
        enabled: _canContinue,
        onTap: widget.onNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5FadeIn(
            slideY: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn thấy mình ở đâu?',
                  style: r.isShort ? V5.titleLg(context) : V5.headline(context),
                ),
                SizedBox(height: r.pick(cozy: V5.space8, short: V5.space6)),
                Text(
                  'Chạm để chọn. Vuốt sang để xem thêm.',
                  style: V5.bodySm(context, color: V5.inkSoft),
                ),
              ],
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
          Expanded(
            child: V5FadeIn(
              delay: const Duration(milliseconds: 140),
              slideY: 14,
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _stories.length,
                itemBuilder: (context, i) {
                  final story = _stories[i];
                  final marked =
                      widget.data.problemResonance.contains(story.id);
                  return _StoryCard(
                    story: story,
                    position: i + 1,
                    total: _stories.length,
                    marked: marked,
                    isLast: i == _stories.length - 1,
                    onMark: () => _toggle(story.id, index: i),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space16, short: V5.space12)),
          _ProgressDots(count: _stories.length, index: _index),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Story model
// ─────────────────────────────────────────────────────────────

enum _PainVisualKind { mirror, generic, cost, fade }

class _PainStory {
  const _PainStory({
    required this.id,
    required this.eyebrow,
    required this.quote,
    required this.visual,
  });

  final String id;
  final String eyebrow;
  final String quote;
  final _PainVisualKind visual;
}

// ─────────────────────────────────────────────────────────────
// Story card — full-bleed dark hero, one pain per card
// ─────────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.position,
    required this.total,
    required this.marked,
    required this.isLast,
    required this.onMark,
  });

  final _PainStory story;
  final int position;
  final int total;
  final bool marked;
  final bool isLast;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          onMark();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: V5.curveSharp,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V5.radiusXl),
            boxShadow: marked ? V5.yellowGlow(0.16) : null,
          ),
          child: V5HeroCard(
            borderRadius: V5.radiusXl,
            elevation: marked ? 3 : 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Soft accent glow per card.
                Positioned(
                  right: -80,
                  top: -80,
                  child: V5AmbientGlow(
                    size: const Size(260, 260),
                    opacity: marked ? 0.28 : 0.20,
                    color: V5.yellow,
                  ),
                ),
                const Positioned.fill(
                  child: V5Texture(opacity: 0.05, density: 1.2),
                ),
                // Selected check overlay — sits in top-right when marked.
                if (marked)
                  Positioned(
                    top: r.pick(cozy: 18.0, short: 14.0),
                    right: r.pick(cozy: 18.0, short: 14.0),
                    child: _SelectedMark(),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.pick(cozy: 24.0, short: 20.0, veryShort: 18.0),
                    r.pick(cozy: 22.0, short: 16.0, veryShort: 12.0),
                    r.pick(cozy: 24.0, short: 20.0, veryShort: 18.0),
                    r.pick(cozy: 22.0, short: 16.0, veryShort: 12.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: V5.yellow.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(V5.radiusFull),
                              border: Border.all(
                                color: V5.yellow.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              '${position.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                              style: V5
                                  .eyebrow(context, color: V5.yellow)
                                  .copyWith(letterSpacing: 1.2),
                            ),
                          ),
                          const SizedBox(width: V5.space10),
                          Expanded(
                            child: Text(
                              story.eyebrow.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.eyebrow(context, color: V5.invInkSoft),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: r.pick(cozy: V5.space16, short: V5.space10),
                      ),
                      // Visual — the focal element, takes most of the card.
                      Expanded(
                        flex: r.isShort ? 5 : 6,
                        child: _PainVisual(kind: story.visual),
                      ),
                      SizedBox(
                        height: r.pick(cozy: V5.space20, short: V5.space12),
                      ),
                      // Quote — centered, tight, no decorative bar.
                      Text(
                        story.quote,
                        textAlign: TextAlign.center,
                        style: V5.text(
                          context,
                          size: r.pick(
                            cozy: 22.0,
                            short: 19.0,
                            veryShort: 17.0,
                          ),
                          weight: FontWeight.w700,
                          color: V5.invInk,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(
                        height: r.pick(cozy: V5.space14, short: V5.space10),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _StorySelectPill(
                          key: ValueKey(marked),
                          marked: marked,
                          isLast: isLast,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StorySelectPill extends StatelessWidget {
  const _StorySelectPill({
    super.key,
    required this.marked,
    required this.isLast,
  });

  final bool marked;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: V5.space14,
        vertical: V5.space10,
      ),
      decoration: BoxDecoration(
        color: marked ? V5.yellow : Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(
          color: marked ? V5.yellow : Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: marked ? V5.yellowGlow(0.18) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            marked ? Icons.check_rounded : Icons.touch_app_rounded,
            size: 16,
            color: marked ? V5.yellowInk : V5.yellow,
          ),
          const SizedBox(width: V5.space8),
          Flexible(
            child: Text(
              marked ? 'Đã chọn' : (isLast ? 'Chọn điều này' : 'Đúng với tôi'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5
                  .titleSm(
                    context,
                    color: marked ? V5.yellowInk : V5.invInk,
                  )
                  .copyWith(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: V5.yellow,
        shape: BoxShape.circle,
        boxShadow: V5.yellowGlow(0.24),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check_rounded, color: V5.yellowInk, size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Progress dots
// ─────────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: V5.curveSharp,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? V5.ink : V5.ink.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(V5.radiusFull),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pain visual — abstract canvas illustration per story
// ─────────────────────────────────────────────────────────────

class _PainVisual extends StatelessWidget {
  const _PainVisual({required this.kind});

  final _PainVisualKind kind;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PainPainter(kind: kind),
        );
      },
    );
  }
}

class _PainPainter extends CustomPainter {
  _PainPainter({required this.kind});

  final _PainVisualKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _PainVisualKind.mirror:
        _paintMirror(canvas, size);
        break;
      case _PainVisualKind.generic:
        _paintGeneric(canvas, size);
        break;
      case _PainVisualKind.cost:
        _paintCost(canvas, size);
        break;
      case _PainVisualKind.fade:
        _paintFade(canvas, size);
        break;
    }
  }

  // Mirror: a clean form-check frame. The posture line is abstract on
  // purpose; it should feel like coaching feedback, not a strange figure.
  void _paintMirror(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final frame = Rect.fromCenter(
      center: Offset(cx, cy),
      width: math.min(w * 0.82, h * 1.08),
      height: h * 0.72,
    );

    final r = RRect.fromRectAndRadius(frame, const Radius.circular(14));
    canvas.drawRRect(
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    final floorY = frame.bottom - frame.height * 0.16;
    canvas.drawLine(
      Offset(frame.left + 14, floorY),
      Offset(frame.right - 14, floorY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 1,
    );

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(frame.left + frame.width * 0.18, frame.top + 14),
      Offset(frame.left + frame.width * 0.18, floorY),
      guidePaint,
    );

    final jointPaint = Paint()..color = Colors.white.withValues(alpha: 0.82);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final shoulder = Offset(
      frame.left + frame.width * 0.44,
      frame.top + frame.height * 0.26,
    );
    final hip = Offset(
      frame.left + frame.width * 0.54,
      frame.top + frame.height * 0.52,
    );
    final knee = Offset(
      frame.left + frame.width * 0.40,
      frame.top + frame.height * 0.66,
    );
    final ankle = Offset(frame.left + frame.width * 0.58, floorY);
    canvas.drawLine(shoulder, hip, linePaint);
    canvas.drawLine(hip, knee, linePaint);
    canvas.drawLine(knee, ankle, linePaint);
    for (final p in [shoulder, hip, knee, ankle]) {
      canvas.drawCircle(p, 5, jointPaint);
    }

    final arcRect = Rect.fromCircle(center: hip, radius: frame.width * 0.16);
    canvas.drawArc(
      arcRect,
      0.62 * math.pi,
      0.38 * math.pi,
      false,
      Paint()
        ..color = V5.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      hip,
      frame.width * 0.18,
      Paint()
        ..color = V5.yellow.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(frame.right - 74, frame.top + 16, 54, 24),
      const Radius.circular(999),
    );
    canvas.drawRRect(badge, Paint()..color = V5.yellow.withValues(alpha: 0.18));
    canvas.drawRRect(
      badge,
      Paint()
        ..color = V5.yellow.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'FORM',
        style: TextStyle(
          color: V5.yellow,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        badge.outerRect.center.dx - tp.width / 2,
        badge.outerRect.center.dy - tp.height / 2,
      ),
    );
  }

  // Generic: repeated plan cards. Cleaner than a row of people, and closer
  // to the actual product problem: generic programming.
  void _paintGeneric(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cardW = w * 0.68;
    final cardH = h * 0.22;
    final left = (w - cardW) / 2;
    final top = h * 0.18;

    for (var i = 0; i < 3; i++) {
      final y = top + i * (cardH * 0.72);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * 4, y, cardW, cardH),
        const Radius.circular(13),
      );
      final active = i == 1;
      canvas.drawRRect(
        rect,
        Paint()
          ..color = active
              ? V5.yellow.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.055),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = active
              ? V5.yellow.withValues(alpha: 0.36)
              : Colors.white.withValues(alpha: 0.14),
      );
      canvas.drawLine(
        Offset(rect.outerRect.left + 18, rect.outerRect.top + cardH * 0.38),
        Offset(rect.outerRect.right - 28, rect.outerRect.top + cardH * 0.38),
        Paint()
          ..color = active ? V5.yellow : Colors.white.withValues(alpha: 0.42)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(rect.outerRect.left + 18, rect.outerRect.top + cardH * 0.62),
        Offset(rect.outerRect.right - 64, rect.outerRect.top + cardH * 0.62),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    final tag = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.82),
        width: math.min(126, w * 0.70),
        height: 28,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(
        tag, Paint()..color = Colors.white.withValues(alpha: 0.06));
    canvas.drawRRect(
      tag,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'cùng một lộ trình',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.64),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        tag.outerRect.center.dx - tp.width / 2,
        tag.outerRect.center.dy - tp.height / 2,
      ),
    );
  }

  // Cost: stacked coin-disc with a lock symbol drawn in negative space
  void _paintCost(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final coinR = math.min(w, h) * 0.30;

    // 3 stacked coins, ascending
    for (var i = 2; i >= 0; i--) {
      final offsetY = i * (coinR * 0.18);
      final faceColor =
          i == 0 ? V5.yellow : Colors.white.withValues(alpha: 0.16 - i * 0.04);
      final rim = Paint()
        ..color = i == 0
            ? V5.yellowDeep.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy + offsetY - coinR * 0.10),
          width: coinR * 2,
          height: coinR * 0.6,
        ),
        Paint()..color = faceColor,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy + offsetY - coinR * 0.10),
          width: coinR * 2,
          height: coinR * 0.6,
        ),
        rim,
      );
    }

    // Padlock on top coin
    final lockCx = cx;
    final lockCy = cy - coinR * 0.45;
    final lockW = coinR * 0.7;
    final lockH = coinR * 0.55;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(lockCx, lockCy),
          width: lockW,
          height: lockH,
        ),
        Radius.circular(lockW * 0.18),
      ),
      Paint()..color = V5.yellowInk,
    );
    // Lock shackle
    final shackleR = lockW * 0.30;
    final shackleRect = Rect.fromCenter(
      center: Offset(lockCx, lockCy - lockH * 0.45),
      width: shackleR * 2,
      height: shackleR * 2,
    );
    canvas.drawArc(
      shackleRect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = V5.yellowInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    // Keyhole
    canvas.drawCircle(
      Offset(lockCx, lockCy),
      lockW * 0.10,
      Paint()..color = V5.yellow,
    );
    final keyholePath = Path()
      ..moveTo(lockCx - lockW * 0.05, lockCy)
      ..lineTo(lockCx + lockW * 0.05, lockCy)
      ..lineTo(lockCx + lockW * 0.07, lockCy + lockH * 0.18)
      ..lineTo(lockCx - lockW * 0.07, lockCy + lockH * 0.18)
      ..close();
    canvas.drawPath(keyholePath, Paint()..color = V5.yellow);
  }

  // Fade: a line chart of motivation that drops off after a strong start.
  void _paintFade(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = w * 0.10;
    final right = w * 0.90;
    final top = h * 0.18;
    final bottom = h * 0.82;

    // Grid hairlines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + (bottom - top) * i / 3;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    // Motivation curve — strong start, gentle plateau, sharp dropoff
    final path = Path();
    const pts = 32;
    Offset? lastP;
    for (var i = 0; i <= pts; i++) {
      final t = i / pts;
      final x = left + (right - left) * t;
      // Piecewise: rise 0..0.2, plateau 0.2..0.55, fall 0.55..1
      double y;
      if (t < 0.2) {
        final s = t / 0.2;
        y = bottom -
            (bottom - top) * (0.15 + 0.65 * Curves.easeOutCubic.transform(s));
      } else if (t < 0.55) {
        final s = (t - 0.2) / 0.35;
        y = bottom - (bottom - top) * (0.80 + 0.05 * math.sin(s * math.pi * 2));
      } else {
        final s = (t - 0.55) / 0.45;
        y = bottom -
            (bottom - top) * (0.85 - 0.78 * Curves.easeInQuart.transform(s));
      }
      final p = Offset(x, y);
      if (lastP == null) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      lastP = p;
    }

    // Area fill
    final areaPath = Path.from(path)
      ..lineTo(right, bottom)
      ..lineTo(left, bottom)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            V5.yellow.withValues(alpha: 0.32),
            V5.yellow.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(left, top, right - left, bottom - top)),
    );

    // Stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = V5.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Marker at the peak
    final peakX = left + (right - left) * 0.32;
    final peakY = top + (bottom - top) * 0.12;
    canvas.drawCircle(
      Offset(peakX, peakY),
      5,
      Paint()..color = V5.yellow,
    );
    canvas.drawCircle(
      Offset(peakX, peakY),
      5,
      Paint()
        ..color = V5.heroBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Marker at the bottom-right (where motivation drops)
    final endX = left + (right - left) * 0.96;
    final endY = bottom - (bottom - top) * 0.07;
    canvas.drawCircle(
      Offset(endX, endY),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _PainPainter old) => old.kind != kind;
}
