// GoalCard — cream-on-cream editorial card for the user's stated goal.
// Sits at the top of the Profile body, just under the dark hero.
//
// Anatomy:
//   ┌──────────────────────────────────────────────┐
//   │ ●  MỤC TIÊU CỦA BẠN              SỬA →       │
//   │                                               │
//   │ Khoẻ đều,                                     │
//   │ bền lâu.                                      │
//   │                                               │
//   │ ┃ "Muốn ngủ ngon hơn và không còn nhức lưng…" │
//   │                                               │
//   │  42 %                              Còn 4 tuần │
//   │  ━━━━━━━━━━●─────────────────                 │  ← progress meter
//   └──────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.title,
    required this.quote,
    required this.progress,
    required this.daysLeft,
    this.onEdit,
  });

  /// Italic display title (no trailing period — added automatically).
  final String title;
  final String quote;

  /// 0..100.
  final int progress;

  /// Weeks-remaining label, e.g. "Còn 4 tuần nữa". Null hides it (no active
  /// plan) so we never show a fake number.
  final String? daysLeft;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: c.yellow, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MỤC TIÊU CỦA BẠN',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkSoft,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onEdit?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SỬA',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: c.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: c.inkSoft,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Two-line italic display title.
          _SplitTitle(title: title),
          const SizedBox(height: 14),
          // Quote with yellow left rule.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"$quote"',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: c.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // Progress meter with editorial labels.
          _ProgressMeter(progress: progress, daysLeft: daysLeft),
        ],
      ),
    );
  }
}

class _SplitTitle extends StatelessWidget {
  const _SplitTitle({required this.title});
  final String title;

  /// Split on the first space so the display falls across two lines
  /// like "Khoẻ đều, / bền lâu." — gives the goal a poster headline.
  (String, String) _split() {
    final t = title.trim();
    // Split on comma+space first (preferred), then on space.
    final commaSpace = t.indexOf(', ');
    if (commaSpace != -1) {
      return (t.substring(0, commaSpace + 1), t.substring(commaSpace + 2));
    }
    final space = t.indexOf(' ');
    if (space != -1) {
      return (t.substring(0, space), t.substring(space + 1));
    }
    return (t, '');
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final (line1, line2) = _split();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line1,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 32,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.6,
            height: 1.0,
            color: c.ink,
          ),
        ),
        if (line2.isNotEmpty)
          Text(
            line2.endsWith('.') ? line2 : '$line2.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -1.6,
              height: 1.0,
              color: c.ink,
            ),
          ),
      ],
    );
  }
}

class _ProgressMeter extends StatelessWidget {
  const _ProgressMeter({required this.progress, required this.daysLeft});
  final int progress;
  final String? daysLeft;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final clamped = progress.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$clamped',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1.0,
                    height: 1.0,
                    color: c.ink,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '%',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'đã đi',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: c.inkSoft,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (daysLeft != null)
              Text(
                daysLeft!,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: c.inkFaint,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (context, bc) {
              final w = bc.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track.
                  Positioned(
                    top: 5,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Yellow filled segment.
                  Positioned(
                    top: 5,
                    left: 0,
                    width: (clamped / 100) * w,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.45),
                            c.yellow,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Today dot at progress position.
                  Positioned(
                    top: 2,
                    left: (clamped / 100) * w - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.bgRaised,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
