// LibraryTileGrid — the "Duyệt nhanh" 2-column facet tile grid that
// sits under the editorial carousel. Each tile is a one-tap deep link
// to a [LibraryBrowseScreen] filtered by that facet (body part / intent
// / modality / duration / level / equipment).
//
// This is the page's scale absorber: as the catalog grows from 100 to
// 1000 items, the home tab stays the same size because depth moves into
// sub-screens. New facets slot in as new BrowseTileData entries.
//
// Each tile uses the editorial cream-raised grammar: italic display
// label, ghost yellow accent, decorative icon top-right, italic
// count numeral bottom-right.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/library_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class LibraryTileGrid extends StatelessWidget {
  const LibraryTileGrid({
    super.key,
    required this.eyebrow,
    required this.tiles,
    required this.onSelectTile,
    this.meta,
    this.intro,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  });

  final String eyebrow;
  final String? meta;
  final String? intro;
  final List<BrowseTileData> tiles;
  final ValueChanged<BrowseTileData> onSelectTile;
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
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final tileWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    SizedBox(
                      width: tileWidth,
                      child: _Tile(
                        tile: tiles[i],
                        index: i,
                        onTap: () => onSelectTile(tiles[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.tile,
    required this.index,
    required this.onTap,
  });

  final BrowseTileData tile;
  final int index;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Alternate two cream surface tones so the grid doesn't read as
    // a single block. Even-indexed tiles use bgRaised, odd use powder.
    final surface = widget.index.isEven ? c.bgRaised : c.powder;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 1.45,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative icon glyph — soft top-right corner.
                Positioned(
                  top: -12,
                  right: -12,
                  child: IgnorePointer(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.18),
                            c.yellow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Icon(
                    widget.tile.icon,
                    size: 22,
                    color: c.inkSoft,
                  ),
                ),
                // Decorative italic numeral watermark for editorial feel.
                Positioned(
                  bottom: -22,
                  left: -6,
                  child: IgnorePointer(
                    child: Text(
                      (widget.index + 1).toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 90,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -4,
                        height: 1,
                        color: c.ink.withValues(alpha: 0.04),
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.tile.eyebrow != null)
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
                            Flexible(
                              child: Text(
                                widget.tile.eyebrow!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: c.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.tile.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.9,
                              height: 1.0,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.tile.breakdown ??
                                      '${widget.tile.count} BÀI',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: c.inkFaint,
                                    fontFeatures: VikaIvoryMain.tabularFigures,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: c.ink,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 11,
                                  color: c.bg,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
