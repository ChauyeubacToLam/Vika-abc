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

import 'vika_albums.dart';
import '../widgets/ivory/atoms.dart';
import '../widgets/library/library_card.dart';
import '../widgets/library/library_filter_chips.dart';
import '../widgets/library/library_stat_band.dart';

// ═══════════════════════════════════════════════════════════════
// V2 — unified scalable data
// ═══════════════════════════════════════════════════════════════

const List<LibraryFilter> libraryFilters = [
  LibraryFilter(id: 'all', label: 'Tất cả', count: 44),
  LibraryFilter(id: 'album', label: 'Bộ tập', count: 10),
  LibraryFilter(id: 'exercise', label: 'Bài tập', count: 34),
  LibraryFilter(id: 'ai', label: 'Có camera AI', count: 34),
  LibraryFilter(id: 'yoga', label: 'Yoga', count: 6),
];

/// Legacy buckets kept empty so old orphaned widgets compile without
/// rendering fabricated programs / collections / weekly-new rails.
const List<LibraryCardData> libraryProgramCards = [];
const List<LibraryCardData> libraryCollectionCards = [];
const List<LibraryCardData> libraryWhatsNewCards = [];

/// Curated back-to-back albums. Source of truth lives in vika_albums.dart.
final List<LibraryCardData> libraryAlbumCards = vikaAlbumCards;

/// Featured exercises with camera-AI form coaching.
const List<LibraryCardData> libraryAiExerciseCards = [
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Squat',
    duration: '15 rep',
    detail: 'Chân · hông',
    icon: Icons.accessibility_new_rounded,
    hasAi: true,
    exerciseName: 'squat',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Chống đẩy',
    duration: '10 rep',
    detail: 'Ngực · vai',
    icon: Icons.fitness_center_rounded,
    hasAi: true,
    exerciseName: 'push_up',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Plank',
    duration: '30 giây',
    detail: 'Cốt lõi',
    icon: Icons.horizontal_rule_rounded,
    hasAi: true,
    exerciseName: 'plank',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Chùng chân',
    duration: '10 rep',
    detail: 'Chân · mông',
    icon: Icons.directions_walk_rounded,
    hasAi: true,
    exerciseName: 'lunge',
  ),
  LibraryCardData(
    kind: LibraryCardKind.exercise,
    title: 'Cầu mông',
    duration: '15 rep',
    detail: 'Mông · lưng',
    icon: Icons.height_rounded,
    hasAi: true,
    exerciseName: 'glute_bridge',
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
  String? get thumbnailAsset => libraryExerciseThumbnailAssets[definitionName];

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
  'CARDIO',
  'YOGA',
];

const Map<String, String> libraryExerciseThumbnailAssets = {
  'squat': 'assets/habt/squat.png',
  'lunge': 'assets/habt/lunge.png',
  'glute_bridge': 'assets/habt/glute_bridge.png',
  'walking_lunge': 'assets/habt/walking_lunge.png',
  'cossack_squat': 'assets/habt/cossack_squat.png',
  'jump_squat': 'assets/habt/jump_squat.png',
  'bird_dog': 'assets/habt/bird_ dog.png',
  'dead_bug': 'assets/habt/dead_bug.png',
  'mcgill_curlup': 'assets/habt/mcgill_curlup.png',
  'plank': 'assets/habt/plank.png',
  'high_plank': 'assets/habt/high_plank.png',
  'bear_plank': 'assets/habt/bear_plank.png',
  'situp': 'assets/habt/sit_up.png',
  'leg_raises': 'assets/habt/leg_raises.png',
  'reverse_crunch': 'assets/habt/reverse_crunch.png',
  'vup': 'assets/habt/v_up.png',
  'russian_twist': 'assets/habt/Russian_twist.png',
  'side_plank_dip': 'assets/habt/side_plank.png',
  'plank_shoulder_tap': 'assets/habt/plank_shoulder _tap.png',
  'plank_up_down': 'assets/habt/plank_up_down.png',
  'standing_knee_to_elbow': 'assets/habt/standing_knee_to_elbow.png',
  'superman': 'assets/habt/superman.png',
  'push_up': 'assets/habt/push_up.png',
  'wall_pushup': 'assets/habt/wall_push_up.png',
  'tricep_dip': 'assets/habt/trace_dip.png',
  'jumping_jack': 'assets/habt/jumping_jack.png',
  'mountain_climber': 'assets/habt/mountain_climber.png',
  'step_back_burpee': 'assets/habt/step_back_burpee.png',
  'warrior_one': 'assets/habt/warrior_1.png',
  'cobra': 'assets/habt/cobra.png',
  'butterfly': 'assets/habt/butterfly_pose.png',
  'seated_forward_fold': 'assets/habt/seated_forward_fold.png',
  'sphinx': 'assets/habt/sphinx_pose.png',
  'bow_pose': 'assets/habt/bow_pose.png',
};

const List<AllExerciseRowMock> libraryMockAllExercises = [
  AllExerciseRowMock(
    idx: 1,
    name: 'Squat',
    cat: 'Chân · Mông · 15 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'squat',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 2,
    name: 'Chùng chân',
    cat: 'Đùi · Mông · 10 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'lunge',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 3,
    name: 'Cầu mông',
    cat: 'Mông · Lưng dưới · 15 rep',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'glute_bridge',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 4,
    name: 'Lunge bước đi',
    cat: 'Chân · Thăng bằng · 12 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'walking_lunge',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 5,
    name: 'Squat Cossack',
    cat: 'Chân · Hông · 8 rep',
    diff: 'TB–Khó',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'cossack_squat',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 6,
    name: 'Squat bật nhảy',
    cat: 'Chân · Sức bật · 10 rep',
    diff: 'TB–Khó',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'jump_squat',
    group: 'CHÂN · MÔNG',
  ),
  AllExerciseRowMock(
    idx: 7,
    name: 'Bird Dog',
    cat: 'Core · Lưng · 12 rep',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'bird_dog',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 8,
    name: 'Dead Bug',
    cat: 'Core ổn định · 12 rep',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'dead_bug',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 9,
    name: 'Gập bụng McGill',
    cat: 'Core McGill · 12 rep',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'mcgill_curlup',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 10,
    name: 'Plank thấp',
    cat: 'Core · Giữ 30 giây',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'plank',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 11,
    name: 'Plank cao',
    cat: 'Core · Vai · 30 giây',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'high_plank',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 12,
    name: 'Plank gấu',
    cat: 'Core · Vai · 30 giây',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'bear_plank',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 13,
    name: 'Gập bụng',
    cat: 'Core · 12 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'situp',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 14,
    name: 'Nâng chân',
    cat: 'Core dưới · 12 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'leg_raises',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 15,
    name: 'Gập bụng ngược',
    cat: 'Core dưới · 12 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'reverse_crunch',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 16,
    name: 'Gập bụng chữ V',
    cat: 'Core · 10 rep',
    diff: 'TB–Khó',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'vup',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 17,
    name: 'Xoay người kiểu Nga',
    cat: 'Core xoay · 16 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'russian_twist',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 18,
    name: 'Plank nghiêng hạ hông',
    cat: 'Core bên · 10 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'side_plank_dip',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 19,
    name: 'Plank chạm vai',
    cat: 'Core · Vai · 16 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'plank_shoulder_tap',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 20,
    name: 'Plank lên xuống',
    cat: 'Core · Tay sau · 10 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'plank_up_down',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 21,
    name: 'Đứng chạm gối khuỷu tay',
    cat: 'Core · Cardio nhẹ · 16 rep',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'standing_knee_to_elbow',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 22,
    name: 'Superman',
    cat: 'Lưng sau · 12 rep',
    diff: 'Dễ–TB',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'superman',
    group: 'CỐT LÕI',
  ),
  AllExerciseRowMock(
    idx: 23,
    name: 'Chống đẩy',
    cat: 'Ngực · Vai · 10 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.wallPushUp,
    definitionName: 'push_up',
    group: 'NGỰC · VAI',
  ),
  AllExerciseRowMock(
    idx: 24,
    name: 'Chống đẩy tường',
    cat: 'Ngực · Vai · 10 rep',
    diff: 'Dễ',
    ai: true,
    glyph: PoseGlyphType.wallPushUp,
    definitionName: 'wall_pushup',
    group: 'NGỰC · VAI',
  ),
  AllExerciseRowMock(
    idx: 25,
    name: 'Dip cơ tam đầu',
    cat: 'Tay sau · Ngực · 10 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'tricep_dip',
    group: 'NGỰC · VAI',
  ),
  AllExerciseRowMock(
    idx: 26,
    name: 'Nhảy dang tay chân',
    cat: 'Cardio · 30 rep',
    diff: 'Dễ',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'jumping_jack',
    group: 'CARDIO',
  ),
  AllExerciseRowMock(
    idx: 27,
    name: 'Leo núi',
    cat: 'Cardio · Core · 20 rep',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'mountain_climber',
    group: 'CARDIO',
  ),
  AllExerciseRowMock(
    idx: 28,
    name: 'Burpee bước lùi',
    cat: 'Cardio · Toàn thân · 8 rep',
    diff: 'TB–Khó',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'step_back_burpee',
    group: 'CARDIO',
  ),
  AllExerciseRowMock(
    idx: 29,
    name: 'Tư thế chiến binh I',
    cat: 'Yoga · Giữ 30 giây',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'warrior_one',
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 30,
    name: 'Tư thế rắn hổ mang',
    cat: 'Yoga · Giữ 20 giây',
    diff: 'Người mới',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'cobra',
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 31,
    name: 'Tư thế bướm',
    cat: 'Yoga · Mở hông · 30 giây',
    diff: 'Người mới',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'butterfly',
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 32,
    name: 'Gập người ngồi',
    cat: 'Yoga · Gân kheo · 30 giây',
    diff: 'Người mới',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'seated_forward_fold',
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 33,
    name: 'Tư thế nhân sư',
    cat: 'Yoga · Lưng nhẹ · 30 giây',
    diff: 'Người mới',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'sphinx',
    yoga: true,
    group: 'YOGA',
  ),
  AllExerciseRowMock(
    idx: 34,
    name: 'Tư thế cánh cung',
    cat: 'Yoga · Lưng sau · 20 giây',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'bow_pose',
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

LibraryCardData _albumCard(String id) {
  final album = vikaAlbumById(id);
  if (album == null) {
    throw StateError('Unknown Vika album id: $id');
  }
  return album.toCardData();
}

final List<LibrarySection> librarySections = [
  LibrarySectionFeaturedCarousel(
    slides: [
      LibraryFeaturedSlideData(
        eyebrow: 'BỘ TẬP · PHỤC HỒI',
        titleLine1: 'Lưng khỏe',
        titleLine2: 'mỗi ngày.',
        statChips: ['5 bài', '~8 phút', 'Có AI'],
        description: 'Cho lưng sau giờ ngồi lâu. Tập liền mạch theo thứ tự.',
        ctaLabel: 'Tập bộ này',
        watermarkNumeral: '01',
        ctaTarget: _albumCard('back'),
      ),
      LibraryFeaturedSlideData(
        eyebrow: 'ĐIỂM BẮT ĐẦU',
        titleLine1: 'Người mới',
        titleLine2: 'bắt đầu.',
        statChips: ['5 bài', '~6 phút', 'Có AI'],
        description:
            'Cơ bản, nhịp chậm. Ưu tiên form đúng trước khi tăng độ khó.',
        ctaLabel: 'Bắt đầu tập',
        watermarkNumeral: '02',
        ctaTarget: _albumCard('beginner'),
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
        ctaTarget: _albumCard('desk'),
      ),
    ],
    filterKinds: ['all'],
  ),
  const LibrarySectionTileGrid(
    eyebrow: 'DUYỆT NHANH',
    meta: '6 phân loại',
    intro: 'Chọn theo phần thân hoặc cảm giác. Tất cả đều là bài có thể mở.',
    tiles: [
      BrowseTileData(
        id: 'lower',
        label: 'Chân · Mông',
        eyebrow: 'PHẦN THÂN',
        icon: Icons.directions_walk_rounded,
        count: 6,
        breakdown: '6 BÀI · 1 BỘ',
      ),
      BrowseTileData(
        id: 'core',
        label: 'Cốt lõi',
        eyebrow: 'PHẦN THÂN',
        icon: Icons.horizontal_rule_rounded,
        count: 16,
        breakdown: '16 BÀI · 1 BỘ',
      ),
      BrowseTileData(
        id: 'back',
        label: 'Lưng & phục hồi',
        eyebrow: 'PHỤC HỒI',
        icon: Icons.healing_rounded,
        count: 7,
        breakdown: '7 BÀI · 1 BỘ',
      ),
      BrowseTileData(
        id: 'yoga',
        label: 'Yoga',
        eyebrow: 'THƯ GIÃN',
        icon: Icons.self_improvement_rounded,
        count: 6,
        breakdown: '6 BÀI · 2 BỘ',
      ),
      BrowseTileData(
        id: 'ai',
        label: 'Có camera AI',
        eyebrow: 'TƯ THẾ',
        icon: Icons.center_focus_strong_rounded,
        count: 34,
        breakdown: '34 BÀI · 10 BỘ',
      ),
      BrowseTileData(
        id: 'short',
        label: 'Nhanh ≤ vài phút',
        eyebrow: 'GIỜ LÀM',
        icon: Icons.access_time_rounded,
        count: 3,
        breakdown: '3 BỘ · NGẮN',
      ),
    ],
    filterKinds: ['all'],
  ),
  LibrarySectionAlbumRail(
    eyebrow: 'BỘ TẬP',
    meta: '${libraryAlbumCards.length} BỘ',
    intro:
        'Tuyển tập tập liền mạch. Chạm một lần, Vika chạy từng bài theo thứ tự.',
    cards: libraryAlbumCards,
    filterKinds: const ['album'],
  ),
  LibrarySectionStatBand(
    stats: [
      LibraryStat(value: '${libraryMockAllExercises.length}', label: 'Bài tập'),
      LibraryStat(
        value: '${libraryMockAllExercises.where((row) => row.ai).length}',
        label: 'Có AI',
      ),
      LibraryStat(value: '${libraryAlbumCards.length}', label: 'Bộ tập'),
    ],
    filterKinds: const ['all'],
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
  LibrarySectionCatalog(
    eyebrow: 'KHO BÀI TẬP',
    meta: '${libraryMockAllExercises.length} BÀI',
    rows: libraryMockAllExercises,
    // No filterKinds → always visible (the completionist tail).
  ),
];
