// LibraryBrowseScreen — the deep sub-screen tiles deep-link into. Same
// editorial language as the main Library tab (dark mini-hero + cream
// body) but focused on one facet (Chân, Cốt lõi, Yoga, AI, ≤10 phút,
// Người mới, etc.).
//
// This is where scale lives: the home tab stays fixed-size, and every
// new bucket of content is reachable from a tile that pushes into this
// screen. A small in-page kind filter at the top of the body lets users
// narrow within the facet.
//
// Content per tile is resolved in `_contentForTile()` — pure data
// composition over the existing library_mock lists.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_mock.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../widgets/ivory/atoms.dart';
import '../widgets/library/library_card.dart';
import '../widgets/library/library_list_card.dart';

class LibraryBrowseScreen extends StatefulWidget {
  const LibraryBrowseScreen({
    super.key,
    required this.tile,
    required this.onSelectExercise,
    required this.onSelectCard,
  });

  final BrowseTileData tile;
  final void Function(ExerciseDefinition) onSelectExercise;
  final ValueChanged<LibraryCardData> onSelectCard;

  @override
  State<LibraryBrowseScreen> createState() => _LibraryBrowseScreenState();
}

class _LibraryBrowseScreenState extends State<LibraryBrowseScreen> {
  String _kindFilter = 'all';

  void _selectCard(LibraryCardData card) {
    widget.onSelectCard(card);
  }

  void _selectByName(String? name) {
    if (name == null) return;
    final def = lookupExerciseDefinition(name);
    if (def == null) return;
    widget.onSelectExercise(def);
  }

  ({List<LibraryCardData> cards, List<AllExerciseRowMock> rows}) get _content {
    return _contentForTile(widget.tile.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final content = _content;

    final filteredCards = _kindFilter == 'all'
        ? content.cards
        : content.cards
            .where((card) => _matchesKindFilter(card, _kindFilter))
            .toList();
    final showRows = _kindFilter == 'all' || _kindFilter == 'exercise';
    final rows = showRows ? content.rows : const <AllExerciseRowMock>[];

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _BrowseHero(
              tile: widget.tile,
              totalCount: content.cards.length + content.rows.length,
              kindFilter: _kindFilter,
              onSelectKind: (id) => setState(() => _kindFilter = id),
              cardCounts: _kindCounts(content),
            ),
          ),
          if (filteredCards.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                eyebrow: 'BỘ TẬP',
                meta: '${filteredCards.length}',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList.separated(
                itemCount: filteredCards.length,
                separatorBuilder: (context, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 1, color: c.border),
                ),
                itemBuilder: (context, i) {
                  final card = filteredCards[i];
                  return LibraryListCard(
                    data: card,
                    description: _descriptionFor(card),
                    indexLabel: (i + 1).toString().padLeft(2, '0'),
                    onTap: () => _selectCard(card),
                  );
                },
              ),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: _SectionHeader(
                eyebrow: 'BÀI TẬP',
                meta: '${rows.length}',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return _BrowseRow(
                    row: row,
                    onTap: () => _selectByName(row.definitionName),
                  );
                },
              ),
            ),
          ],
          if (filteredCards.isEmpty && rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 48 + bottomInset)),
        ],
      ),
    );
  }

  Map<String, int> _kindCounts(
      ({List<LibraryCardData> cards, List<AllExerciseRowMock> rows}) c) {
    final m = <String, int>{
      'all': c.cards.length + c.rows.length,
      'album': c.cards.where((x) => x.kind == LibraryCardKind.album).length,
      'exercise': c.rows.length +
          c.cards
              .where((x) =>
                  x.kind == LibraryCardKind.exercise ||
                  x.kind == LibraryCardKind.workout)
              .length,
    };
    return m;
  }

  bool _matchesKindFilter(LibraryCardData card, String filter) {
    return switch (filter) {
      'album' => card.kind == LibraryCardKind.album,
      'exercise' => card.kind == LibraryCardKind.exercise ||
          card.kind == LibraryCardKind.workout,
      _ => true,
    };
  }
}

// ─────────────────────────────────────────────────────────────
// CONTENT RESOLUTION — what each tile shows.
// ─────────────────────────────────────────────────────────────

/// Resolves a tile's content from the existing mock lists. Keeping this
/// in one place keeps the screen pure UI and the curation explicit.
({List<LibraryCardData> cards, List<AllExerciseRowMock> rows}) _contentForTile(
    String tileId) {
  switch (tileId) {
    case 'lower':
      return (
        cards: [_albumCardById('legs')],
        rows: _rowsInGroup('CHÂN · MÔNG'),
      );
    case 'core':
      return (
        cards: [_albumCardById('core')],
        rows: _rowsInGroup('CỐT LÕI'),
      );
    case 'back':
      return (
        cards: [_albumCardById('back')],
        rows: _rowsByIds(const [
          'bird_dog',
          'dead_bug',
          'glute_bridge',
          'superman',
          'sphinx',
          'cobra',
          'bow_pose',
        ]),
      );
    case 'yoga':
      return (
        cards: [_albumCardById('evening'), _albumCardById('mobility')],
        rows: libraryMockAllExercises.where((row) => row.yoga).toList(),
      );
    case 'ai':
      return (
        cards: libraryAlbumCards,
        rows: libraryMockAllExercises.where((r) => r.ai).toList(),
      );
    case 'short':
      return (
        cards: [
          _albumCardById('wake'),
          _albumCardById('desk'),
          _albumCardById('energy'),
        ],
        rows: const [],
      );
  }
  return (cards: const [], rows: const []);
}

LibraryCardData _albumCardById(String id) {
  return libraryAlbumCards.firstWhere((card) => card.albumId == id);
}

List<AllExerciseRowMock> _rowsInGroup(String group) {
  return libraryMockAllExercises.where((row) => row.group == group).toList();
}

List<AllExerciseRowMock> _rowsByIds(List<String> ids) {
  return [
    for (final id in ids)
      libraryMockAllExercises.firstWhere((row) => row.definitionName == id),
  ];
}

String? _descriptionFor(LibraryCardData card) {
  // Generic single-line descriptors so the browse list reads cleanly
  // without us needing per-card descriptions.
  return switch (card.kind) {
    LibraryCardKind.program =>
      'Lộ trình ${card.duration ?? "nhiều tuần"} có cấu trúc theo từng buổi.',
    LibraryCardKind.collection => 'Bộ sưu tập ngắn. Tập theo mục đích cụ thể.',
    LibraryCardKind.exercise =>
      'Bài tập riêng lẻ với camera AI hỗ trợ chỉnh form.',
    LibraryCardKind.workout => 'Buổi tập trọn vẹn.',
    LibraryCardKind.yoga => 'Tư thế yoga cho linh hoạt và thư giãn.',
    LibraryCardKind.album =>
      'Bộ tập có camera AI. Vika chạy từng bài theo thứ tự.',
  };
}

// ═══════════════════════════════════════════════════════════════
// HERO — small dark stage carrying back button + tile identity
// ═══════════════════════════════════════════════════════════════

class _BrowseHero extends StatelessWidget {
  const _BrowseHero({
    required this.tile,
    required this.totalCount,
    required this.kindFilter,
    required this.onSelectKind,
    required this.cardCounts,
  });

  final BrowseTileData tile;
  final int totalCount;
  final String kindFilter;
  final ValueChanged<String> onSelectKind;
  final Map<String, int> cardCounts;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(32),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.7, -1),
            end: const Alignment(0.7, 1),
            colors: [c.bgInverse, c.bgInverseHi],
          ),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(label: tile.label),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Stack(
                    children: [
                      // Watermark italic numeral — gives the sub-hero
                      // chapter mark like the home page's carousel.
                      Positioned(
                        right: -30,
                        top: -10,
                        child: IgnorePointer(
                          child: Text(
                            totalCount.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 140,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -7,
                              height: 1,
                              color: c.invInk.withValues(alpha: 0.05),
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: c.yellow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (tile.eyebrow ?? 'PHÂN LOẠI'),
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: c.yellow,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tile.label,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -2.4,
                              height: 0.92,
                              color: c.invInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: c.yellow,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  '$totalCount mục · album và bài tập có camera AI.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                    color: c.invInkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _KindChips(
                  selectedId: kindFilter,
                  counts: cardCounts,
                  onSelect: onSelectKind,
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).maybePop();
            },
          ),
          const Spacer(),
          Text(
            'VIKA  ·  KHÁM PHÁ',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: c.invInkSoft,
            ),
          ),
          const Spacer(),
          _CircleButton(
            icon: Icons.search_rounded,
            tooltip: 'Tìm trong $label',
            onTap: () {
              HapticFeedback.selectionClick();
              // Search drawer is wired in phase 6.
            },
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: c.invInk),
        ),
      ),
    );
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.selectedId,
    required this.counts,
    required this.onSelect,
  });
  final String selectedId;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  static const _items = [
    ('all', 'Tất cả'),
    ('album', 'Bộ tập'),
    ('exercise', 'Bài tập'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, label) = _items[i];
          final count = counts[id] ?? 0;
          final selected = id == selectedId;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(id);
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    selected ? c.yellow : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? c.yellow
                      : Colors.white.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: selected ? c.yellowInk : c.invInk,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.yellow.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? c.yellowInk : c.invInkSoft,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER (matches the rest of the Library page)
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.eyebrow, this.meta});
  final String eyebrow;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      child: Row(
        children: [
          Container(
            width: 4,
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
              fontSize: 10.5,
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
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EXERCISE ROW (compact catalog-style row, mirrors AllExercisesGrid)
// ═══════════════════════════════════════════════════════════════

class _BrowseRow extends StatelessWidget {
  const _BrowseRow({required this.row, required this.onTap});
  final AllExerciseRowMock row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: c.bgRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  row.idx.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: row.yoga ? c.powder : c.bgInverse,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: PoseGlyph(type: row.glyph, size: 22, dark: !row.yoga),
              ),
              const SizedBox(width: 12),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: c.ink,
                            ),
                          ),
                        ),
                        if (row.ai) ...[
                          const SizedBox(width: 6),
                          const AIDot(small: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${row.cat} · ${row.diff}',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: c.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: c.inkFaint),
            const SizedBox(height: 14),
            Text(
              'Chưa có bài nào ở mục này',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.inkSoft,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đang cập nhật hàng tuần.',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
