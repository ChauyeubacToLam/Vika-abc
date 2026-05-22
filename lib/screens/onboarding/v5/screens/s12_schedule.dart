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
    ('morning', '5–8h', 'Sáng', Icons.wb_sunny_outlined),
    ('afternoon', '16–18h', 'Chiều', Icons.wb_twilight_rounded),
    ('evening', '19–22h', 'Tối', Icons.nightlight_round),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.data.scheduleSessions.isEmpty) {
      widget.data.scheduleSessions = [
        'T2_afternoon',
        'T4_afternoon',
        'T6_afternoon'
      ];
    }
  }

  int get _recommendedFreq {
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
    final totalHr =
        (sessions.length * _minutesPerSession / 60).toStringAsFixed(1);
    final r = V5Responsive.of(context);
    return V5Screen(
      index: 14,
      onBack: widget.onBack,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              V5.gutter,
              r.chromeTopPadding,
              V5.gutter,
              r.ctaBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V5ScreenHeader(
                  eyebrow: 'Lịch tập',
                  title: 'Bạn rảnh\nlúc nào?',
                  size: r.isShort ? V5HeaderSize.medium : V5HeaderSize.large,
                ),
                SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
                V5FadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: SizedBox(
                    width: double.infinity,
                    child: _RecommendationStrip(
                      freq: _recommendedFreq,
                      reason: _reason,
                      days: _days,
                      sessions: sessions,
                    ),
                  ),
                ),
                SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CHỌN BUỔI TẬP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.eyebrow(context, color: V5.inkSoft),
                      ),
                    ),
                    const SizedBox(width: V5.space10),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            key: ValueKey(sessions.length),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sessions.isEmpty
                                  ? V5.inkHair
                                  : V5.yellow.withValues(alpha: 0.16),
                              borderRadius:
                                  BorderRadius.circular(V5.radiusFull),
                              border: Border.all(
                                color: sessions.isEmpty
                                    ? V5.border
                                    : V5.yellow.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              sessions.isEmpty
                                  ? 'Chạm để chọn'
                                  : '${sessions.length} buổi · ~$totalHr h',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5
                                  .bodyXs(
                                    context,
                                    color: sessions.isEmpty
                                        ? V5.inkFaint
                                        : V5.yellowDeep,
                                  )
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: V5.space10),
                Expanded(
                  child: V5FadeIn(
                    delay: const Duration(milliseconds: 220),
                    slideY: 8,
                    child: _ScheduleGrid(
                      days: _days,
                      slots: _slots,
                      sessions: sessions,
                      onToggle: _toggle,
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
          bottom: 32 + r.viewPadding.bottom,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Recommendation strip — frequency stat + week dot indicator
// ─────────────────────────────────────────────────────────────

class _RecommendationStrip extends StatelessWidget {
  const _RecommendationStrip({
    required this.freq,
    required this.reason,
    required this.days,
    required this.sessions,
  });

  final int freq;
  final String reason;
  final List<String> days;
  final List<String> sessions;

  @override
  Widget build(BuildContext context) {
    return V5HeroCard(
      borderRadius: V5.radiusLg,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: V5AmbientGlow(
              size: const Size(200, 200),
              opacity: 0.18,
              color: V5.yellow,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                // Left — frequency stat.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const V5Sparkle(size: 11),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'VIKA GỢI Ý',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.eyebrow(context, color: V5.invInkSoft),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: V5.space10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$freq',
                            style: V5.displaySm(context, color: V5.yellow),
                          ),
                          const SizedBox(width: V5.space6),
                          Flexible(
                            child: Text(
                              'buổi/tuần',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.titleSm(context, color: V5.invInk),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: V5.space4),
                      Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.bodySm(context, color: V5.invInkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: V5.space12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TUẦN CỦA BẠN',
                      style: V5.eyebrow(context, color: V5.invInkFaint),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: days.map((d) {
                        final lit = sessions.any((s) => s.startsWith('${d}_'));
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: lit
                                ? V5.yellow
                                : Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(V5.radiusXs),
                            boxShadow: lit
                                ? [
                                    BoxShadow(
                                      color: V5.yellow.withValues(alpha: 0.6),
                                      blurRadius: 7,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: days.map((d) {
                        return SizedBox(
                          width: 15,
                          child: Text(
                            d.replaceAll('T', '').replaceAll('CN', 'C'),
                            textAlign: TextAlign.center,
                            style: V5.text(
                              context,
                              size: 8,
                              weight: FontWeight.w700,
                              color: V5.invInkFaint,
                              letterSpacing: 0.2,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Schedule grid — 7 days × 3 slots, toggleable cells
// ─────────────────────────────────────────────────────────────

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.days,
    required this.slots,
    required this.sessions,
    required this.onToggle,
  });

  final List<String> days;
  final List<(String, String, String, IconData)> slots;
  final List<String> sessions;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusLg),
        boxShadow: V5.elevation1,
      ),
      child: Column(
        children: [
          // Day headers.
          Row(
            children: [
              const SizedBox(width: 48),
              ...days.map(
                (d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: V5.eyebrow(context, color: V5.inkSoft),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: slots.map((slot) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        // Time slot label.
                        SizedBox(
                          width: 48,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(slot.$4, size: 11, color: V5.inkSoft),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      slot.$3,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: V5
                                          .eyebrow(context, color: V5.ink)
                                          .copyWith(
                                            letterSpacing: 0.2,
                                            height: 1,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: V5.space2),
                              Text(
                                slot.$2,
                                style: V5
                                    .caption(context, color: V5.inkFaint)
                                    .copyWith(height: 1.1),
                              ),
                            ],
                          ),
                        ),
                        ...days.map((d) {
                          final key = '${d}_${slot.$1}';
                          final selected = sessions.contains(key);
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onToggle(key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: V5.curveSharp,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? V5.ink
                                        : V5.ink.withValues(alpha: 0.04),
                                    border: Border.all(
                                      color: selected
                                          ? V5.ink
                                          : V5.ink.withValues(alpha: 0.06),
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(V5.radiusXs),
                                    boxShadow: selected
                                        ? V5.elevation2
                                        : const <BoxShadow>[],
                                  ),
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: V5.curveSharp,
                                      width: selected ? 8 : 3,
                                      height: selected ? 8 : 3,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? V5.yellow
                                            : V5.ink.withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                        boxShadow: selected
                                            ? [
                                                BoxShadow(
                                                  color: V5.yellow
                                                      .withValues(alpha: 0.7),
                                                  blurRadius: 8,
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
    );
  }
}
