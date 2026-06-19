// LibraryCatalogEntry — the compact "Kho bài tập" block on the Khám phá tab.
//
// It replaces the old inline horizontal pager (which hid a sideways swipe in a
// vertical scroll and snapped to its header on every change). This block does
// no in-place group switching at all: it's a teaser + a set of routes into the
// dedicated LibraryCatalogScreen, where browsing happens with real tabs.
//
//   • section header ("KHO BÀI TẬP" · count)
//   • group chips — each DEEP-LINKS into the catalog on that group's tab
//   • one featured exercise (immediate, tappable)
//   • a full-width "Xem tất cả N bài →" route into the catalog
//
// Nothing here mutates state, so the jump bug is structurally impossible.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/library_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../ivory/atoms.dart';

class LibraryCatalogEntry extends StatelessWidget {
  const LibraryCatalogEntry({
    super.key,
    required this.eyebrow,
    required this.rows,
    required this.onSelectByName,
    required this.onOpenCatalog,
    this.meta,
  });

  final String eyebrow;
  final String? meta;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelectByName;

  /// Opens the dedicated catalog screen. A non-null group lands on that tab.
  final void Function(String? initialGroup) onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final c = VikaColors.of(context);
    final featured = rows.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header — yellow tick + eyebrow + count, matching every
          // other Library section.
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
                  meta!,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Lead line — sets the expectation that this opens a full browser.
          Text(
            'Toàn bộ thư viện, sắp theo nhóm cơ.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 16),
          // One featured exercise — an immediate, tappable object.
          _FeaturedCard(
            row: featured,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelectByName(featured.definitionName);
            },
          ),
          const SizedBox(height: 14),
          // Primary route into the full catalog.
          _SeeAllButton(
            label: 'Xem tất cả ${rows.length} bài',
            onTap: () {
              HapticFeedback.selectionClick();
              onOpenCatalog(null);
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.row, required this.onTap});
  final AllExerciseRowMock row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.bgRaised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.09),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  final cacheWidth = (constraints.maxWidth * dpr).round();
                  return AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: c.powder,
                      child: row.thumbnailAsset != null
                          ? Image.asset(
                              row.thumbnailAsset!,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              cacheWidth: cacheWidth,
                              filterQuality: FilterQuality.medium,
                              excludeFromSemantics: true,
                              errorBuilder: (_, __, ___) => Center(
                                child: PoseGlyph(
                                    type: row.glyph, size: 40, dark: true),
                              ),
                            )
                          : Center(
                              child: PoseGlyph(
                                  type: row.glyph, size: 40, dark: true),
                            ),
                    ),
                  );
                },
              ),
              Container(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
                child: Row(
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
                            '${row.cat} · ${row.diff}',
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
                    Container(
                      width: 38,
                      height: 38,
                      decoration:
                          BoxDecoration(color: c.ink, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 17, color: c.bg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: c.bgRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: c.ink,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 16, color: c.ink),
            ],
          ),
        ),
      ),
    );
  }
}
