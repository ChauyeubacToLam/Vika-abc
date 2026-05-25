// LibraryListCard + LibraryListRail — vertical magazine-style list of
// cards used for the "Bộ sưu tập" section. Deliberately DIFFERENT
// format from the horizontal LibraryRail so the page rhythm varies as
// you scroll (horizontal → vertical → horizontal again). Reads like an
// editorial article list, not a rail of identical thumbnails.
//
// Each list card: square visual block on the left + content column on
// the right (eyebrow, italic title, description, meta + tap chevron).
// More room for description than the horizontal rail card — works for
// content that benefits from "what is this?" context.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'library_card.dart';

class LibraryListRail extends StatelessWidget {
  const LibraryListRail({
    super.key,
    required this.eyebrow,
    required this.cards,
    required this.descriptions,
    required this.onSelectCard,
    this.meta,
    this.intro,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  });

  final String eyebrow;
  final String? meta;
  final String? intro;
  final List<LibraryCardData> cards;

  /// One description per card, parallel-indexed with [cards].
  final List<String> descriptions;
  final ValueChanged<LibraryCardData> onSelectCard;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          if (intro != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 17),
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
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < cards.length; i++) ...[
            LibraryListCard(
              data: cards[i],
              description: i < descriptions.length ? descriptions[i] : null,
              indexLabel: (i + 1).toString().padLeft(2, '0'),
              onTap: () => onSelectCard(cards[i]),
            ),
            if (i < cards.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(height: 1, color: c.border),
              ),
          ],
        ],
      ),
    );
  }
}

class LibraryListCard extends StatefulWidget {
  const LibraryListCard({
    super.key,
    required this.data,
    required this.onTap,
    this.description,
    this.indexLabel,
  });

  final LibraryCardData data;
  final String? description;

  /// Optional small italic numeral on the right of the eyebrow (01, 02).
  final String? indexLabel;

  final VoidCallback onTap;

  @override
  State<LibraryListCard> createState() => _LibraryListCardState();
}

class _LibraryListCardState extends State<LibraryListCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual block — square, ~88pt
            _Visual(data: widget.data),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.data.kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: c.inkSoft,
                        ),
                      ),
                      if (widget.data.kind.cadenceShort != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: c.inkFaint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.data.kind.cadenceShort!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: c.yellow,
                          ),
                        ),
                      ],
                      if (widget.indexLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.indexLabel!,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.3,
                            color: c.inkFaint,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                      ],
                      if (widget.data.hasAi) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: c.yellowGhost,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: c.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.7,
                      height: 1.1,
                      color: c.ink,
                    ),
                  ),
                  if (widget.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.data.duration != null) ...[
                        Icon(Icons.access_time_rounded,
                            size: 11, color: c.inkFaint),
                        const SizedBox(width: 4),
                        Text(
                          widget.data.duration!,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.inkFaint,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                      ],
                      if (widget.data.detail != null) ...[
                        if (widget.data.duration != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: BoxDecoration(
                              color: c.inkFaint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.data.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.inkFaint,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: c.inkSoft,
                      ),
                    ],
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

class _Visual extends StatelessWidget {
  const _Visual({required this.data});
  final LibraryCardData data;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final palette = _paletteFor(data.kind, c);
    return Container(
      width: 86,
      height: 86,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: palette.gradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: IgnorePointer(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.halo.withValues(alpha: 0.35),
                      palette.halo.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (data.icon != null)
            Center(
              child: Icon(
                data.icon,
                size: 32,
                color: palette.iconColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _ListPalette {
  const _ListPalette({
    required this.gradient,
    required this.halo,
    required this.iconColor,
  });
  final LinearGradient gradient;
  final Color halo;
  final Color iconColor;
}

_ListPalette _paletteFor(LibraryCardKind kind, VikaColors c) {
  switch (kind) {
    case LibraryCardKind.program:
      return _ListPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.bgInverse, c.bgInverseHi],
        ),
        halo: c.yellow,
        iconColor: c.yellow,
      );
    case LibraryCardKind.collection:
      return _ListPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9DDC5), Color(0xFFDDD0B5)],
        ),
        halo: c.yellow,
        iconColor: c.ink,
      );
    case LibraryCardKind.workout:
      return _ListPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD5C9B0), Color(0xFFC8BCA0)],
        ),
        halo: const Color(0xFFCD7C45),
        iconColor: c.ink,
      );
    case LibraryCardKind.exercise:
      return _ListPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.bgRaised, c.powder],
        ),
        halo: c.yellow,
        iconColor: c.inkSoft,
      );
    case LibraryCardKind.yoga:
      return _ListPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3CDB0), Color(0xFFD2B58F)],
        ),
        halo: const Color(0xFFCD7C45),
        iconColor: c.ink,
      );
    case LibraryCardKind.album:
      return const _ListPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D211A), Color(0xFF3F2E22)],
        ),
        halo: Color(0xFFCD7C45),
        iconColor: Color(0xFFE9DDC5),
      );
  }
}
