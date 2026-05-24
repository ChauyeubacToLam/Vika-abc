// LibraryAlbumRail — horizontal rail of "album / series" cards. A
// series is a multi-episode arc (think Apple Fitness+ Time to Walk,
// Peloton "Bike with Kendall" — a structured sequence of related
// classes that share a thread). Distinct from a Program (multi-week
// path) and from a Collection (one-shot bucket).
//
// Visual treatment: 3:4 portrait card, deep walnut gradient with
// terracotta halo, italic display title overlaid on the cover, episode
// count badge top-right, watermark italic numeral. Reads as "vinyl box
// set" — clearly its own tier.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'library_card.dart';

class LibraryAlbumRail extends StatelessWidget {
  const LibraryAlbumRail({
    super.key,
    required this.eyebrow,
    required this.cards,
    required this.onSelectCard,
    this.meta,
    this.intro,
    this.cardWidth = 172,
    this.gutter = 20,
  });

  final String eyebrow;
  final String? meta;
  final String? intro;
  final List<LibraryCardData> cards;
  final ValueChanged<LibraryCardData> onSelectCard;
  final double cardWidth;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, intro == null ? 16 : 10),
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
          height: cardWidth * (4 / 3) + 6,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              return LibraryAlbumCard(
                data: cards[i],
                width: cardWidth,
                indexLabel: (i + 1).toString().padLeft(2, '0'),
                onTap: () => onSelectCard(cards[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A portrait album/series card. Text is overlaid on the cover (album
/// grammar) rather than placed underneath like [LibraryCard].
class LibraryAlbumCard extends StatefulWidget {
  const LibraryAlbumCard({
    super.key,
    required this.data,
    required this.onTap,
    this.width = 172,
    this.indexLabel,
  });

  final LibraryCardData data;
  final VoidCallback onTap;
  final double width;
  final String? indexLabel;

  @override
  State<LibraryAlbumCard> createState() => _LibraryAlbumCardState();
}

class _LibraryAlbumCardState extends State<LibraryAlbumCard> {
  bool _pressed = false;

  static const _bg = Color(0xFF2D211A);
  static const _bgHi = Color(0xFF3F2E22);
  static const _accent = Color(0xFFCD7C45);
  static const _cream = Color(0xFFE9DDC5);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_bg, _bgHi],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Terracotta halo top-right.
                    Positioned(
                      top: -40,
                      right: -40,
                      child: IgnorePointer(
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x66CD7C45), // ~0.40 alpha
                                Color(0x00CD7C45),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Big italic chapter numeral — bleeds off the right
                    // edge near the upper-middle. Acts as the cover art.
                    if (widget.indexLabel != null)
                      Positioned(
                        top: 30,
                        right: -32,
                        child: IgnorePointer(
                          child: Text(
                            widget.indexLabel!,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 168,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -10,
                              height: 1,
                              color: _cream.withValues(alpha: 0.09),
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                        ),
                      ),
                    // Decorative icon — small stamp upper-left.
                    if (widget.data.icon != null)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _cream.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _cream.withValues(alpha: 0.14),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.data.icon,
                            size: 16,
                            color: _accent,
                          ),
                        ),
                      ),
                    // Episode count badge top-right.
                    if (widget.data.episodeCount != null)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: _EpisodeBadge(
                          count: widget.data.episodeCount!,
                        ),
                      ),
                    // Bottom gradient — stronger now for legible overlay.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 160,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x661A130F),
                                Color(0xEE140F0B),
                              ],
                              stops: [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Terracotta hairline accent above the title.
                    Positioned(
                      left: 14,
                      bottom: 100,
                      child: Container(
                        width: 24,
                        height: 2,
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    // Title overlay block.
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: _accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ALBUM',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: _accent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 2,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: _cream.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TUẦN TỰ',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: _cream.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.data.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1.0,
                              height: 1.0,
                              color: _cream,
                            ),
                          ),
                          if (widget.data.episodeMeta != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.data.episodeMeta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _cream.withValues(alpha: 0.62),
                                fontFeatures:
                                    VikaIvoryMain.tabularFigures,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.count});
  final int count;

  static const _accent = Color(0xFFCD7C45);
  static const _cream = Color(0xFFE9DDC5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _cream.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cream.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _accent, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count TẬP',
            style: const TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: _cream,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
