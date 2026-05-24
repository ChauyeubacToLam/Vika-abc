// SheetChrome — sheet drag handle, slim editorial header, and refined
// search bar at the top of the Library / Khám phá sheet.
//
// v2 (polished): the header is trimmed to a single line —
// "THƯ VIỆN · 100 BÀI" eyebrow on the left, close button on the right.
// The verbose 3-line "Khám phá. + tagline" hero has been dropped; the
// hero featured card below carries the moment instead.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: c.borderHi,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Slim header — one row: yellow bar + 'THƯ VIỆN' + bullet + count +
/// hairline + close. Removes the prior 3-line header that competed
/// with the hero featured card below.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.onClose,
    this.totalCount,
  });

  final VoidCallback onClose;

  /// Optional total catalog count shown in the header (e.g. 100).
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: c.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 11),
          Text(
            'THƯ VIỆN',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: c.ink,
            ),
          ),
          if (totalCount != null) ...[
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: c.inkFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$totalCount BÀI',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: c.inkSoft,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SheetSearch extends StatelessWidget {
  const SheetSearch({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: c.inkSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tìm theo tên, mục tiêu, phần thân…',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
