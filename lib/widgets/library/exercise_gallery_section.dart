// ExerciseGallerySection — the catalog's per-group treatment.
//
// One reusable component renders EVERY muscle group identically: an editorial
// masthead, one large featured card, then the rest as a 2-column grid. The
// whole Khám phá catalog is just a vertical stack of these. Adding an exercise
// = a data row in libraryMockAllExercises; adding a group = one entry in
// libraryGroupEditorial. No widget code changes either way — that's how it
// scales.
//
// Each exercise is a CONTAINED card: the 16:9 render and its caption live inside
// one rounded, bordered, raised (bgRaised) container with a soft warm shadow, so
// every exercise reads as a distinct, tappable object — not a floating image.
// The renders are native 16:9, so BoxFit.cover crops nothing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/library_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../ivory/atoms.dart';

class ExerciseGallerySection extends StatelessWidget {
  const ExerciseGallerySection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.onSelectByName,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelectByName;

  void _open(AllExerciseRowMock row) {
    HapticFeedback.selectionClick();
    onSelectByName(row.definitionName);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final featured = rows.first;
    final rest = rows.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Masthead(
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          count: rows.length,
        ),
        const SizedBox(height: 20),
        _ExerciseCard(row: featured, featured: true, onTap: () => _open(featured)),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (var i = 0; i < rest.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ExerciseCard(
                    row: rest[i],
                    onTap: () => _open(rest[i]),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < rest.length
                      ? _ExerciseCard(
                          row: rest[i + 1],
                          onTap: () => _open(rest[i + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (i + 2 < rest.length) const SizedBox(height: 16),
          ],
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Masthead ────────────────────────────────────────────────────────────────
class _Masthead extends StatelessWidget {
  const _Masthead({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 28, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow with the yellow accent tick — same chapter-mark
          // language as every other Library section header, so a group
          // reads unmistakably as "you are now in a new section".
          Row(
            children: [
              Container(
                width: 5,
                height: 16,
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                eyebrow,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  height: 1.2,
                  color: c.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Big italic display title + a short yellow underline beneath it.
          // The underline is one of the four reserved yellow uses and makes
          // the group title pop off the cream instead of blending in.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: c.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: c.border)),
              const SizedBox(width: 12),
              Text(
                '${count.toString().padLeft(2, '0')} bài',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: c.inkFaint,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Exercise card (contained — featured or grid) ────────────────────────────
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.row,
    required this.onTap,
    this.featured = false,
  });

  final AllExerciseRowMock row;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final radius = featured ? 22.0 : 18.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.bgRaised,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: featured ? 0.09 : 0.06),
                blurRadius: featured ? 26 : 14,
                offset: Offset(0, featured ? 12 : 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardImage(asset: row.thumbnailAsset, glyph: row.glyph),
              // Hairline seating the image on the caption surface.
              Container(height: 1, color: c.border),
              Padding(
                padding: featured
                    ? const EdgeInsets.fromLTRB(16, 14, 14, 16)
                    : const EdgeInsets.fromLTRB(13, 11, 12, 13),
                child: featured ? _featuredCaption(c) : _gridCaption(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredCaption(VikaColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        height: 1.08,
                        letterSpacing: -0.5,
                        color: c.ink,
                      ),
                    ),
                  ),
                  if (row.ai) ...[
                    const SizedBox(width: 8),
                    const AIDot(small: true),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${row.displayCat} · ${row.diff}',
                maxLines: 1,
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
          ),
        ),
        const SizedBox(width: 12),
        // Filled "go" affordance — obvious primary action on the hero card.
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(Icons.arrow_forward_rounded, size: 17, color: c.bg),
        ),
      ],
    );
  }

  Widget _gridCaption(VikaColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                  letterSpacing: -0.3,
                  color: c.ink,
                ),
              ),
            ),
            if (row.ai) ...[
              const SizedBox(width: 5),
              const AIDot(small: true),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          row.displayCat,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: c.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ─── Card image (16:9, native ratio → no crop) ───────────────────────────────
class _CardImage extends StatelessWidget {
  const _CardImage({required this.asset, required this.glyph});

  final String? asset;
  final PoseGlyphType glyph;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = (constraints.maxWidth * dpr).round();
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: c.powder,
            child: asset != null
                ? Image.asset(
                    asset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    cacheWidth: cacheWidth,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) =>
                        Center(child: PoseGlyph(type: glyph, size: 40, dark: true)),
                  )
                : Center(child: PoseGlyph(type: glyph, size: 40, dark: true)),
          ),
        );
      },
    );
  }
}
