// LibraryCatalogScreen — the full exercise database ("Kho bài tập"), opened
// from the compact catalog entry on the Khám phá tab.
//
// This replaces the old inline horizontal pager that was nested inside the
// Library tab's vertical scroll. That nesting caused the three problems we set
// out to fix:
//   • a hidden horizontal swipe inside a vertical scroll (not discoverable)
//   • a variable-height block that resized + snapped to its header on change
//   • a group title that blended into the cream body
//
// Here each muscle group is a real TAB. The structure is deliberately flat:
//   dark compact hero (back + title + search)
//   → scrollable TabBar (one tab per group, moving yellow underline)
//   → TabBarView, where EACH tab owns its own scroll view.
//
// Because every tab scrolls independently, switching groups never resizes a
// shared block and never throws you back to a header. Because it's a real
// TabBar, the sideways swipe is the universal, expected gesture — the moving
// underline and the next tab peeking at the edge say "swipe me" without a hint.
//
// Search is hosted in the FIXED hero (not the collapsing area) so typing never
// rebuilds the field or drops focus. A non-empty query swaps the body to a flat
// result list across all groups and hides the tab bar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_mock.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../widgets/ivory/atoms.dart';
import '../widgets/library/exercise_gallery_section.dart';

class LibraryCatalogScreen extends StatefulWidget {
  const LibraryCatalogScreen({
    super.key,
    required this.rows,
    required this.onSelectByName,
    this.initialGroup,
  });

  /// Every catalog exercise. Grouped into tabs by [AllExerciseRowMock.group].
  final List<AllExerciseRowMock> rows;

  /// Opens an exercise by its definition name (delegated to the host screen).
  final void Function(String?) onSelectByName;

  /// Group to land on. Falls back to the first group when null/unknown.
  final String? initialGroup;

  @override
  State<LibraryCatalogScreen> createState() => _LibraryCatalogScreenState();
}

class _LibraryCatalogScreenState extends State<LibraryCatalogScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  late final List<String> _groups;
  TabController? _tabController;

  /// The "Vuốt để đổi nhóm" hint is shown until the user changes tab once.
  bool _hintVisible = true;

  @override
  void initState() {
    super.initState();
    _groups = orderedCatalogGroups(widget.rows);

    if (_groups.isNotEmpty) {
      final wanted = _groups.indexOf(widget.initialGroup ?? '');
      _tabController = TabController(
        length: _groups.length,
        initialIndex: wanted < 0 ? 0 : wanted,
        vsync: this,
      )..addListener(_onTabChanged);
    }

    _searchCtl.addListener(() {
      final q = _searchCtl.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  void _onTabChanged() {
    // Fires on the first tap or swipe (and during the animation). Once the
    // user has moved between groups, the hint has done its job — drop it.
    if (_hintVisible) setState(() => _hintVisible = false);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _open(String? name) {
    HapticFeedback.selectionClick();
    widget.onSelectByName(name);
  }

  List<AllExerciseRowMock> _rowsIn(String group) =>
      widget.rows.where((r) => r.group == group).toList();

  ({String eyebrow, String title, String subtitle}) _editorialFor(String g) {
    final meta = libraryGroupEditorial[g];
    return (
      eyebrow: meta?.eyebrow ?? 'NHÓM CƠ',
      title: meta?.title ?? g,
      subtitle: meta?.subtitle ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final searching = _query.isNotEmpty;
    final tab = _tabController;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed dark hero — back, identity, search. Never rebuilt
          // structurally, so the search field keeps focus while typing.
          _CatalogHero(
            total: widget.rows.length,
            controller: _searchCtl,
            searching: searching,
          ),
          Expanded(
            // The tabs stay permanently mounted; search results overlay on
            // top. Swapping the TabBarView out of the tree would remount it
            // and re-trigger the jumpToPage-during-build crash.
            child: tab == null
                ? _SearchResults(
                    query: _query, rows: widget.rows, onSelect: _open)
                : Stack(
                    children: [
                      Column(
                        children: [
                          _GroupTabBar(
                            controller: tab,
                            labels: [
                              for (final g in _groups) _editorialFor(g).title,
                            ],
                          ),
                          _SwipeHint(visible: _hintVisible && !searching),
                          Expanded(
                            child: TabBarView(
                              controller: tab,
                              // Swiping the body moves the underline 1:1 —
                              // the affordance is the gesture itself.
                              children: [
                                for (final g in _groups)
                                  _GroupTab(
                                    group: g,
                                    editorial: _editorialFor(g),
                                    rows: _rowsIn(g),
                                    onSelect: _open,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (searching)
                        Positioned.fill(
                          child: ColoredBox(
                            color: c.bg,
                            child: _SearchResults(
                              query: _query,
                              rows: widget.rows,
                              onSelect: _open,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HERO — compact dark stage: back, eyebrow, italic title, search.
// ═══════════════════════════════════════════════════════════════

class _CatalogHero extends StatelessWidget {
  const _CatalogHero({
    required this.total,
    required this.controller,
    required this.searching,
  });

  final int total;
  final TextEditingController controller;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
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
              blurRadius: 30,
              offset: const Offset(0, 8),
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
                // Top bar — back + section wordmark.
                Padding(
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
                        'VIKA  ·  KHO BÀI TẬP',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: c.invInkSoft,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 38),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
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
                                  'TOÀN BỘ THƯ VIỆN',
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
                            const SizedBox(height: 10),
                            Text(
                              'Kho bài tập',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -1.8,
                                height: 0.95,
                                color: c.invInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              total.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                height: 1,
                                letterSpacing: -1.5,
                                color: c.invInk,
                                fontFeatures: VikaIvoryMain.tabularFigures,
                              ),
                            ),
                            Text(
                              'BÀI',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: c.invInkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: _SearchField(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 18, color: c.invInkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: c.yellow,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: c.invInk,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: InputBorder.none,
                hintText: 'Tìm trong toàn bộ kho bài',
                hintStyle: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.invInkSoft,
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
                child:
                    Icon(Icons.close_rounded, size: 16, color: c.invInkSoft),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.tooltip});
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: c.invInk),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB BAR — one tab per muscle group. Scrollable so the next tab
// peeks at the edge; yellow underline tracks the active group and
// the swipe.
// ═══════════════════════════════════════════════════════════════

class _GroupTabBar extends StatelessWidget {
  const _GroupTabBar({required this.controller, required this.labels});
  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        indicatorColor: c.yellow,
        labelColor: c.ink,
        unselectedLabelColor: c.inkFaint,
        labelStyle: const TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          for (final label in labels)
            Tab(height: 46, child: Text(label)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GROUP TAB — one group's body. Owns its own scroll view, so
// switching groups never resizes a shared block (no jump).
// ═══════════════════════════════════════════════════════════════

class _GroupTab extends StatelessWidget {
  const _GroupTab({
    required this.group,
    required this.editorial,
    required this.rows,
    required this.onSelect,
  });

  final String group;
  final ({String eyebrow, String title, String subtitle}) editorial;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Stop this list's scroll notifications from bubbling up into the
    // TabBarView, which otherwise misreads them and changes index mid-build.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: ListView(
        // Preserves each tab's scroll position across swipes.
        key: PageStorageKey<String>(group),
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 4, 20, 40 + bottomInset),
        children: [
          ExerciseGallerySection(
            eyebrow: editorial.eyebrow,
            title: editorial.title,
            subtitle: editorial.subtitle,
            rows: rows,
            onSelectByName: onSelect,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SWIPE HINT — a quiet caption that teaches the sideways gesture,
// then fades the first time the user changes tab.
// ═══════════════════════════════════════════════════════════════

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: visible
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_rounded, size: 15, color: c.inkFaint),
                    const SizedBox(width: 7),
                    Text(
                      'Vuốt trái / phải để đổi nhóm cơ',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH RESULTS — flat list across all groups (tabs hidden).
// ═══════════════════════════════════════════════════════════════

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.rows,
    required this.onSelect,
  });

  final String query;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final results = rows
        .where((r) =>
            r.name.toLowerCase().contains(query) ||
            r.cat.toLowerCase().contains(query) ||
            r.group.toLowerCase().contains(query))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                'Thử từ khoá khác, hoặc xoá để duyệt theo nhóm.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + bottomInset),
      itemCount: results.length + 1,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 6),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration:
                      BoxDecoration(color: c.yellow, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  '${results.length} KẾT QUẢ',
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
        final row = results[i - 1];
        return _ResultRow(row: row, onTap: () => onSelect(row.definitionName));
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.row, required this.onTap});
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                child: Icon(Icons.arrow_forward_rounded,
                    size: 12, color: c.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
