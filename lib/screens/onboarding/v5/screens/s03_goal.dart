import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S03Goal extends StatefulWidget {
  const S03Goal({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S03Goal> createState() => _S03GoalState();
}

class _S03GoalState extends State<S03Goal> {
  bool get _canContinue =>
      widget.data.goal != null && widget.data.duration != null;

  V5GoalOption? get _selected {
    final id = widget.data.goal;
    if (id == null) return null;
    for (final option in goalOptions) {
      if (option.id == id) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    final r = V5Responsive.of(context);
    final majorGap = r.pick(
      cozy: V5.space14,
      short: V5.space8,
      veryShort: V5.space6,
      tall: V5.space16,
    );
    final minorGap = r.pick(
      cozy: V5.space8,
      short: V5.space6,
      veryShort: V5.space4,
    );
    final gridSpacing = r.pick(
      cozy: V5.space10,
      short: V5.space8,
      veryShort: V5.space6,
    );
    final goalAspectRatio = r.pick(
      cozy: 2.45,
      short: 3.0,
      veryShort: 3.25,
      tall: 2.35,
    );
    final hero = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: V5.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
      child: sel == null
          ? const _GoalEmptyHero(key: ValueKey('empty'))
          : _GoalHero(
              key: ValueKey(sel.id),
              option: sel,
            ),
    );
    final goalGrid = GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
      childAspectRatio: goalAspectRatio,
      children: goalOptions.asMap().entries.map((entry) {
        final i = entry.key;
        final option = entry.value;
        final selected = widget.data.goal == option.id;
        return V5FadeIn(
          delay: Duration(milliseconds: 80 + i * 60),
          slideY: 8,
          child: _GoalChip(
            option: option,
            selected: selected,
            onTap: () => setState(() => widget.data.goal = option.id),
          ),
        );
      }).toList(),
    );
    final experienceSelector = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusLg),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: Row(
        children: durationOptions.map((duration) {
          final selected = widget.data.duration == duration.id;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => widget.data.duration = duration.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: V5.curveSharp,
                constraints: BoxConstraints(
                  minHeight: r.isVeryShort ? 38 : 46,
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected ? V5.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(V5.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  duration.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5
                      .bodySm(
                        context,
                        color: selected ? V5.invInk : V5.ink,
                      )
                      .copyWith(fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    return V5Page(
      index: 5,
      onBack: widget.onBack,
      cta: V5PillCTA(
        label: 'Tiếp tục',
        enabled: _canContinue,
        onTap: widget.onNext,
        bottom: math.max(32, r.viewPadding.bottom + 12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (r.isTablet && r.size.width > r.size.height) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const V5ScreenHeader(
                  eyebrow: 'Mục tiêu 4 tuần',
                  title: 'Bạn muốn đạt\nđược gì?',
                  size: V5HeaderSize.medium,
                ),
                SizedBox(height: majorGap),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: hero),
                      SizedBox(width: majorGap),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              goalGrid,
                              SizedBox(height: majorGap),
                              Text(
                                'KINH NGHIỆM',
                                style: V5.eyebrow(
                                  context,
                                  color: V5.inkSoft,
                                ),
                              ),
                              SizedBox(height: minorGap),
                              experienceSelector,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          if (r.size.width > r.size.height && constraints.maxHeight < 420) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  V5ScreenHeader(
                    eyebrow: 'Mục tiêu 4 tuần',
                    title: 'Bạn muốn đạt\nđược gì?',
                    size: V5HeaderSize.medium,
                  ),
                  SizedBox(height: majorGap),
                  SizedBox(height: 156, child: hero),
                  SizedBox(height: majorGap),
                  goalGrid,
                  SizedBox(height: majorGap),
                  Text(
                    'KINH NGHIỆM',
                    style: V5.eyebrow(context, color: V5.inkSoft),
                  ),
                  SizedBox(height: minorGap),
                  experienceSelector,
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V5ScreenHeader(
                eyebrow: 'Mục tiêu 4 tuần',
                title: 'Bạn muốn đạt\nđược gì?',
                size: r.isShort ? V5HeaderSize.medium : V5HeaderSize.large,
              ),
              SizedBox(height: majorGap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bodyConstraints) {
                    final cardWidth =
                        (bodyConstraints.maxWidth - gridSpacing) / 2;
                    final gridHeight =
                        (cardWidth / goalAspectRatio) * 2 + gridSpacing;
                    final selectorHeight = 8 + (r.isVeryShort ? 38.0 : 46.0);
                    final lowerHeight = majorGap +
                        gridHeight +
                        majorGap +
                        12 +
                        minorGap +
                        selectorHeight;
                    final bannerHeight = math.max(
                      0.0,
                      bodyConstraints.maxHeight - lowerHeight - 6,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: bannerHeight, child: hero),
                        SizedBox(height: majorGap),
                        goalGrid,
                        SizedBox(height: majorGap),
                        Text(
                          'KINH NGHIỆM',
                          style: V5.eyebrow(context, color: V5.inkSoft),
                        ),
                        SizedBox(height: minorGap),
                        experienceSelector,
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Goal hero (selected) — fills available space, big editorial stat
// ─────────────────────────────────────────────────────────────

class _GoalHero extends StatelessWidget {
  const _GoalHero({super.key, required this.option});

  final V5GoalOption option;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final dense = r.isShort;
    final icon = switch (option.id) {
      'health' => Icons.favorite_rounded,
      'body' => Icons.straighten_rounded,
      'strength' => Icons.fitness_center_rounded,
      'flexible' => Icons.self_improvement_rounded,
      _ => Icons.flag_rounded,
    };
    return V5HeroCard(
      borderRadius: V5.radiusXl,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -60,
            child: V5AmbientGlow(
              size: const Size(280, 280),
              opacity: 0.22,
              color: V5.yellow,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              dense ? 16 : 22,
              dense ? 12 : 18,
              dense ? 16 : 22,
              dense ? 12 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    V5Sparkle(size: dense ? 10 : 12),
                    SizedBox(width: dense ? V5.space6 : V5.space8),
                    Expanded(
                      child: Text(
                        'SAU 4 TUẦN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.eyebrow(context, color: V5.invInkSoft),
                      ),
                    ),
                    Container(
                      width: dense ? 30 : 34,
                      height: dense ? 30 : 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(V5.radiusSm),
                        border: Border.all(color: V5.heroBorderHi),
                      ),
                      child:
                          Icon(icon, color: V5.yellow, size: dense ? 16 : 18),
                    ),
                  ],
                ),
                SizedBox(height: dense ? V5.space8 : V5.space14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.title,
                                        maxLines: dense ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: dense
                                            ? V5.title(
                                                context,
                                                color: V5.invInk,
                                              )
                                            : V5.titleLg(
                                                context,
                                                color: V5.invInk,
                                              ),
                                      ),
                                      if (!dense) ...[
                                        const SizedBox(height: V5.space4),
                                        Text(
                                          option.sub,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: V5.bodySm(
                                            context,
                                            color: V5.invInkSoft,
                                          ),
                                        ),
                                      ],
                                      SizedBox(
                                        height: dense ? V5.space8 : V5.space14,
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: dense ? 10 : 12,
                                          vertical: dense ? 7 : 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              V5.yellow.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            V5.radiusFull,
                                          ),
                                          border: Border.all(
                                            color: V5.yellow
                                                .withValues(alpha: 0.38),
                                          ),
                                        ),
                                        child: RichText(
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: V5.text(
                                              context,
                                              size: dense ? 16 : 18,
                                              weight: FontWeight.w800,
                                              color: V5.yellow,
                                              letterSpacing: -0.4,
                                              height: 1,
                                            ),
                                            children: [
                                              TextSpan(text: option.stat),
                                              TextSpan(
                                                text: '  ${option.unit}',
                                                style: V5.text(
                                                  context,
                                                  size: dense ? 11 : 12,
                                                  weight: FontWeight.w700,
                                                  color: V5.invInkSoft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: V5.space14),
                      Expanded(
                        flex: 5,
                        child: _GoalSignal(option: option, compact: dense),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSignal extends StatelessWidget {
  const _GoalSignal({required this.option, required this.compact});

  final V5GoalOption option;
  final bool compact;

  List<double> get _bars => switch (option.id) {
        'health' => const [0.44, 0.62, 0.78, 0.92],
        'body' => const [0.82, 0.68, 0.55, 0.40],
        'strength' => const [0.35, 0.52, 0.72, 0.90],
        'flexible' => const [0.30, 0.48, 0.68, 0.86],
        _ => const [0.42, 0.56, 0.72, 0.84],
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 7 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(V5.radiusLg),
        border: Border.all(color: V5.heroBorderHi),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _bars.asMap().entries.map((entry) {
          final active = entry.key == _bars.length - 1;
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: entry.key == _bars.length - 1 ? 0 : 6),
              child: FractionallySizedBox(
                heightFactor: entry.value,
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  decoration: BoxDecoration(
                    gradient: active ? V5.accentGradient : null,
                    color: active ? null : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(V5.radiusFull),
                    border: Border.all(
                      color: active
                          ? V5.yellow.withValues(alpha: 0.4)
                          : V5.heroBorderHi,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalEmptyHero extends StatelessWidget {
  const _GoalEmptyHero({super.key});

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    return Container(
      decoration: BoxDecoration(
        color: V5.surfaceSoft,
        borderRadius: BorderRadius.circular(V5.radiusXl),
        border: Border.all(color: V5.borderHi),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    V5IconBubble(
                      icon: Icons.flag_outlined,
                      size: r.isShort ? 36 : 44,
                    ),
                    SizedBox(
                        height: r.pick(cozy: V5.space10, short: V5.space6)),
                    Text(
                      'Chọn mục tiêu của bạn',
                      style: r.isShort
                          ? V5.bodySm(context, color: V5.inkSoft)
                          : V5.body(context, color: V5.inkSoft),
                    ),
                    if (!r.isShort) ...[
                      const SizedBox(height: V5.space4),
                      Text(
                        'Vika sẽ xây dựng lộ trình theo đúng mục tiêu của bạn.',
                        style: V5.caption(context, color: V5.inkFaint),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Goal chip — 2x2 grid item
// ─────────────────────────────────────────────────────────────

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final V5GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (option.id) {
      'health' => Icons.favorite_outline_rounded,
      'body' => Icons.straighten_rounded,
      'strength' => Icons.fitness_center_rounded,
      'flexible' => Icons.self_improvement_rounded,
      _ => Icons.flag_rounded,
    };
    return V5Card(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: V5.radiusLg,
      elevation: selected ? 2 : 1,
      tint: selected ? V5CardTint.ink : V5CardTint.cream,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? V5.yellow : V5.inkSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              option.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.titleSm(
                context,
                color: selected ? V5.invInk : V5.ink,
              ),
            ),
          ),
          if (selected)
            const V5CheckCircle(selected: true, size: 18, dark: true),
        ],
      ),
    );
  }
}
