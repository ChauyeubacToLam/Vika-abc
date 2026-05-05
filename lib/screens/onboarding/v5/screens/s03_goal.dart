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
  bool get _canContinue => widget.data.goal != null && widget.data.duration != null;

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
    return V5Screen(
      index: 3,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: 144,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const V5Eyebrow(label: 'Mục tiêu 4 tuần'),
              const SizedBox(height: 14),
              Text(
                'Bạn muốn đạt\nđược gì?',
                style: V5.text(
                  context,
                  size: 30,
                  weight: FontWeight.w800,
                  color: V5.ink,
                  letterSpacing: -1.2,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 280,
          left: 16,
          right: 16,
          height: 170,
          child: sel == null ? _emptyHero() : _selectedHero(sel),
        ),
        Positioned(
          top: 466,
          left: 16,
          right: 16,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.05,
            children: goalOptions.asMap().entries.map((entry) {
              final i = entry.key;
              final option = entry.value;
              final selected = widget.data.goal == option.id;
              return V5FadeIn(
                delay: Duration(milliseconds: i * 40),
                slideY: 8,
                child: GestureDetector(
                  onTap: () => setState(() => widget.data.goal = option.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? V5.ink : V5.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? V5.ink : V5.border),
                      boxShadow: [selected ? V5.cardShadow(0.18) : V5.cardShadow(0.08)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.title,
                                style: V5.text(
                                  context,
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: selected ? V5.invInk : V5.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (selected) const V5CheckCircle(selected: true, size: 16),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          option.stat,
                          style: V5.text(
                            context,
                            size: 16,
                            weight: FontWeight.w800,
                            color: V5.yellow,
                            letterSpacing: -0.5,
                            height: 1,
                          ),
                        ),
                        Text(
                          option.unit,
                          style: V5.text(
                            context,
                            size: 10,
                            weight: FontWeight.w500,
                            color: selected ? V5.invInkSoft : V5.inkSoft,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 112,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'BẠN ĐÃ TẬP BAO LÂU?',
                  style: V5.text(
                    context,
                    size: 10,
                    weight: FontWeight.w700,
                    color: V5.inkSoft,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: V5.surface,
                  border: Border.all(color: V5.border),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [V5.cardShadow(0.08)],
                ),
                child: Row(
                  children: durationOptions.map((duration) {
                    final selected = widget.data.duration == duration.id;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => widget.data.duration = duration.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          decoration: BoxDecoration(
                            color: selected ? V5.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            duration.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V5.text(
                              context,
                              size: 13,
                              weight: FontWeight.w700,
                              color: selected ? V5.invInk : V5.ink,
                              letterSpacing: -0.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Tiếp tục',
          enabled: _canContinue,
          onTap: widget.onNext,
        ),
      ],
    );
  }

  Widget _selectedHero(V5GoalOption selected) {
    return V5FadeIn(
      key: ValueKey(selected.id),
      child: V5HeroCard(
        borderRadius: 24,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: -30,
              bottom: 0,
              width: 200,
              child: V5HeroFigure(pose: selected.pose),
            ),
            Positioned(
              left: 22,
              top: 18,
              bottom: 18,
              width: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAU 4 TUẦN',
                    style: V5.text(
                      context,
                      size: 10,
                      weight: FontWeight.w700,
                      color: V5.invInkSoft,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    selected.stat,
                    style: V5.text(
                      context,
                      size: 44,
                      weight: FontWeight.w800,
                      color: V5.yellow,
                      letterSpacing: -2,
                      height: 0.95,
                    ),
                  ),
                  Text(
                    selected.unit,
                    style: V5.text(
                      context,
                      size: 11,
                      weight: FontWeight.w500,
                      color: V5.invInkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHero() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: V5.borderHi, width: 1.5, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: V5.yellowSoft, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: V5.yellowDeep, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn mục tiêu bên dưới',
            style: V5.text(
              context,
              size: 13,
              weight: FontWeight.w600,
              color: V5.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
