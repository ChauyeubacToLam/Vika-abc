// LibraryScreen — the "Khám phá" tab. Premium Ivory v4 (data-driven).
//
// FULLY SCALABLE composition: the screen iterates over
// [librarySections] from data/library_mock.dart. Each entry there
// declares one section (Featured / Rail / List / StatBand / Catalog)
// plus which filter kinds reveal it. Adding new content categories
// (new series, new goals, new content types) means appending to that
// list — no widget or screen code changes needed.
//
// The screen renders by dispatching on the sealed [LibrarySection]
// subclass via Dart 3 switch expressions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_mock.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../screens/exercise/exercise_launch_args.dart';
import '../services/user_profile_service.dart';
import '../services/workout_launch_service.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../widgets/library/library_album_rail.dart';
import '../widgets/library/library_card.dart';
import '../widgets/library/library_catalog_entry.dart';
import 'library_catalog_screen.dart';
import '../widgets/library/library_featured.dart';
import '../widgets/library/library_featured_carousel.dart';
import '../widgets/library/library_filter_chips.dart';
import '../widgets/library/library_list_card.dart';
import '../widgets/library/library_rail.dart';
import '../widgets/library/library_stage_hero.dart';
import '../widgets/library/library_stat_band.dart';
import '../widgets/library/library_tile_grid.dart';
import 'library_browse_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.bottomPadding,
    required this.onSelectExercise,
    this.userProfile,
  });

  final double bottomPadding;
  final void Function(ExerciseDefinition) onSelectExercise;
  final AppUserProfile? userProfile;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'all';
  final ScrollController _scrollController = ScrollController();
  final _launches = WorkoutLaunchService();
  bool _showStickyBar = false;

  /// Scroll offset (in logical px) past which the compact pill bar
  /// fades in. ~ where the stage hero's headline crosses the top.
  static const double _stickyBarThreshold = 230;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _stickyBarThreshold;
    if (shouldShow != _showStickyBar) {
      setState(() => _showStickyBar = shouldShow);
    }
  }

  void _onStickyBarTap() {
    // Snap back to the top — restores access to the full stage hero
    // (filter chips, headline, search icon) without a separate modal.
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  LibraryFilter get _activeFilter => libraryFilters.firstWhere(
        (f) => f.id == _selectedFilter,
        orElse: () => libraryFilters.first,
      );

  int get _totalLibraryCount =>
      libraryAlbumCards.length + libraryMockAllExercises.length;

  void _onSelectCard(LibraryCardData card) {
    final sequenceIds = card.sequenceExerciseIds;
    if (sequenceIds != null && sequenceIds.isNotEmpty) {
      unawaited(_launchCatalogSequence(sequenceIds));
      return;
    }

    if (card.exerciseName == null) {
      debugPrint(
          '[Library] Card "${card.title}" has no exerciseName; tap stubbed.');
      return;
    }
    _onSelectByName(card.exerciseName);
  }

  void _onSelectByName(String? name) {
    if (name == null) {
      debugPrint('[Library] Selected an entry without ExerciseDefinition.');
      return;
    }
    final def = lookupExerciseDefinition(name);
    if (def == null) {
      debugPrint('[Library] No ExerciseDefinition found for "$name".');
      return;
    }
    widget.onSelectExercise(def);
  }

  Future<void> _launchCatalogSequence(List<String> catalogIds) async {
    final sequence = await _launches.buildSequenceFromCatalogIds(catalogIds);
    if (!mounted) return;
    if (sequence.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Bộ tập này chưa có bài camera phù hợp.'),
        ));
      return;
    }

    final firstItem = sequence.first;
    final first = ExerciseLaunchArgs(
      definition: firstItem.definition,
      workoutSessionId: null,
      catalogExerciseId: firstItem.catalogExerciseId,
      catalogInfo: firstItem.catalogInfo,
      prescription: firstItem.prescription,
      recommendationId: firstItem.recommendationId,
      weekNumber: firstItem.weekNumber,
      sessionIndex: firstItem.sessionIndex,
      slotName: firstItem.slotName,
      sequence: sequence,
      sequenceIndex: 0,
    );
    await _runWorkoutSequence(first);
  }

  Future<bool> _runWorkoutSequence(ExerciseLaunchArgs first) async {
    ExerciseLaunchArgs? next = first;
    var completedFinalSlot = false;
    while (mounted && next != null) {
      final result = await Navigator.of(context).pushNamed(
        '/exercise',
        arguments: next,
      );
      if (!mounted) return false;
      if (result is Map && result['next'] is ExerciseLaunchArgs) {
        next = result['next'] as ExerciseLaunchArgs;
      } else {
        completedFinalSlot = result is Map && result['completed'] == true;
        next = null;
      }
    }
    return completedFinalSlot;
  }

  void _openBrowseTile(BrowseTileData tile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryBrowseScreen(
          tile: tile,
          onSelectExercise: widget.onSelectExercise,
          onSelectCard: _onSelectCard,
        ),
      ),
    );
  }

  /// Dispatches a [LibrarySection] to the appropriate widget. Adding a
  /// new section subclass requires adding ONE switch case here.
  Widget _buildSection(LibrarySection section) {
    return switch (section) {
      LibrarySectionFeatured() => LibraryFeatured(
          eyebrow: section.eyebrow,
          indexLabel: section.indexLabel,
          titleLine1: section.titleLine1,
          titleLine2: section.titleLine2,
          statChips: section.statChips,
          description: section.description,
          ctaLabel: section.ctaLabel,
          watermarkNumeral: section.watermarkNumeral,
          onTap: () => _onSelectCard(section.ctaTarget),
        ),
      LibrarySectionFeaturedCarousel() => LibraryFeaturedCarousel(
          slides: [
            for (final s in section.slides)
              LibraryFeaturedSlide(
                eyebrow: s.eyebrow,
                titleLine1: s.titleLine1,
                titleLine2: s.titleLine2,
                statChips: s.statChips,
                description: s.description,
                ctaLabel: s.ctaLabel,
                watermarkNumeral: s.watermarkNumeral,
                onTap: () => _onSelectCard(s.ctaTarget),
              ),
          ],
        ),
      LibrarySectionTileGrid() => LibraryTileGrid(
          eyebrow: section.eyebrow,
          meta: section.meta,
          intro: section.intro,
          tiles: section.tiles,
          onSelectTile: _openBrowseTile,
        ),
      LibrarySectionAlbumRail() => LibraryAlbumRail(
          eyebrow: section.eyebrow,
          meta: section.meta,
          intro: section.intro,
          cards: section.cards,
          onSelectCard: _onSelectCard,
        ),
      LibrarySectionRail() => LibraryRail(
          eyebrow: section.eyebrow,
          meta: section.meta,
          intro: section.intro,
          cards: section.cards,
          showIndices: section.showIndices,
          onSelectCard: _onSelectCard,
        ),
      LibrarySectionList() => LibraryListRail(
          eyebrow: section.eyebrow,
          meta: section.meta,
          intro: section.intro,
          cards: section.cards,
          descriptions: section.descriptions,
          onSelectCard: _onSelectCard,
        ),
      LibrarySectionStatBand() => LibraryStatBand(stats: section.stats),
      LibrarySectionCatalog() => _CatalogSection(
          eyebrow: section.eyebrow,
          meta: section.meta,
          rows: section.rows,
          onSelectByName: _onSelectByName,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      color: c.bg,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LibraryStageHero(
                    filters: libraryFilters,
                    selectedFilterId: _selectedFilter,
                    totalCount: _totalLibraryCount,
                    onSelectFilter: (id) =>
                        setState(() => _selectedFilter = id),
                    userInitial: widget.userProfile?.initial ?? 'N',
                    avatarUrl: widget.userProfile?.avatarUrl,
                  ),
                  // Canonical post-hero gap — matches Progress + Profile.
                  const SizedBox(height: 24),
                  // Iterate over the data-defined sections. Each visible
                  // section gets a 40px chapter break — same gap used
                  // across Progress + Profile so tabs read as one app.
                  for (final section in librarySections)
                    if (section.visibleFor(_selectedFilter)) ...[
                      _buildSection(section),
                      const SizedBox(height: 40),
                    ],
                  _Closer(onBackToTop: _onStickyBarTap),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _StickyPillBar(
              visible: _showStickyBar,
              activeFilter: _activeFilter,
              onTap: _onStickyBarTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION ADAPTERS — wrap legacy widgets in the section interface
// ═══════════════════════════════════════════════════════════════

class _CatalogSection extends StatelessWidget {
  const _CatalogSection({
    required this.eyebrow,
    required this.rows,
    required this.onSelectByName,
    this.meta,
  });

  final String eyebrow;
  final String? meta;
  final List<AllExerciseRowMock> rows;
  final void Function(String?) onSelectByName;

  void _openCatalog(BuildContext context, String? initialGroup) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryCatalogScreen(
          rows: rows,
          onSelectByName: onSelectByName,
          initialGroup: initialGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LibraryCatalogEntry(
      eyebrow: eyebrow,
      meta: meta,
      rows: rows,
      onSelectByName: onSelectByName,
      onOpenCatalog: (group) => _openCatalog(context, group),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STICKY PILL BAR — compact search + active filter, slides in after
// the user scrolls past the stage hero. Provides always-reachable
// discovery while protecting the cinematic stage hero entrance.
// ═══════════════════════════════════════════════════════════════

class _StickyPillBar extends StatelessWidget {
  const _StickyPillBar({
    required this.visible,
    required this.activeFilter,
    required this.onTap,
  });

  final bool visible;
  final LibraryFilter activeFilter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.4),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: Container(
            // Soft cream scrim behind the pill so content scrolling
            // underneath fades rather than collides with the bar.
            padding: EdgeInsets.fromLTRB(14, topInset + 10, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.bg.withValues(alpha: 0.96),
                  c.bg.withValues(alpha: 0.78),
                  c.bg.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: Material(
              elevation: 0,
              color: Colors.transparent,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.bgRaised,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.borderHi, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      // Brand mark — VIKA logo medallion so the bar is
                      // never anonymous.
                      Container(
                        width: 34,
                        height: 34,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: c.yellow.withValues(alpha: 0.36),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/branding/Logo.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: c.inkSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tìm bài tập, bộ tập…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.inkFaint,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ActiveFilterPill(filter: activeFilter),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterPill extends StatelessWidget {
  const _ActiveFilterPill({required this.filter});
  final LibraryFilter filter;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filter.label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: c.invInk,
            ),
          ),
          const SizedBox(width: 4),
          if (filter.count != null) ...[
            Text(
              '${filter.count}',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: c.yellow,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 14,
            color: c.invInkSoft,
          ),
        ],
      ),
    );
  }
}

class _Closer extends StatelessWidget {
  const _Closer({required this.onBackToTop});

  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: c.border)),
              const SizedBox(width: 14),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'VIKA · THƯ VIỆN',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: c.border)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mỗi tuần Vika thêm bài mới',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${libraryMockAllExercises.length} bài · ${libraryAlbumCards.length} bộ tập',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.inkFaint,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BackToTopButton(onTap: onBackToTop),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackToTopButton extends StatefulWidget {
  const _BackToTopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<_BackToTopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
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
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
          height: 40,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lên đầu',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: c.invInk,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: c.yellowInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
