// LibraryRail — a section in the Library sheet: small header bar with
// an eyebrow + optional meta + optional "see all" affordance, then a
// horizontal-scrolling row of [LibraryCard]s.
//
// One file, one widget — works for ANY content type because the cards
// inside are [LibraryCard]s driven by [LibraryCardData]. Future rails
// just instantiate a new LibraryRail with new data; no widget changes.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'library_card.dart';

class LibraryRail extends StatelessWidget {
  const LibraryRail({
    super.key,
    required this.eyebrow,
    required this.cards,
    required this.onSelectCard,
    this.meta,
    this.intro,
    this.cardWidth = 156,
    this.gutter = 20,
    this.showIndices = false,
  });

  /// e.g. 'ĐANG CHẠY', 'BỘ SƯU TẬP', 'BÀI TẬP CÓ CAMERA AI'.
  final String eyebrow;

  /// Optional meta on the right of the header — e.g. '4 lộ trình' or 'Xem tất cả →'.
  final String? meta;

  /// Optional italic editorial sub-head describing the section's purpose.
  final String? intro;

  final List<LibraryCardData> cards;
  final ValueChanged<LibraryCardData> onSelectCard;

  final double cardWidth;
  final double gutter;

  /// When true, each card displays its position (01, 02, …) as a
  /// soft italic watermark numeral inside the visual area. Gives the
  /// rail an editorial "chapter" feel.
  final bool showIndices;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              EdgeInsets.fromLTRB(gutter, 0, gutter, intro == null ? 16 : 10),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: c.border)),
              if (meta != null) ...[
                const SizedBox(width: 14),
                Text(
                  meta!.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (intro != null)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter + 17, 0, gutter, 16),
            child: Text(
              intro!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                height: 1.45,
                color: c.inkSoft,
                letterSpacing: -0.1,
              ),
            ),
          ),
        SizedBox(
          height: _calcCardHeight(cardWidth),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              return LibraryCard(
                data: cards[i],
                width: cardWidth,
                indexLabel:
                    showIndices ? (i + 1).toString().padLeft(2, '0') : null,
                onTap: () => onSelectCard(cards[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Rough vertical budget for a card — visual area (1:1) + 12pt gap +
  /// text block (~78pt for eyebrow + 2-line title + meta).
  double _calcCardHeight(double w) => w + 12 + 78;
}
