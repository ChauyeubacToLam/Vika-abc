// ExerciseBrowser — the Library / Khám phá sheet (v2: polished,
// scalable, Netflix-style rails).
//
// Composition:
//   ┌─ Drag handle
//   ├─ SheetHeader (slim: THƯ VIỆN · 100 BÀI + close)
//   ├─ SheetSearch (compact, no keyboard shortcut chrome)
//   ├─ LibraryFilterChips (Tất cả · Lộ trình · Bộ sưu tập · …)
//   │
//   ├─ LibraryHero (1 large featured card — AI coach moment)
//   │
//   ├─ LibraryRail (LỘ TRÌNH · Đang chạy) ── horizontal scroll
//   ├─ LibraryRail (BỘ SƯU TẬP)            ── horizontal scroll
//   ├─ LibraryRail (CAMERA AI)             ── horizontal scroll
//   │
//   ├─ AllExercisesGrid (KHO BÀI TẬP — catalog)
//   └─ Editorial closer
//
// Every horizontal rail uses the SAME LibraryCard template. Adding new
// rails (new series, new goals, new types) just means new data — no UI
// changes. That's the scalability the user asked for.

import 'package:flutter/material.dart';
import '../data/library_mock.dart';
import '../models/exercise_definition.dart';
import '../services/catalog/catalog_source.dart';
import '../models/exercise_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../widgets/library/all_exercises_grid.dart';
import '../widgets/library/library_card.dart';
import '../widgets/library/library_filter_chips.dart';
import '../widgets/library/library_hero.dart';
import '../widgets/library/library_rail.dart';
import '../widgets/library/sheet_chrome.dart';

class ExerciseBrowser extends StatefulWidget {
  const ExerciseBrowser({
    super.key,
    required this.bottomPadding,
    required this.onClose,
    required this.onSelectExercise,
  });

  final double bottomPadding;
  final VoidCallback onClose;
  final void Function(ExerciseDefinition) onSelectExercise;

  @override
  State<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends State<ExerciseBrowser>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late final AnimationController _snapBackController;
  Animation<double>? _snapBackAnim;
  String _selectedFilter = 'all';

  static const double _dismissDistanceThreshold = 100;
  static const double _dismissVelocityThreshold = 600;

  @override
  void initState() {
    super.initState();
    // Catalog is preloaded in main(); ensure here too so list volume labels
    // resolve even if this screen is reached first, then rebuild once ready.
    CatalogSource.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_snapBackAnim != null) {
          setState(() => _dragOffset = _snapBackAnim!.value);
        }
      });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 800);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss = _dragOffset > _dismissDistanceThreshold ||
        velocity > _dismissVelocityThreshold;
    if (shouldDismiss) {
      widget.onClose();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _dragOffset = 0);
      });
    } else {
      _snapBackAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(
          parent: _snapBackController,
          curve: Curves.easeOutCubic,
        ),
      );
      _snapBackController
        ..reset()
        ..forward();
    }
  }

  void _onSelectCard(LibraryCardData card) {
    if (card.exerciseName == null) {
      // Programs / collections / yoga without a wired exercise. Stubbed
      // for now — could open a detail sheet later.
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

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: c.ink.withValues(
                alpha: (0.4 * (1 - (_dragOffset / 400))).clamp(0.0, 0.4),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: FractionallySizedBox(
              heightFactor: 0.94,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: Column(
                        children: [
                          const SheetDragHandle(),
                          SheetHeader(
                            onClose: widget.onClose,
                            totalCount: 100,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: widget.bottomPadding + 24,
                        ),
                        child: _SheetBody(
                          selectedFilter: _selectedFilter,
                          onSelectFilter: (id) =>
                              setState(() => _selectedFilter = id),
                          onSelectCard: _onSelectCard,
                          onSelectByName: _onSelectByName,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.selectedFilter,
    required this.onSelectFilter,
    required this.onSelectCard,
    required this.onSelectByName,
  });

  final String selectedFilter;
  final ValueChanged<String> onSelectFilter;
  final ValueChanged<LibraryCardData> onSelectCard;
  final void Function(String?) onSelectByName;

  bool _railVisible(String kindFilterId) {
    // 'all' shows every rail; other filters reveal only the matching rail.
    return selectedFilter == 'all' || selectedFilter == kindFilterId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSearch(),
        const SizedBox(height: 14),
        LibraryFilterChips(
          filters: libraryFilters,
          selectedId: selectedFilter,
          onSelect: onSelectFilter,
        ),
        const SizedBox(height: 24),
        if (selectedFilter == 'all' || selectedFilter == 'ai') ...[
          LibraryHero(
            eyebrow: 'CAMERA AI · NỔI BẬT',
            titleLine1: 'Tập có',
            titleLine2: 'huấn luyện.',
            subtitle:
                'Camera Vika theo dõi tư thế theo thời gian thực. 20 bài có AI.',
            ctaLabel: 'Khám phá',
            onTap: () => debugPrint('[Library] AI hero tapped (stubbed).'),
          ),
          const SizedBox(height: 32),
        ],
        if (_railVisible('program')) ...[
          LibraryRail(
            eyebrow: 'LỘ TRÌNH',
            meta: '${libraryProgramCards.length} lộ trình',
            cards: libraryProgramCards,
            onSelectCard: onSelectCard,
            cardWidth: 156,
          ),
          const SizedBox(height: 28),
        ],
        if (_railVisible('collection')) ...[
          LibraryRail(
            eyebrow: 'BỘ SƯU TẬP',
            meta: '${libraryCollectionCards.length} bộ',
            cards: libraryCollectionCards,
            onSelectCard: onSelectCard,
            cardWidth: 156,
          ),
          const SizedBox(height: 28),
        ],
        if (_railVisible('ai') || _railVisible('exercise')) ...[
          LibraryRail(
            eyebrow: 'CÓ CAMERA AI',
            meta: '${libraryAiExerciseCards.length} bài',
            cards: libraryAiExerciseCards,
            onSelectCard: onSelectCard,
            cardWidth: 156,
          ),
          const SizedBox(height: 28),
        ],
        // Full catalog list — always visible regardless of filter.
        const _CatalogHeader(),
        AllExercisesGrid(
          rows: libraryMockAllExercises,
          onSelectByName: onSelectByName,
        ),
        // Editorial closer
        const SizedBox(height: 32),
        const _Closer(),
      ],
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
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
            'KHO BÀI TẬP',
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
          const SizedBox(width: 14),
          Text(
            '${libraryMockAllExercises.length} BÀI',
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
      ),
    );
  }
}

class _Closer extends StatelessWidget {
  const _Closer();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
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
          const SizedBox(width: 10),
          Text(
            'Mỗi tuần thêm bài mới',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: c.border)),
        ],
      ),
    );
  }
}
