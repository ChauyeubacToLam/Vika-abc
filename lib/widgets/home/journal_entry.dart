// JournalEntry — italic quote with a yellow left-border accent. Displays
// what the user wrote about their goal during onboarding.
//
// Mirrors the journal entry block on the Home tab in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';

class JournalEntry extends StatelessWidget {
  const JournalEntry({
    super.key,
    required this.dateLabel,
    required this.quote,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 0),
  });

  final String dateLabel; // 'Bạn viết · 27 tháng 4'
  final String quote;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: c.yellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlanEyebrow(
                    dateLabel,
                    size: 10,
                    letterSpacing: 1.8,
                    color: c.inkSoft,
                  ),
                  const SizedBox(height: 8),
                  PlanP(
                    quote,
                    size: 14,
                    italic: true,
                    soft: true,
                    height: 1.55,
                    letterSpacing: -0.05,
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
