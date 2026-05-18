// FutureChapterCard — cream-raised card for future weeks. Eyebrow with
// "SẮP MỞ KHOÁ" delimiter, italic phase name, tagline, two preview stats
// (sessions + bodyFocus), dashed unlock note with lock icon.
//
// Mirrors `FutureChapterCard` and `ChapterStat` in
// vika-main-app-ivory-v1.jsx. The card explicitly drops the third
// "Trạng thái: Coming" stat that was redundant with the eyebrow + unlock
// note (anti-pattern #4 in the spec).

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';
class FutureChapterCard extends StatelessWidget {
  const FutureChapterCard({super.key, required this.week});

  final PlanWeek week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(22),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.border),
        ),
        child: Stack(
          children: [
            // Subtle paper-edge wash on the right.
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        c.borderHi.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow: "CHƯƠNG TIẾP · TUẦN 04 · SẮP MỞ KHOÁ"
                Row(
                  children: [
                    PlanEyebrow(
                      'CHƯƠNG TIẾP · TUẦN ${week.num.toString().padLeft(2, '0')}',
                      size: 9,
                      letterSpacing: 1.8,
                      tabular: true,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PlanEyebrow(
                      'SẮP MỞ KHOÁ',
                      size: 9,
                      letterSpacing: 1.8,
                      color: c.inkSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PlanH1('${week.name}.', size: 36, letterSpacing: -1.8),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: PlanP(
                    week.chapterLine ??
                        'Lộ trình tuần kế sẽ định hình từ kết quả này.',
                    soft: true,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                // Two stats: sessions + body focus.
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ChapterStat(
                          label: 'Số buổi',
                          value: '${week.sessions} buổi',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: c.border,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ChapterStat(
                          label: 'Trọng tâm',
                          value: week.bodyFocus,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Unlock note — dashed, with lock icon.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(12),
                    // Note: Flutter can't render dashed borders without a
                    // dependency or CustomPainter. Use solid borderHi here;
                    // visual impact is similar at this radius/weight.
                    border: Border.all(color: c.borderHi),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: c.inkSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          week.unlockNote ??
                              'Mở khoá sau bài đánh giá tuần trước.',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: c.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterStat extends StatelessWidget {
  const _ChapterStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlanEyebrow(label, size: 9, letterSpacing: 1.4),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: c.ink,
          ),
        ),
      ],
    );
  }
}
