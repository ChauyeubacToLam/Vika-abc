// Mock data for the Library / Khám phá sheet.
//
// v2 (current): unified [LibraryCardData] lists, one per rail, plus the
// catalog data + filters. This is the SCALABLE shape — adding a new
// rail means adding a new `List<LibraryCardData>`, no widget changes.
//
// v1 (legacy): ProgramMock / IntentCollectionMock / CollectionExerciseMock
// kept below so old widget files (ai_spotlight, programs_rail,
// intent_collection) still compile while they're orphaned. They can be
// deleted later.

import 'package:flutter/material.dart';

import '../widgets/ivory/atoms.dart';
import '../widgets/library/library_card.dart';
import '../widgets/library/library_filter_chips.dart';
import '../widgets/library/library_stat_band.dart';

// ═══════════════════════════════════════════════════════════════
// V2 — unified scalable data
// ═══════════════════════════════════════════════════════════════

const List<LibraryFilter> libraryFilters = [
  LibraryFilter(id: 'all', label: 'Tất cả', count: 100),
  LibraryFilter(id: 'program', label: 'Lộ trình', count: 4),
  LibraryFilter(id: 'collection', label: 'Bộ sưu tập', count: 6),
  LibraryFilter(id: 'exercise', label: 'Bài tập', count: 80),
  LibraryFilter(id: 'ai', label: 'Có camera AI', count: 20),
  LibraryFilter(id: 'yoga', label: 'Yoga', count: 50),
];

/// Active and upcoming multi-week programs.
const List<LibraryCardData> libraryProgramCards = [
  LibraryCardData(
    kind: LibraryCardKind.program,
    title: 'Khởi đầu',
    duration: '4 tuần',
    detail: '12 buổi',
    tag: 'Đang chạy',
    icon: Icons.flag_rounded,
  ),
  LibraryCardData(
    kind: LibraryCardKind.program,
    title: 'Khoẻ lưng',
    duration: '21 ngày',
    detail: '14 buổi',
    icon: Icons.straighten_rounded,
  ),
  LibraryCardData(
    kind: LibraryCardKind.program,
    title: 'Yoga sáng',
    duration: '14 ngày',
    detail: '14 buổi',
    icon: Icons.wb_sunny_outlined,
  ),
  LibraryCardData(
    kind: LibraryCardKind.program,
    title: 'Reset tối',
    duration: '14 ngày',
    detail: '7 buổi',
    tag: 'Sắp ra mắt',
    icon: Icons.nightlight_round,
  ),
];

/// Intent-based collections (sortable buckets — by time, mood, goal).
/// The "8 phút / 12 phút" specificity from v1 is replaced by general
/// intent labels so the category scales — new collections drop in
/// without redesigning.
const List<LibraryCardData> libraryCollectionCards = [
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Khởi động sáng',
    duration: '8 phút',
    detail: '5 bài',
    icon: Icons.wb_twilight_rounded,
    hasAi: true,
  ),
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Reset bàn làm việc',
    duration: '5 phút',
    detail: '4 bài',
    icon: Icons.chair_rounded,
    hasAi: true,
  ),
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Tối yên',
    duration: '12 phút',
    detail: '6 tư thế',
    icon: Icons.nightlight_round,
  ),
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Vai cổ thư giãn',
    duration: '7 phút',
    detail: '5 bài',
    icon: Icons.self_improvement_rounded,
  ),
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Năng lượng nhanh',
    duration: '4 phút',
    detail: '3 bài',
    icon: Icons.bolt_rounded,
    hasAi: true,
  ),
];

/// "Mới tuần này" — temporal freshness rail. Curators rotate weekly;
/// the corner `tag` doubles as a date stamp.
const List<LibraryCardData> libraryWhatsNewCards = [
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Tỉnh sáng',
    duration: '6 phút',
    detail: '4 bài',
    icon: Icons.wb_twilight_rounded,
    tag: 'MỚI · T7',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Bird Dog',
    duration: '3 × 12',
    detail: 'Cốt lõi · lưng',
    icon: Icons.pets_rounded,
    hasAi: true,
    tag: 'MỚI · T6',
  ),
  LibraryCardData(
    kind: LibraryCardKind.collection,
    title: 'Hông tự do',
    duration: '8 phút',
    detail: '5 bài',
    icon: Icons.open_with_rounded,
    tag: 'MỚI · T5',
  ),
  LibraryCardData(
    kind: LibraryCardKind.album,
    title: 'Phục hồi',
    icon: Icons.healing_rounded,
    episodeCount: 8,
    episodeMeta: '6-8 phút mỗi tập',
    tag: 'MỚI',
  ),
];

/// Multi-episode series ("albums"). Distinct tier from program /
/// collection — episodic arcs with internal sequence.
const List<LibraryCardData> libraryAlbumCards = [
  LibraryCardData(
    kind: LibraryCardKind.album,
    title: 'Phục hồi',
    icon: Icons.healing_rounded,
    episodeCount: 8,
    episodeMeta: '6-8 phút mỗi tập',
  ),
  LibraryCardData(
    kind: LibraryCardKind.album,
    title: 'Linh hoạt',
    icon: Icons.self_improvement_rounded,
    episodeCount: 12,
    episodeMeta: '5-10 phút mỗi tập',
  ),
  LibraryCardData(
    kind: LibraryCardKind.album,
    title: 'Sức mạnh',
    icon: Icons.fitness_center_rounded,
    episodeCount: 10,
    episodeMeta: '8-12 phút mỗi tập',
  ),
  LibraryCardData(
    kind: LibraryCardKind.album,
    title: 'Bình tĩnh',
    icon: Icons.air_rounded,
    episodeCount: 6,
    episodeMeta: '5-7 phút mỗi tập',
  ),
  LibraryCardData(
    kind: LibraryCardKind.album,
    title: 'Năng lượng',
    icon: Icons.bolt_rounded,
    episodeCount: 7,
    episodeMeta: '4-6 phút mỗi tập',
  ),
];

/// Featured exercises with camera-AI form coaching.
const List<LibraryCardData> libraryAiExerciseCards = [
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Squat',
    duration: '3 × 10',
    detail: 'Chân · hông',
    icon: Icons.accessibility_new_rounded,
    hasAi: true,
    exerciseName: 'Squat',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Push Up',
    duration: '3 × 8',
    detail: 'Ngực · vai',
    icon: Icons.fitness_center_rounded,
    hasAi: true,
    exerciseName: 'Push Up',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Plank',
    duration: '3 × 30s',
    detail: 'Cốt lõi',
    icon: Icons.horizontal_rule_rounded,
    hasAi: true,
    exerciseName: 'Plank',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Lunge',
    duration: '3 × 10',
    detail: 'Chân · mông',
    icon: Icons.directions_walk_rounded,
    hasAi: true,
    exerciseName: 'Lunge',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Glute Bridge',
    duration: '3 × 15',
    detail: 'Mông · lưng',
    icon: Icons.height_rounded,
    hasAi: true,
    exerciseName: 'Glute Bridge',
  ),
];

// ═══════════════════════════════════════════════════════════════
// CATALOG — vertical list at the bottom of the sheet
// ═══════════════════════════════════════════════════════════════

@immutable
class AllExerciseRowMock {
  const AllExerciseRowMock({
    required this.idx,
    required this.name,
    required this.cat,
    required this.diff,
    required this.glyph,
    required this.group,
    this.ai = false,
    this.yoga = false,
    this.definitionName,
  });
  final int idx;
  final String name;
  final String cat;
  final String diff;
  final PoseGlyphType glyph;
  final bool ai;
  final bool yoga;
  final String? definitionName;

  /// Group label used by the grouped catalog. e.g. 'CHÂN · MÔNG',
  /// 'CỐT LÕI', 'YOGA'. Curators can mint new groups freely — the
  /// catalog widget renders whatever shows up.
  final String group;
}

/// Canonical group order in the catalog. Groups appearing in
/// [libraryMockAllExercises] but missing here are appended in
/// first-seen order.
const List<String> libraryCatalogGroupOrder = [
  'CHÂN · MÔNG',
  'CỐT LÕI',
  'NGỰC · VAI',
  'LƯNG · CỔ',
  'CARDIO',
  'YOGA',
];

const List<AllExerciseRowMock> libraryMockAllExercises = [
  AllExerciseRowMock(
    idx: 1,
    name: 'Squat',
    cat: 'Phân tích tư thế · 3×10',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'Squat',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 2,
    name: 'Push Up',
    cat: 'Ngực · Vai · Core · 15 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.wallPushUp,
    definitionName: 'Push Up',
    group: 'NGỰC · VAI',
  ),
  AllExerciseRowMock(
    idx: 3,
    name: 'Plank',
    cat: 'McGill Short-Hold · 3×10s',
    diff: 'Dễ – Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Plank',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 4,
    name: 'Lunge',
    cat: 'Đùi · Mông · Hamstring · 10 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Lunge',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 5,
    name: 'Glute Bridge',
    cat: 'Mông · Lưng dưới · 15 reps',
    diff: 'Dễ – Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Glute Bridge',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 6,
    name: 'McGill Curl-up',
    cat: 'Core ổn định · 12 reps',
    diff: 'Dễ – Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'McGill Curl-up',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 7,
    name: 'Jumping Jack',
    cat: 'Cardio nhẹ · 30 reps',
    diff: 'Dễ',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Jumping Jack',
    group: 'CARDIO',
  ),
  AllExerciseRowMock(
    idx: 8,
    name: 'Gập trước đứng',
    cat: 'Yoga · 30s',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 9,
    name: 'Rắn hổ mang',
    cat: 'Yoga · 20s',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 10,
    name: 'Chó cúi mặt',
    cat: 'Yoga · 5 phút',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 11,
    name: 'Tư thế em bé',
    cat: 'Yoga · 3 phút',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
    group: 'YOGA',
  ),
];

// ═══════════════════════════════════════════════════════════════
// LEGACY v1 — kept so orphaned old widgets still compile. Delete
// after dropping ai_spotlight / programs_rail / intent_collection.
// ═══════════════════════════════════════════════════════════════

@immutable
class ProgramMock {
  const ProgramMock({
    required this.idx,
    required this.name,
    required this.dur,
    required this.sessions,
    required this.diff,
    required this.tagline,
    this.tag,
    this.tone = ProgramTone.cream,
  });
  final String idx;
  final String name;
  final String dur;
  final String sessions;
  final String diff;
  final String tagline;
  final String? tag;
  final ProgramTone tone;
}

enum ProgramTone { current, dark, cream }

@immutable
class CollectionExerciseMock {
  const CollectionExerciseMock({
    required this.name,
    required this.glyph,
    required this.meta,
    this.ai = false,
    this.yoga = false,
  });
  final String name;
  final PoseGlyphType glyph;
  final String meta;
  final bool ai;
  final bool yoga;
}

@immutable
class IntentCollectionMock {
  const IntentCollectionMock({
    required this.idx,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.hero,
    required this.small,
  });
  final String idx;
  final String eyebrow;
  final String title;
  final String subtitle;
  final CollectionExerciseMock hero;
  final List<CollectionExerciseMock> small;
}

const List<ProgramMock> libraryMockPrograms = [];
const List<IntentCollectionMock> libraryMockCollections = [];
const List<({String id, String label, int count})> libraryMockFilters = [];

// ═══════════════════════════════════════════════════════════════
// SCALABLE PAGE COMPOSITION — data-driven section list
// ═══════════════════════════════════════════════════════════════
//
// The Library screen renders by iterating over [librarySections]. Each
// entry is one [LibrarySection] subclass — Featured / Rail / List /
// StatBand / Catalog. Adding new content (a new series, a new goal
// category, a new featured promo) means ADDING TO THE LIST — no
// changes to widget code or screen code required.
//
// Each section declares which filter kinds reveal it via
// [filterKinds]. When the user picks "Tất cả" everything shows; when
// they pick a specific filter, only sections whose filterKinds contain
// the selected id show.
//
// Stats inside the StatBand DERIVE from data, so adding new content
// auto-updates the stats without manual editing.

sealed class LibrarySection {
  const LibrarySection({this.filterKinds = const []});

  /// Filter IDs that reveal this section. Empty = always visible. The
  /// 'all' filter selection always shows everything regardless.
  final List<String> filterKinds;

  bool visibleFor(String selectedFilterId) {
    if (filterKinds.isEmpty) return true;
    if (selectedFilterId == 'all') return true;
    return filterKinds.contains(selectedFilterId);
  }
}

/// Magazine-cover featured card — one big editorial moment.
@immutable
class LibrarySectionFeatured extends LibrarySection {
  const LibrarySectionFeatured({
    required this.eyebrow,
    required this.indexLabel,
    required this.titleLine1,
    required this.titleLine2,
    required this.statChips,
    required this.description,
    required this.ctaLabel,
    required this.ctaTarget,
    this.watermarkNumeral,
    super.filterKinds,
  });

  final String eyebrow;
  final String indexLabel;
  final String titleLine1;
  final String titleLine2;
  final List<String> statChips;
  final String description;
  final String ctaLabel;
  final LibraryCardData ctaTarget;
  final String? watermarkNumeral;
}

/// Data-only payload for one slide of the featured carousel. The screen
/// turns this into a `LibraryFeaturedSlide` with the resolved onTap.
@immutable
class LibraryFeaturedSlideData {
  const LibraryFeaturedSlideData({
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.statChips,
    required this.description,
    required this.ctaLabel,
    required this.ctaTarget,
    this.watermarkNumeral,
  });

  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final List<String> statChips;
  final String description;
  final String ctaLabel;
  final LibraryCardData ctaTarget;
  final String? watermarkNumeral;
}

/// Swipeable carousel of editorial featured covers. Curators rotate
/// 3–5 picks; pagination dots track active slide.
@immutable
class LibrarySectionFeaturedCarousel extends LibrarySection {
  const LibrarySectionFeaturedCarousel({
    required this.slides,
    super.filterKinds,
  });
  final List<LibraryFeaturedSlideData> slides;
}

/// One cell in the "Duyệt nhanh" facet tile grid. Tapping deep-links to
/// a `LibraryBrowseScreen` with the matching content list.
@immutable
class BrowseTileData {
  const BrowseTileData({
    required this.id,
    required this.label,
    required this.icon,
    required this.count,
    this.eyebrow,
    this.breakdown,
  });
  final String id;
  final String label;
  final IconData icon;
  final int count;
  final String? eyebrow;

  /// Editorial type-breakdown line, e.g. "12 BÀI · 2 LT". Optional; if
  /// omitted, the tile uses [count] as a single italic numeral.
  final String? breakdown;
}

/// The 2×3 facet grid section ("Duyệt nhanh"). Sits below the carousel
/// and absorbs scale — taps deep-link, the home stays fixed-size.
@immutable
class LibrarySectionTileGrid extends LibrarySection {
  const LibrarySectionTileGrid({
    required this.eyebrow,
    required this.tiles,
    this.meta,
    this.intro,
    super.filterKinds,
  });
  final String eyebrow;
  final String? meta;
  final String? intro;
  final List<BrowseTileData> tiles;
}

/// Horizontal rail of multi-episode "album / series" cards (3:4 portrait
/// with overlaid title). A distinct tier from programs and collections.
@immutable
class LibrarySectionAlbumRail extends LibrarySection {
  const LibrarySectionAlbumRail({
    required this.eyebrow,
    required this.cards,
    this.meta,
    this.intro,
    super.filterKinds,
  });
  final String eyebrow;
  final String? meta;
  final String? intro;
  final List<LibraryCardData> cards;
}


/// Horizontal-scroll row of [LibraryCard]s.
@immutable
class LibrarySectionRail extends LibrarySection {
  const LibrarySectionRail({
    required this.eyebrow,
    required this.cards,
    this.meta,
    this.intro,
    this.showIndices = false,
    super.filterKinds,
  });

  final String eyebrow;
  final String? meta;

  /// Optional italic one-liner that sits below the section rule —
  /// editorial framing that tells the reader *why* this section exists.
  final String? intro;

  final List<LibraryCardData> cards;
  final bool showIndices;
}

/// Vertical magazine list — varies the page's visual rhythm.
@immutable
class LibrarySectionList extends LibrarySection {
  const LibrarySectionList({
    required this.eyebrow,
    required this.cards,
    required this.descriptions,
    this.meta,
    this.intro,
    super.filterKinds,
  });

  final String eyebrow;
  final String? meta;
  final String? intro;
  final List<LibraryCardData> cards;

  /// Parallel-indexed with [cards]; one description per card.
  final List<String> descriptions;
}

/// Editorial stat divider between major sections.
@immutable
class LibrarySectionStatBand extends LibrarySection {
  const LibrarySectionStatBand({
    required this.stats,
    super.filterKinds,
  });

  final List<LibraryStat> stats;
}

/// Bottom catalog list — the "completionist" tail (uses the existing
/// AllExercisesGrid behind the scenes).
@immutable
class LibrarySectionCatalog extends LibrarySection {
  const LibrarySectionCatalog({
    required this.eyebrow,
    required this.rows,
    this.meta,
    super.filterKinds,
  });

  final String eyebrow;
  final String? meta;
  final List<AllExerciseRowMock> rows;
}

// ─────────────────────────────────────────────────────────────
// The page composition. Add a new section here to extend the page.
// ─────────────────────────────────────────────────────────────

final List<LibrarySection> librarySections = [
  // Editorial carousel — 4 swipeable editor's-pick covers. Reorder /
  // append to rotate weekly without screen code changes.
  const LibrarySectionFeaturedCarousel(
    slides: [
      LibraryFeaturedSlideData(
        eyebrow: 'TUẦN NÀY · GỢI Ý',
        titleLine1: 'Khoẻ',
        titleLine2: 'lưng.',
        statChips: ['21 ngày', '14 buổi', 'Cơ bản'],
        description:
            'Phục hồi cốt lõi và hông. Cho lưng dưới hết đau sau giờ ngồi cả ngày.',
        ctaLabel: 'Bắt đầu lộ trình',
        watermarkNumeral: '01',
        ctaTarget: LibraryCardData(
          kind: LibraryCardKind.program,
          title: 'Khoẻ lưng',
          duration: '21 ngày',
          detail: '14 buổi',
          icon: Icons.straighten_rounded,
        ),
      ),
      LibraryFeaturedSlideData(
        eyebrow: 'ĐIỂM BẮT ĐẦU',
        titleLine1: 'Khởi',
        titleLine2: 'đầu.',
        statChips: ['4 tuần', '12 buổi', 'Người mới'],
        description:
            'Lộ trình nền tảng cho người mới. Tập dáng, nhịp thở, và những bài cơ bản.',
        ctaLabel: 'Bắt đầu hành trình',
        watermarkNumeral: '02',
        ctaTarget: LibraryCardData(
          kind: LibraryCardKind.program,
          title: 'Khởi đầu',
          duration: '4 tuần',
          detail: '12 buổi',
          tag: 'Đang chạy',
          icon: Icons.flag_rounded,
        ),
      ),
      LibraryFeaturedSlideData(
        eyebrow: 'GIỜ LÀM · 5 PHÚT',
        titleLine1: 'Reset',
        titleLine2: 'bàn.',
        statChips: ['5 phút', '4 bài', 'Có AI'],
        description:
            'Bốn động tác nhanh giữa giờ làm. Không cần thay đồ, không cần mat.',
        ctaLabel: 'Tập ngay',
        watermarkNumeral: '03',
        ctaTarget: LibraryCardData(
          kind: LibraryCardKind.collection,
          title: 'Reset bàn làm việc',
          duration: '5 phút',
          detail: '4 bài',
          icon: Icons.chair_rounded,
          hasAi: true,
        ),
      ),
      LibraryFeaturedSlideData(
        eyebrow: 'CAMERA AI · TƯ THẾ',
        titleLine1: 'Squat',
        titleLine2: 'chuẩn.',
        statChips: ['3 × 10', 'Chân · hông', 'Có AI'],
        description:
            'Camera Vika theo dõi gối, hông, lưng theo thời gian thực. Sửa form khi tập.',
        ctaLabel: 'Mở camera',
        watermarkNumeral: '04',
        ctaTarget: LibraryCardData(
          kind: LibraryCardKind.exercise,
          title: 'Squat',
          duration: '3 × 10',
          detail: 'Chân · hông',
          icon: Icons.accessibility_new_rounded,
          hasAi: true,
          exerciseName: 'Squat',
        ),
      ),
    ],
    filterKinds: ['all'],
  ),
  // Scale absorber — facet tiles deep-link into LibraryBrowseScreen so
  // the home tab stays fixed-size while content can grow indefinitely.
  // Add tiles to expose new facets without touching the home page.
  const LibrarySectionTileGrid(
    eyebrow: 'DUYỆT NHANH',
    meta: '6 phân loại',
    intro: 'Chọn theo phần thân hoặc cảm giác. Sáu lối tắt vào kho.',
    tiles: [
      BrowseTileData(
        id: 'lower',
        label: 'Chân · Mông',
        eyebrow: 'PHẦN THÂN',
        icon: Icons.directions_walk_rounded,
        count: 12,
        breakdown: '12 BÀI · 1 LỘ TRÌNH',
      ),
      BrowseTileData(
        id: 'core',
        label: 'Cốt lõi',
        eyebrow: 'PHẦN THÂN',
        icon: Icons.horizontal_rule_rounded,
        count: 8,
        breakdown: '8 BÀI · 1 ALBUM',
      ),
      BrowseTileData(
        id: 'back',
        label: 'Lưng · Cổ',
        eyebrow: 'PHỤC HỒI',
        icon: Icons.straighten_rounded,
        count: 9,
        breakdown: '9 BÀI · 1 LT · 1 BST',
      ),
      BrowseTileData(
        id: 'yoga',
        label: 'Yoga',
        eyebrow: 'THƯ GIÃN',
        icon: Icons.self_improvement_rounded,
        count: 50,
        breakdown: '50 BÀI · 1 LT · 1 BST',
      ),
      BrowseTileData(
        id: 'ai',
        label: 'Có camera AI',
        eyebrow: 'TƯ THẾ',
        icon: Icons.center_focus_strong_rounded,
        count: 20,
        breakdown: '20 BÀI · CÓ AI',
      ),
      BrowseTileData(
        id: 'short',
        label: '≤ 10 phút',
        eyebrow: 'GIỜ LÀM',
        icon: Icons.access_time_rounded,
        count: 18,
        breakdown: '18 BÀI · NHANH',
      ),
    ],
    filterKinds: ['all'],
  ),
  LibrarySectionRail(
    eyebrow: 'LỘ TRÌNH',
    meta: '${libraryProgramCards.length} lộ trình',
    intro:
        'Có lịch, có cấu trúc. Mỗi tuần một mục tiêu, đi xuyên nhiều buổi.',
    cards: libraryProgramCards,
    showIndices: true,
    filterKinds: const ['program'],
  ),
  // Dark portrait album rail — strong visual chapter break between
  // cream rails. Series live here, episodic content gets its own tier.
  LibrarySectionAlbumRail(
    eyebrow: 'ALBUM & SERIES',
    meta: '${libraryAlbumCards.length} BỘ',
    intro:
        'Tuyển tập nhiều tập. Tập theo thứ tự — như nghe trọn một đĩa nhạc.',
    cards: libraryAlbumCards,
    filterKinds: const ['all', 'collection'],
  ),
  // Stats derived from data — adding a new card to any list
  // auto-updates the band.
  LibrarySectionStatBand(
    stats: [
      const LibraryStat(value: '100', label: 'Bài tập'),
      LibraryStat(
        value: '${libraryAiExerciseCards.length * 4}',
        label: 'Có AI',
      ),
      LibraryStat(
        value: '${libraryCollectionCards.length}',
        label: 'Bộ sưu tập',
      ),
      LibraryStat(
        value: '${libraryProgramCards.length}',
        label: 'Lộ trình',
      ),
    ],
    filterKinds: const ['all'],
  ),
  LibrarySectionList(
    eyebrow: 'BỘ SƯU TẬP',
    meta: '${libraryCollectionCards.length} bộ',
    intro:
        'Bài ngắn cho một mạch. Không cần thay đồ, không cần mat — vào là tập.',
    cards: libraryCollectionCards,
    descriptions: const [
      'Năm bài để cơ thể tỉnh dậy trước khi ngồi vào bàn.',
      'Bốn động tác nhanh giữa giờ. Không cần thay đồ.',
      'Sáu tư thế yoga giúp hạ nhịp tim, dễ ngủ.',
      'Năm bài nhẹ nhàng cho vai và cổ sau giờ làm.',
      'Ba bài cường độ cao để bùng nổ năng lượng.',
    ],
    filterKinds: const ['collection'],
  ),
  LibrarySectionRail(
    eyebrow: 'CÓ CAMERA AI',
    meta: '${libraryAiExerciseCards.length} bài',
    intro:
        'Vika nhìn dáng, đếm rep, sửa form theo thời gian thực — như có HLV bên cạnh.',
    cards: libraryAiExerciseCards,
    showIndices: true,
    filterKinds: const ['ai', 'exercise'],
  ),
  // Temporal freshness rail — reuses the standard rail, the tag field
  // carries the weekly date stamp ("MỚI · T7" etc.).
  LibrarySectionRail(
    eyebrow: 'MỚI TUẦN NÀY',
    meta: '${libraryWhatsNewCards.length} mới',
    intro: 'Vừa thêm vào kho. Khám phá trước trong tuần này.',
    cards: libraryWhatsNewCards,
    filterKinds: const ['all'],
  ),
  LibrarySectionCatalog(
    eyebrow: 'KHO BÀI TẬP',
    meta: '${libraryMockAllExercises.length} BÀI',
    rows: libraryMockAllExercises,
    // No filterKinds → always visible (the completionist tail).
  ),
];
