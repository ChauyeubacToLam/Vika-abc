import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
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

  @override
  void initState() {
    super.initState();
    _recommendedId = _recommendFork();
    widget.data.fork ??= _recommendedId;
  }

  String _recommendFork() {
    // TODO(LOGIC-REFINEMENT-#2): S05 Fork — Yoga vs HW recommendation uses single-rule heuristic with `+1.5` pain factor toward yoga.
    // Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
    // See Notion: Vika State > Onboarding Logic Refinement block for full context.
    final hasBackOrNeckPain =
        widget.data.painAreas.any((a) => a == 'back' || a == 'neck');
    final homeScore = (widget.data.goal == 'strength' ? 2 : 0) +
        (widget.data.goal == 'body' ? 1.5 : 0) +
        (widget.data.whyStep1 == 'confidence' ? 1 : 0);
    final yogaScore = (widget.data.goal == 'flexible' ? 2 : 0) +
        (widget.data.whyStep1 == 'pain' ? 1.5 : 0) +
        (widget.data.whyStep1 == 'energy' ? 0.5 : 0) +
        (hasBackOrNeckPain ? 1.5 : 0);
    return homeScore >= yogaScore ? 'home' : 'yoga';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    final heroTop = compact ? 126.0 : 144.0;
    final heroHeight = compact ? 170.0 : 184.0;
    final contentTop = compact ? 310.0 : 344.0;
    final recChoice = forkChoices[_recommendedId]!;
    final orderedIds =
        _recommendedId == 'home' ? ['home', 'yoga'] : ['yoga', 'home'];
    final reasoning = _reasoning();
    return V5Screen(
      index: 5,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: heroTop,
          left: 16,
          right: 16,
          height: heroHeight,
          child: V5FadeIn(
            child: V5HeroCard(
              child: Stack(
                children: [
                  const Positioned(
                    top: 18,
                    left: 18,
                    child: V5Eyebrow(
                      label: 'Vika gợi ý',
                      dark: true,
                      sparkle: true,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: -30,
                    bottom: 0,
                    width: 220,
                    child: V5HeroFigure(pose: recChoice.pose),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 20,
                    width: 200,
                    child: V5FadeIn(
                      slideY: 12,
                      curve: Curves.easeOutBack,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VIKA NGHĨ',
                            style: V5.text(
                              context,
                              size: 11,
                              weight: FontWeight.w600,
                              color: V5.invInkSoft,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${recChoice.title}\nphù hợp',
                            style: V5.text(
                              context,
                              size: 24,
                              weight: FontWeight.w800,
                              color: V5.invInk,
                              letterSpacing: -0.8,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reasoning,
                            style: V5.text(
                              context,
                              size: 11,
                              weight: FontWeight.w500,
                              color: V5.invInkSoft,
                              height: 1.4,
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
        ),
        Positioned(
          top: contentTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: orderedIds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final choice = forkChoices[orderedIds[index]]!;
                    return V5FadeIn(
                      delay: Duration(milliseconds: index * 60),
                      slideY: 8,
                      child: _ForkCard(
                        choice: choice,
                        selected: widget.data.fork == choice.id,
                        recommended: choice.id == _recommendedId,
                        onTap: () =>
                            setState(() => widget.data.fork = choice.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Tiếp tục',
          enabled: widget.data.fork != null,
          onTap: widget.onNext,
        ),
      ],
    );
  }

  String _reasoning() {
    final hasBackOrNeckPain =
        widget.data.painAreas.any((a) => a == 'back' || a == 'neck');
    if (_recommendedId == 'yoga' && hasBackOrNeckPain) {
      return 'Yoga giúp giảm đau lưng/cổ vai & tăng linh hoạt';
    }
    final parts = <String>[];
    V5GoalOption? goal;
    for (final option in goalOptions) {
      if (option.id == widget.data.goal) goal = option;
    }
    V5WhyOption? why;
    for (final option in whyOptions) {
      if (option.id == widget.data.whyStep1) why = option;
    }
    if (goal != null) parts.add(goal.title.toLowerCase());
    if (why != null) parts.add(why.label.toLowerCase());
    return parts.isNotEmpty
        ? 'Vì bạn muốn ${parts.join(' & ')}'
        : 'Dựa trên lựa chọn của bạn';
  }
}

class _ForkCard extends StatelessWidget {
  const _ForkCard({
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
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? V5.ink : V5.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? V5.ink
                  : recommended
                      ? V5.yellow.withValues(alpha: 0.5)
                      : V5.border,
            ),
            boxShadow: [selected ? V5.cardShadow(0.18) : V5.cardShadow(0.08)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: selected
                            ? V5.yellow.withValues(alpha: 0.18)
                            : V5.yellowSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            choice.stat,
                            style: V5.text(
                              context,
                              size: 17,
                              weight: FontWeight.w800,
                              color: V5.yellow,
                              letterSpacing: -0.5,
                              height: 1,
                            ),
                          ),
                          Text(
                            choice.statLabel.toUpperCase(),
                            style: V5.text(
                              context,
                              size: 8,
                              weight: FontWeight.w700,
                              color: selected ? V5.invInkSoft : V5.yellowDeep,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                choice.title,
                                style: V5.text(
                                  context,
                                  size: 17,
                                  weight: FontWeight.w800,
                                  color: selected ? V5.invInk : V5.ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (recommended && !selected)
                                _MiniTag(label: 'Gợi ý', dark: false),
                              if (selected)
                                _MiniTag(label: 'Đã chọn', dark: true),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            choice.sub,
                            style: V5.text(
                              context,
                              size: 13,
                              weight: FontWeight.w600,
                              color: selected ? V5.invInkSoft : V5.inkSoft,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                V5FadeIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: Colors.white.withValues(alpha: 0.08)),
                        Text(
                          choice.desc,
                          style: V5.text(
                            context,
                            size: 12,
                            weight: FontWeight.w500,
                            color: V5.invInkSoft,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...choice.highlights.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.check_rounded,
                                    color: V5.yellow, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: V5.text(
                                      context,
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: V5.invInk,
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: V5.text(
          context,
          size: 9,
          weight: FontWeight.w700,
          color: dark ? V5.yellowInk : V5.yellowDeep,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
