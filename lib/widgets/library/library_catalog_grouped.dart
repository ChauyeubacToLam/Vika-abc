// LibraryCatalogGrouped — replaces the flat "Kho bài tập" list. As the
// catalog grows past ~30 items the flat list becomes a wall; this
// widget addresses scale with three layered tools:
//
//   1. Inline search field (filters by name in real time)
//   2. Group chip strip (jumps to a group; reflects active group as you
//      scroll near it)
//   3. Per-group subsections with their own headers
//
// Editorial language is preserved: section header rules, italic display
// row names, ghost yellow accent, tabular figures for counts. Same row
// design as AllExercisesGrid so the catalog reads coherent end-to-end.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/library_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../ivory/atoms.dart';

class LibraryCatalogGrouped extends StatefulWidget {
  const LibraryCatalogGrouped({
    super.key,
    required this.eyebrow,
    required this.rows,
    required this.onSelectByName,
    this.meta,
    this.groupOrder = libraryCatalogGroupOrder,
  });

  final String eyebrow;
  final String? meta;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelectByName;
  final List<String> groupOrder;

  @override
  State<LibraryCatalogGrouped> createState() => _LibraryCatalogGroupedState();
}

class _LibraryCatalogGroupedState extends State<LibraryCatalogGrouped> {
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  /// Active group filter. `null` means "Tất cả" (all groups shown with
  /// section headers). Set means: render only that group's rows.
  String? _filterGroup;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final q = _searchCtl.text.trim().toLowerCase();
    if (q != _query) setState(() => _query = q);
  }

  @override
  void dispose() {
    _searchCtl.removeListener(_onQueryChanged);
    _searchCtl.dispose();
    super.dispose();
  }

  // Returns groups in canonical [groupOrder] first, then any
  // unrecognized groups in first-seen order.
  List<String> _allGroupsOrdered() {
    final seen = <String>{};
    final ordered = <String>[];
    for (final g in widget.groupOrder) {
      if (widget.rows.any((r) => r.group == g)) {
        ordered.add(g);
        seen.add(g);
      }
    }
    for (final r in widget.rows) {
      if (!seen.contains(r.group)) {
        ordered.add(r.group);
        seen.add(r.group);
      }
    }
    return ordered;
  }

  void _onChipTap(String? group) {
    HapticFeedback.selectionClick();
    setState(() {
      // Toggle: tapping the active chip clears the filter.
      _filterGroup = (_filterGroup == group) ? null : group;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final groups = _allGroupsOrdered();

    // Rows visible after both filters apply.
    Iterable<AllExerciseRowMock> visible = widget.rows;
    if (_filterGroup != null) {
      visible = visible.where((r) => r.group == _filterGroup);
    }
    if (_query.isNotEmpty) {
      visible = visible.where((r) =>
          r.name.toLowerCase().contains(_query) ||
          r.cat.toLowerCase().contains(_query));
    }
    final filteredRows = visible.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(eyebrow: widget.eyebrow, meta: widget.meta),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _SearchField(controller: _searchCtl),
        ),
        _GroupChipStrip(
          groups: groups,
          activeGroup: _filterGroup,
          counts: {
            for (final g in groups)
              g: widget.rows.where((r) => r.group == g).length,
          },
          totalCount: widget.rows.length,
          onTap: _onChipTap,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildBody(c, groups, filteredRows),
        ),
      ],
    );
  }

  Widget _buildBody(
    VikaColors c,
    List<String> groups,
    List<AllExerciseRowMock> filteredRows,
  ) {
    // Empty state when search yields nothing (works for any filter combo).
    if (filteredRows.isEmpty && (_query.isNotEmpty || _filterGroup != null)) {
      return _EmptyResults(query: _query);
    }
    // A specific group selected → flat list (no group headers needed,
    // since there's only one group of rows).
    if (_filterGroup != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResultCount(label: '${filteredRows.length} BÀI · $_filterGroup'),
          for (final r in filteredRows) ...[
            _CatalogRow(
              row: r,
              onTap: () => widget.onSelectByName(r.definitionName),
            ),
            const SizedBox(height: 6),
          ],
        ],
      );
    }
    // Search active, no group filter → flat list.
    if (_query.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResultCount(label: '${filteredRows.length} KẾT QUẢ'),
          for (final r in filteredRows) ...[
            _CatalogRow(
              row: r,
              onTap: () => widget.onSelectByName(r.definitionName),
            ),
            const SizedBox(height: 6),
          ],
        ],
      );
    }
    // Default: all groups with their own section headers.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups) ...[
          _GroupSection(
            group: g,
            rows: widget.rows.where((r) => r.group == g).toList(),
            onSelectByName: widget.onSelectByName,
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: c.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.eyebrow, this.meta});
  final String eyebrow;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEARCH FIELD
// ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 18, color: c.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: c.ink,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: c.ink,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: InputBorder.none,
                hintText: 'Tìm bài tập trong kho',
                hintStyle: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.clear();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, size: 16, color: c.inkSoft),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GROUP CHIP STRIP
// ─────────────────────────────────────────────────────────────

class _GroupChipStrip extends StatelessWidget {
  const _GroupChipStrip({
    required this.groups,
    required this.activeGroup,
    required this.counts,
    required this.totalCount,
    required this.onTap,
  });

  final List<String> groups;

  /// null = "Tất cả" (no group filter). Set = group-name string.
  final String? activeGroup;
  final Map<String, int> counts;
  final int totalCount;

  /// Tapping a chip toggles its filter. Passing `null` means the user
  /// tapped the "Tất cả" reset chip.
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    // Build a unified list of entries: first "Tất cả" reset, then the
    // group chips. Active state highlights the currently-filtered chip.
    final entries = <_ChipEntry>[
      _ChipEntry(label: 'Tất cả', count: totalCount, group: null),
      for (final g in groups)
        _ChipEntry(label: g, count: counts[g] ?? 0, group: g),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = entries[i];
          final active = e.group == activeGroup;
          return _Chip(entry: e, active: active, onTap: () => onTap(e.group));
        },
      ),
    );
  }
}

class _ChipEntry {
  const _ChipEntry({
    required this.label,
    required this.count,
    required this.group,
  });
  final String label;
  final int count;

  /// null = "Tất cả" reset chip.
  final String? group;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.entry,
    required this.active,
    required this.onTap,
  });
  final _ChipEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.ink : c.bgRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.ink : c.border),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: active ? c.invInk : c.ink,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    active ? c.yellow.withValues(alpha: 0.22) : c.yellowGhost,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.count}',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: active ? c.yellow : c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GROUP SECTION
// ─────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.rows,
    required this.onSelectByName,
  });

  final String group;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelectByName;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Row(
            children: [
              Text(
                group,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: c.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rows.length} BÀI',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: c.inkFaint,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: c.border)),
            ],
          ),
        ),
        for (final r in rows) ...[
          _CatalogRow(
            row: r,
            onTap: () => onSelectByName(r.definitionName),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ROW
// ─────────────────────────────────────────────────────────────

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.row, required this.onTap});
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
              ExerciseThumbnail(
                glyph: row.glyph,
                asset: row.thumbnailAsset,
                yoga: row.yoga,
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

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 32, color: c.inkFaint),
          const SizedBox(height: 10),
          Text(
            'Không tìm thấy "$query"',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thử từ khoá khác, hoặc xoá để duyệt toàn bộ.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
