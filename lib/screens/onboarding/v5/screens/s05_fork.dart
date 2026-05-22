import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../fork_recommendation.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S05Fork extends StatefulWidget {
  const S05Fork({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S05Fork> createState() => _S05ForkState();
}

class _S05ForkState extends State<S05Fork> {
  late final String _recommendedId;
  late final ForkRecommendation _rec;

  @override
  void initState() {
    super.initState();
    _rec = recommendFork(widget.data);
    _recommendedId = _rec.fork;
    widget.data.forkRec = _rec;
    widget.data.fork ??= _recommendedId;
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final selected = widget.data.fork ?? _recommendedId;
    final selectedChoice = forkChoices[selected]!;
    final recIsSelected = selected == _recommendedId;
    final homeChoice = forkChoices['home']!;
    final yogaChoice = forkChoices['yoga']!;
    return V5Page(
      index: 7,
      onBack: widget.onBack,
      cta: V5PillCTA(
        label: 'Tiếp tục',
        enabled: widget.data.fork != null,
        onTap: widget.onNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: V5ScreenHeader(
              eyebrow: 'Lộ trình của bạn',
              title: 'Chọn cách\ntập.',
              size: r.isShort ? V5HeaderSize.medium : V5HeaderSize.large,
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space6)),
          SizedBox(
            height: r.pick(
              cozy: 148.0,
              short: 122.0,
              veryShort: 96.0,
              tall: 156.0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: V5.curve,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: _ForkHero(
                key: ValueKey(selectedChoice.id),
                choice: selectedChoice,
                isRecommended: recIsSelected,
              ),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space10, short: V5.space6)),
          Expanded(
            child: V5FadeIn(
              delay: const Duration(milliseconds: 220),
              slideY: 8,
              child: Row(
                // Stretch so both cards take the full row height and stay
                // visually balanced across the two training paths.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ForkOptionPanel(
                      choice: homeChoice,
                      selected: selected == homeChoice.id,
                      recommended: homeChoice.id == _recommendedId,
                      onTap: () =>
                          setState(() => widget.data.fork = homeChoice.id),
                    ),
                  ),
                  const SizedBox(width: V5.space8),
                  Expanded(
                    child: _ForkOptionPanel(
                      choice: yogaChoice,
                      selected: selected == yogaChoice.id,
                      recommended: yogaChoice.id == _recommendedId,
                      onTap: () =>
                          setState(() => widget.data.fork = yogaChoice.id),
                    ),
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

// ─────────────────────────────────────────────────────────────
// Fork hero — large dark editorial card showing the currently
// selected choice's details. Updates when user taps a card.
// ─────────────────────────────────────────────────────────────

class _ForkHero extends StatelessWidget {
  const _ForkHero({
    super.key,
    required this.choice,
    required this.isRecommended,
  });

  final ForkChoice choice;
  final bool isRecommended;

  List<String> get _chips => choice.id == 'yoga'
      ? ['Linh hoạt', 'Thả lỏng', choice.equipment]
      : ['Sức mạnh', 'Săn chắc', choice.equipment];

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final tight = r.isShort;
    return V5HeroCard(
      borderRadius: V5.radiusLg,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -40,
            child: V5AmbientGlow(
              size: const Size(220, 220),
              opacity: 0.22,
              color: V5.yellow,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              V5.space16,
              tight ? V5.space10 : V5.space14,
              V5.space16,
              tight ? V5.space10 : V5.space12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isRecommended)
                                const V5Sparkle(size: 12)
                              else
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: V5.invInkSoft,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: V5.space8),
                              Flexible(
                                child: Text(
                                  isRecommended ? 'VIKA GỢI Ý' : 'ĐÃ CHỌN',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V5.eyebrow(
                                    context,
                                    color: V5.invInkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: tight ? V5.space4 : V5.space8),
                          Text(
                            choice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tight
                                ? V5.titleLg(context, color: V5.invInk)
                                : V5.headline(context, color: V5.invInk),
                          ),
                          const SizedBox(height: V5.space4),
                          Text(
                            choice.sub,
                            maxLines: r.isVeryShort ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: V5.bodySm(context, color: V5.invInkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: V5.space14),
                    SizedBox(
                      width: tight ? 58 : 82,
                      height: tight ? 58 : 82,
                      child: _ForkMotionPreview(kind: choice.id),
                    ),
                  ],
                ),
                if (!tight)
                  Row(
                    children: _chips.asMap().entries.map((entry) {
                      final last = entry.key == _chips.length - 1;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: last ? 0 : V5.space6),
                          child: _FocusChip(label: entry.value),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForkMotionPreview extends StatelessWidget {
  const _ForkMotionPreview({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final icon = kind == 'yoga'
        ? Icons.self_improvement_rounded
        : Icons.fitness_center_rounded;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(V5.radiusLg),
        border: Border.all(color: V5.heroBorderHi),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ForkMotionPainter(isYoga: kind == 'yoga'),
            ),
          ),
          Center(child: Icon(icon, color: V5.yellow, size: 28)),
        ],
      ),
    );
  }
}

class _ForkMotionPainter extends CustomPainter {
  const _ForkMotionPainter({required this.isYoga});

  final bool isYoga;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = V5.yellow.withValues(alpha: 0.28);
    final path = Path();
    if (isYoga) {
      path
        ..moveTo(size.width * 0.18, size.height * 0.66)
        ..quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.18,
          size.width * 0.82,
          size.height * 0.66,
        );
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        Offset(size.width * 0.50, size.height * 0.30),
        size.width * 0.06,
        Paint()..color = V5.yellow.withValues(alpha: 0.36),
      );
    } else {
      for (var i = 0; i < 3; i++) {
        final y = size.height * (0.32 + i * 0.18);
        canvas.drawLine(
          Offset(size.width * 0.22, y),
          Offset(size.width * (0.56 + i * 0.10), y),
          paint,
        );
      }
      canvas.drawCircle(
        Offset(size.width * 0.72, size.height * 0.50),
        size.width * 0.08,
        Paint()..color = V5.yellow.withValues(alpha: 0.34),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ForkMotionPainter oldDelegate) =>
      oldDelegate.isYoga != isYoga;
}

class _FocusChip extends StatelessWidget {
  const _FocusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: V5.heroBorderHi),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: V5
            .eyebrow(context, color: V5.invInkSoft)
            .copyWith(letterSpacing: 0, height: 1),
      ),
    );
  }
}

class _ForkOptionPanel extends StatelessWidget {
  const _ForkOptionPanel({
    required this.choice,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final ForkChoice choice;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final dense = r.isShort;
    final tiny = r.size.height < 700;
    final icon = choice.id == 'yoga'
        ? Icons.self_improvement_rounded
        : Icons.fitness_center_rounded;
    final bullets = _panelHighlights(choice.id, tiny: tiny);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: V5.curveSharp,
        padding: EdgeInsets.fromLTRB(
          tiny ? 10 : 12,
          tiny ? 10 : 13,
          tiny ? 10 : 12,
          tiny ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? V5.ink : V5.surface,
          borderRadius: BorderRadius.circular(V5.radiusLg),
          border: Border.all(
            color: selected
                ? V5.ink
                : recommended
                    ? V5.yellow.withValues(alpha: 0.5)
                    : V5.border,
            width: selected || recommended ? 1.4 : 1,
          ),
          boxShadow: selected ? V5.elevation2 : V5.elevation1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: tiny ? 34 : 40,
                  height: tiny ? 34 : 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? V5.yellow.withValues(alpha: 0.16)
                        : V5.yellowSoft,
                    borderRadius: BorderRadius.circular(V5.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: tiny ? 18 : 21,
                    color: selected ? V5.yellow : V5.yellowDeep,
                  ),
                ),
                const Spacer(),
                V5CheckCircle(
                  selected: selected,
                  size: tiny ? 19 : 22,
                  dark: selected,
                ),
              ],
            ),
            SizedBox(height: tiny ? 8 : 10),
            Text(
              choice.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.titleSm(
                context,
                color: selected ? V5.invInk : V5.ink,
              ),
            ),
            const SizedBox(height: V5.space4),
            Text(
              choice.sub,
              maxLines: 1,
              style: V5
                  .caption(
                    context,
                    color: selected ? V5.invInkSoft : V5.inkSoft,
                  )
                  .copyWith(height: 1.22),
            ),
            SizedBox(height: tiny ? V5.space8 : V5.space10),
            if (recommended)
              _MiniTag(label: 'Gợi ý', dark: selected)
            else
              _MiniTag(
                label:
                    choice.equipment == 'Cần thảm' ? 'Cần thảm' : '0 dụng cụ',
                dark: selected,
              ),
            SizedBox(height: tiny ? V5.space8 : V5.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final bullet in bullets) ...[
                    _ForkBullet(label: bullet, dark: selected, dense: dense),
                    SizedBox(height: tiny ? 5 : 7),
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

class _ForkBullet extends StatelessWidget {
  const _ForkBullet({
    required this.label,
    required this.dark,
    required this.dense,
  });

  final String label;
  final bool dark;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(Icons.check_rounded,
              color: V5.yellow, size: dense ? 11 : 12),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: V5
                    .bodyXs(
                      context,
                      color: dark ? V5.invInkSoft : V5.inkSoft,
                    )
                    .copyWith(fontWeight: FontWeight.w700, height: 1.18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<String> _panelHighlights(String id, {required bool tiny}) {
  final items = id == 'yoga'
      ? const [
          'Mở khớp, giảm căng',
          'Thở chậm, thả lỏng',
          'Thả lỏng cuối ngày',
        ]
      : const [
          'Tăng sức mạnh',
          'Săn chắc, đốt năng lượng',
          'Tập gọn tại nhà',
        ];
  return items.take(tiny ? 2 : 3).toList(growable: false);
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? V5.yellow : V5.yellowSoft,
        borderRadius: BorderRadius.circular(V5.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: V5
            .eyebrow(context, color: dark ? V5.yellowInk : V5.yellowDeep)
            .copyWith(letterSpacing: 1.0),
      ),
    );
  }
}
