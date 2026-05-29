// RankedInsights — container that shows the top-3 exercise insights and
// offers an "Xem cả N bài đo được" expansion CTA. Once expanded, all
// insights render and the CTA changes to "Thu gọn".
//
// Mirrors `RankedExerciseInsights` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import 'exercise_insight.dart';
import '../../theme/app_colors.dart';

class RankedInsights extends StatefulWidget {
  const RankedInsights({super.key, required this.ranked});

  final List<ExerciseInsightMock> ranked;

  @override
  State<RankedInsights> createState() => _RankedInsightsState();
}

class _RankedInsightsState extends State<RankedInsights> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visible = _expanded ? widget.ranked : widget.ranked.take(3).toList();
    final remaining = widget.ranked.length - 3;

    return Column(
      children: [
        for (final mock in visible) ExerciseInsight(mock: mock),
        if (!_expanded && remaining > 0)
          _ExpandSentinel(
            remaining: widget.ranked.length,
            onTap: () => setState(() => _expanded = true),
          )
        else if (_expanded)
          _CollapseButton(onTap: () => setState(() => _expanded = false)),
      ],
    );
  }
}

class _ExpandSentinel extends StatelessWidget {
  const _ExpandSentinel({required this.remaining, required this.onTap});

  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderHi),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem cả $remaining bài đo được',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sắp xếp theo mức tiến bộ',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: c.bg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          alignment: Alignment.center,
          child: Text(
            'Thu gọn',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: c.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
