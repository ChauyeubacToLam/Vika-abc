// LibraryCard — the scalable card template used by every horizontal
// rail in the Library / Khám phá sheet. ONE shape, ONE template; future
// content types (new series, new collections, new goals) slot in by
// providing data — no UI changes required.
//
// Card anatomy:
//   ┌──────────────────┐
//   │  ┌──┐            │  ← optional corner tag (top-left)
//   │  └──┘            │
//   │                  │  Visual area (1:1 aspect)
//   │   [icon glyph]   │  - gradient background (until photos arrive)
//   │                  │  - centered illustrative icon
//   │              ●AI │  ← optional AI badge (bottom-right)
//   ├──────────────────┤
//   │ TYPE             │  eyebrow (PROGRAM, BỘ SƯU TẬP, etc.)
//   │ Title            │  italic display title
//   │ meta             │  compact meta line
//   └──────────────────┘
//
// All variants of the card are driven by the [LibraryCardData] model;
// kind sets the eyebrow + accent palette, the rest is freeform.

import 'package:flutter/material.dart';

import '../../services/catalog/catalog_source.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

enum LibraryCardKind {
  program,
  collection,
  workout,
  exercise,
  yoga,
  album,
}

extension LibraryCardKindLabel on LibraryCardKind {
  String get label {
    switch (this) {
      case LibraryCardKind.program:
        return 'LỘ TRÌNH';
      case LibraryCardKind.collection:
        return 'BỘ SƯU TẬP';
      case LibraryCardKind.workout:
        return 'BUỔI TẬP';
      case LibraryCardKind.exercise:
        return 'BÀI TẬP';
      case LibraryCardKind.yoga:
        return 'YOGA';
      case LibraryCardKind.album:
        return 'ALBUM';
    }
  }

  /// Cadence — the *shape of commitment* this content asks of the user.
  /// Surfaced on every card so the difference between
  /// "one-session bundle" (collection) and "multi-episode arc" (album)
  /// is unmistakable at a glance.
  String? get cadence {
    switch (this) {
      case LibraryCardKind.program:
        return 'Theo lịch';
      case LibraryCardKind.album:
        return 'Tuần tự';
      case LibraryCardKind.collection:
        return 'Một buổi';
      case LibraryCardKind.workout:
        return 'Một buổi';
      case LibraryCardKind.exercise:
      case LibraryCardKind.yoga:
        return null;
    }
  }

  /// Short uppercase variant of [cadence], for compact eyebrow chips.
  String? get cadenceShort {
    switch (this) {
      case LibraryCardKind.program:
        return 'CÓ LỊCH';
      case LibraryCardKind.album:
        return 'TUẦN TỰ';
      case LibraryCardKind.collection:
        return '1 BUỔI';
      case LibraryCardKind.workout:
        return '1 BUỔI';
      case LibraryCardKind.exercise:
      case LibraryCardKind.yoga:
        return null;
    }
  }
}

/// All data needed to render a card. Add new content types by adding to
/// [LibraryCardKind] and pointing the kind's accent palette in
/// [_kindPalette] below. No card-widget changes required.
@immutable
class LibraryCardData {
  const LibraryCardData({
    required this.kind,
    required String title,
    this.duration,
    this.detail,
    this.hasAi = false,
    this.tag,
    this.icon,
    this.exerciseName,
    this.albumId,
    this.sequenceExerciseIds,
    this.episodeCount,
    this.episodeMeta,
  }) : _title = title;

  final LibraryCardKind kind;

  /// Curated pre-load fallback title. NOT authoritative for exercise cards —
  /// the [title] getter prefers the bundled catalog ([CatalogSource]).
  final String _title;

  /// Italic display title. For exercise-backed cards ([exerciseName] set),
  /// resolves from the catalog (single source of truth) so the card never
  /// disagrees with the exercise intro. Falls back to [_title] for albums /
  /// non-exercise cards or before the catalog loads.
  String get title {
    final ex = exerciseName;
    if (ex != null) {
      final vn = CatalogSource.instance.lookup(ex)?.vietnameseName;
      if (vn != null && vn.isNotEmpty) return vn;
    }
    return _title;
  }

  /// e.g. '4 tuần', '15 phút', '5 phút/buổi'. Optional.
  final String? duration;

  /// e.g. '12 buổi · Người mới'. Optional. Renders below duration.
  final String? detail;

  final bool hasAi;

  /// Optional corner ribbon — e.g. 'Đang chạy', 'Sắp ra mắt', 'Mới'.
  final String? tag;

  /// Illustrative glyph at the center of the visual area. Until photos
  /// arrive, an icon over a gradient stands in.
  final IconData? icon;

  /// Maps to a real `ExerciseDefinition` lookup key. In the Library this is
  /// normally the catalog id (`squat`, `mcgill_curlup`, ...).
  final String? exerciseName;

  /// Album-specific: stable curated album id (`wake`, `desk`, ...).
  final String? albumId;

  /// Album-specific: ordered catalog ids to launch back-to-back.
  final List<String>? sequenceExerciseIds;

  /// Album-specific: number of episodes in this series. Surfaced as a
  /// badge on [LibraryAlbumCard] / [LibrarySectionAlbumRail].
  final int? episodeCount;

  /// Album-specific: secondary line describing episode cadence (e.g.
  /// '6-8 phút mỗi tập').
  final String? episodeMeta;

  /// The volume label to show on the card. When this card is backed by a real
  /// exercise, pull the live volume from the bundled catalog ([CatalogSource])
  /// so the card and the exercise intro never disagree. Falls back to the
  /// static [duration] for non-exercise cards, or before the catalog has
  /// loaded (preloaded in main(); screens may also ensureLoaded()).
  String? get displayDuration {
    final name = exerciseName;
    if (name != null) {
      final info = CatalogSource.instance.lookup(name);
      if (info != null) return info.volumeLabel;
    }
    return duration;
  }
}

class LibraryCard extends StatefulWidget {
  const LibraryCard({
    super.key,
    required this.data,
    required this.onTap,
    this.width = 156,
    this.indexLabel,
  });

  final LibraryCardData data;
  final VoidCallback onTap;
  final double width;

  /// Optional italic watermark numeral painted into the card's visual
  /// area (e.g. '01', '02') — gives the rail a "chapter" feel and lets
  /// each card carry editorial personality.
  final String? indexLabel;

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final palette = _kindPalette(widget.data.kind, c);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Visual(
                palette: palette,
                data: widget.data,
                indexLabel: widget.indexLabel,
              ),
              const SizedBox(height: 12),
              _Text(data: widget.data, palette: palette),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VISUAL AREA — gradient + icon (placeholder until photos)
// ═══════════════════════════════════════════════════════════════

class _Visual extends StatelessWidget {
  const _Visual({
    required this.palette,
    required this.data,
    this.indexLabel,
  });
  final _CardPalette palette;
  final LibraryCardData data;
  final String? indexLabel;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Gradient background — palette-driven so each kind has its
            // own visual signature, but all share the same template.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: palette.gradient,
                ),
              ),
            ),
            // Watermark numeral — soft italic chapter mark in the
            // bottom-right. Adds editorial personality; reads as
            // "01 / 02 / 03" magazine chapter index per card.
            if (indexLabel != null)
              Positioned(
                right: -12,
                bottom: -28,
                child: IgnorePointer(
                  child: Text(
                    indexLabel!,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 120,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -6,
                      height: 1,
                      color: palette.iconColor.withValues(alpha: 0.10),
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ),
              ),
            // Subtle radial halo top-right — adds depth, hides flat
            // gradient feel until photos replace it.
            Positioned(
              top: -30,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        palette.haloColor.withValues(alpha: 0.4),
                        palette.haloColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Centered illustrative icon
            if (data.icon != null)
              Center(
                child: Icon(
                  data.icon,
                  size: 32,
                  color: palette.iconColor,
                ),
              ),
            // Corner tag (top-left) — e.g. ĐANG CHẠY, MỚI
            if (data.tag != null)
              Positioned(
                top: 10,
                left: 10,
                child: _CornerTag(label: data.tag!, palette: palette),
              ),
            // AI badge (bottom-right)
            if (data.hasAi)
              Positioned(
                bottom: 10,
                right: 10,
                child: _AIBadge(yellow: c.yellow, ink: c.ink),
              ),
          ],
        ),
      ),
    );
  }
}

class _CornerTag extends StatelessWidget {
  const _CornerTag({required this.label, required this.palette});
  final String label;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.tagBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: palette.tagFg,
        ),
      ),
    );
  }
}

class _AIBadge extends StatelessWidget {
  const _AIBadge({required this.yellow, required this.ink});
  final Color yellow;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: yellow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: yellow.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: ink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'AI',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TEXT AREA — eyebrow + italic title + compact meta
// ═══════════════════════════════════════════════════════════════

class _Text extends StatelessWidget {
  const _Text({required this.data, required this.palette});
  final LibraryCardData data;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final duration = data.displayDuration;
    final metaParts = <String>[
      if (duration != null) duration,
      if (data.detail != null) data.detail!,
    ];
    final cadenceShort = data.kind.cadenceShort;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data.kind.label,
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
            if (cadenceShort != null) ...[
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
              Flexible(
                child: Text(
                  cadenceShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.6,
            height: 1.1,
            color: c.ink,
          ),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            metaParts.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.inkFaint,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// KIND → PALETTE — each card kind gets a distinct visual signature
// ═══════════════════════════════════════════════════════════════

class _CardPalette {
  const _CardPalette({
    required this.gradient,
    required this.haloColor,
    required this.iconColor,
    required this.tagBg,
    required this.tagFg,
    required this.accent,
  });
  final LinearGradient gradient;
  final Color haloColor;
  final Color iconColor;
  final Color tagBg;
  final Color tagFg;
  final Color accent;
}

_CardPalette _kindPalette(LibraryCardKind kind, VikaColors c) {
  switch (kind) {
    case LibraryCardKind.program:
      // Warm dark — programs are the "prestige" tier
      return _CardPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.bgInverse, c.bgInverseHi],
        ),
        haloColor: c.yellow,
        iconColor: c.yellow,
        tagBg: c.yellow,
        tagFg: c.yellowInk,
        accent: c.yellow,
      );
    case LibraryCardKind.collection:
      // Cream-on-cream — collections are everyday
      return _CardPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9DDC5), Color(0xFFDDD0B5)],
        ),
        haloColor: c.yellow,
        iconColor: c.ink,
        tagBg: c.ink,
        tagFg: c.bg,
        accent: const Color(0xFFCD7C45),
      );
    case LibraryCardKind.workout:
      // Cooler tone for individual workouts
      return _CardPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD5C9B0), Color(0xFFC8BCA0)],
        ),
        haloColor: const Color(0xFFCD7C45),
        iconColor: c.ink,
        tagBg: c.ink,
        tagFg: c.bg,
        accent: c.yellow,
      );
    case LibraryCardKind.exercise:
      // Cream raised — discrete exercise drills
      return _CardPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.bgRaised, c.powder],
        ),
        haloColor: c.yellow,
        iconColor: c.inkSoft,
        tagBg: c.yellowGhost,
        tagFg: c.ink,
        accent: c.yellow,
      );
    case LibraryCardKind.yoga:
      // Warm earth tone for yoga
      return _CardPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3CDB0), Color(0xFFD2B58F)],
        ),
        haloColor: const Color(0xFFCD7C45),
        iconColor: c.ink,
        tagBg: c.ink,
        tagFg: c.bg,
        accent: const Color(0xFFCD7C45),
      );
    case LibraryCardKind.album:
      // Deep walnut with terracotta accent — series / multi-episode
      // arcs read as the "vinyl / box-set" tier visually.
      return _CardPalette(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D211A), Color(0xFF3F2E22)],
        ),
        haloColor: const Color(0xFFCD7C45),
        iconColor: const Color(0xFFE9DDC5),
        tagBg: const Color(0xFFCD7C45),
        tagFg: const Color(0xFF2D211A),
        accent: const Color(0xFFCD7C45),
      );
  }
}
