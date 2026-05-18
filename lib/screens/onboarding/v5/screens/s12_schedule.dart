import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S12Schedule extends StatefulWidget {
  const S12Schedule({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S12Schedule> createState() => _S12ScheduleState();
}

class _S12ScheduleState extends State<S12Schedule> {
  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _slots = [
    ('morning', '5 - 8h', 'Sáng'),
    ('afternoon', '16 - 18h', 'Chiều'),
    ('evening', '19 - 22h', 'Tối'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.data.scheduleSessions.isEmpty) {
      widget.data.scheduleSessions = ['T2_afternoon', 'T4_afternoon', 'T6_afternoon'];
    }
  }

  int get _recommendedFreq {
    // TODO(LOGIC-REFINEMENT-#7): S11 Schedule — frequency recommendation uses 3/4/5 by level only.
    // Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
    // See Notion: Vika State > Onboarding Logic Refinement block for full context.
    final level = widget.data.level ?? 'beginner';
    return level == 'advanced'
        ? 5
        : level == 'intermediate'
            ? 4
            : 3;
  }

  String get _reason {
    final level = widget.data.level ?? 'beginner';
    return level == 'advanced'
        ? 'Cường độ cao cho người tập đều'
        : level == 'intermediate'
            ? 'Tốt cho mục tiêu của bạn'
            : 'Phù hợp với mức bắt đầu';
  }

  int get _minutesPerSession {
    final level = widget.data.level ?? 'beginner';
    return level == 'advanced'
        ? 50
        : level == 'intermediate'
            ? 35
            : 25;
  }

  void _toggle(String key) {
    setState(() {
      if (widget.data.scheduleSessions.contains(key)) {
        widget.data.scheduleSessions.remove(key);
      } else {
        widget.data.scheduleSessions.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.data.scheduleSessions;
    final totalHr = (sessions.length * _minutesPerSession / 60).toStringAsFixed(1);
    return V5Screen(
      index: 12,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: 144,
          left: 16,
          right: 16,
          height: 124,
          child: V5FadeIn(
            child: V5HeroCard(
              borderRadius: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: _days.map((d) {
                            final lit = sessions.any((s) => s.startsWith('${d}_'));
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: lit ? V5.yellow : Colors.white.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: lit
                                    ? [
                                        BoxShadow(
                                          color: V5.yellow.withValues(alpha: .5),
                                          blurRadius: 5,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: _days.map((d) {
                            return SizedBox(
                              width: 12,
                              child: Text(
                                d.replaceAll('T', '').replaceAll('CN', 'C'),
                                textAlign: TextAlign.center,
                                style: V5.text(
                                  context,
                                  size: 7,
                                  weight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: .4),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const V5Eyebrow(
                            label: 'Vika gợi ý',
                            dark: true,
                            sparkle: true,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$_recommendedFreq',
                                style: V5.text(
                                  context,
                                  size: 32,
                                  weight: FontWeight.w800,
                                  color: V5.invInk,
                                  letterSpacing: -1.2,
                                  height: .95,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'buổi/tuần',
                                style: V5.text(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: V5.invInk,
                                  letterSpacing: -.3,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _reason,
                            style: V5.text(
                              context,
                              size: 11,
                              weight: FontWeight.w500,
                              color: V5.invInkSoft,
                              height: 1.35,
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
        ),
        Positioned(
          top: 284,
          left: 0,
          right: 0,
          bottom: 108,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Lịch tập trong tuần',
                      style: V5.text(
                        context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: V5.ink,
                        letterSpacing: -.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      sessions.isEmpty ? 'Chạm để chọn' : '${sessions.length} buổi · ~$totalHr h',
                      style: V5.text(
                        context,
                        size: 11,
                        weight: FontWeight.w700,
                        color: sessions.isEmpty ? V5.inkFaint : V5.yellowDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                    decoration: BoxDecoration(
                      color: V5.surface,
                      border: Border.all(color: V5.border),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [V5.cardShadow(0.08)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            ..._days.map(
                              (d) => Expanded(
                                child: Text(
                                  d,
                                  textAlign: TextAlign.center,
                                  style: V5.text(
                                    context,
                                    size: 10,
                                    weight: FontWeight.w800,
                                    color: V5.inkSoft,
                                    letterSpacing: .3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Column(
                            children: _slots.map((slot) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              slot.$2,
                                              maxLines: 1,
                                              style: V5.text(
                                                context,
                                                size: 9,
                                                weight: FontWeight.w800,
                                                color: V5.ink,
                                                letterSpacing: -.1,
                                                height: 1,
                                              ),
                                            ),
                                            Text(
                                              slot.$3,
                                              style: V5.text(
                                                context,
                                                size: 8,
                                                weight: FontWeight.w600,
                                                color: V5.inkFaint,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ..._days.map((d) {
                                        final key = '${d}_${slot.$1}';
                                        final selected = sessions.contains(key);
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: GestureDetector(
                                              onTap: () => _toggle(key),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? V5.ink
                                                      : V5.ink.withValues(alpha: .04),
                                                  border: Border.all(
                                                    color: selected
                                                        ? V5.ink
                                                        : V5.ink.withValues(alpha: .06),
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow:
                                                      selected ? [V5.cardShadow(0.18)] : null,
                                                ),
                                                child: Center(
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 180),
                                                    width: selected ? 8 : 3,
                                                    height: selected ? 8 : 3,
                                                    decoration: BoxDecoration(
                                                      color: selected
                                                          ? V5.yellow
                                                          : V5.ink.withValues(alpha: .15),
                                                      shape: BoxShape.circle,
                                                      boxShadow: selected
                                                          ? [
                                                              BoxShadow(
                                                                color: V5.yellow
                                                                    .withValues(alpha: .7),
                                                                blurRadius: 8,
                                                              ),
                                                              BoxShadow(
                                                                color: V5.yellow
                                                                    .withValues(alpha: .15),
                                                                spreadRadius: 3,
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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
        V5PillCTA(
          label: 'Khoá lịch tập',
          disabledLabel: 'Chạm để chọn buổi tập',
          enabled: sessions.length >= 2,
          onTap: widget.onNext,
        ),
      ],
    );
  }
}
