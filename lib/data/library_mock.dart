// Mock data for the Library / Browser sheet. Mirrors values inline in
// `BrowserSheet`, `ProgramsRail`, `IntentCollection`, and
// `AllExercisesGrid` of vika-main-app-ivory-v1.jsx.

import 'package:flutter/foundation.dart';

import '../widgets/ivory/atoms.dart';

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
  final String idx; // '01'
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

const List<ProgramMock> libraryMockPrograms = [
  ProgramMock(
    idx: '01',
    name: 'Khởi đầu',
    dur: '4 tuần',
    sessions: '12 buổi',
    diff: 'Người mới',
    tag: 'Đang chạy',
    tone: ProgramTone.current,
    tagline: 'Lộ trình bốn tuần đưa bạn từ ghế ra sàn.',
  ),
  ProgramMock(
    idx: '02',
    name: 'Khoẻ lưng',
    dur: '21 ngày',
    sessions: '14 buổi',
    diff: 'Cơ bản',
    tone: ProgramTone.dark,
    tagline: 'Cốt lõi và hông. Cho lưng dưới hết đau.',
  ),
  ProgramMock(
    idx: '03',
    name: 'Yoga sáng',
    dur: '14 ngày',
    sessions: '14 buổi',
    diff: 'Người mới',
    tone: ProgramTone.cream,
    tagline: 'Mười phút mỗi sáng. Trước khi mở email.',
  ),
  ProgramMock(
    idx: '04',
    name: 'Reset cuối ngày',
    dur: '14 ngày',
    sessions: '7 buổi',
    diff: 'Người mới',
    tag: 'Sắp ra mắt',
    tone: ProgramTone.cream,
    tagline: 'Mười lăm phút sau giờ làm. Dễ ngủ hơn.',
  ),
];

const List<IntentCollectionMock> libraryMockCollections = [
  IntentCollectionMock(
    idx: '01',
    eyebrow: 'SÁNG · 8 PHÚT',
    title: 'Khởi động sáng',
    subtitle: 'Năm bài để cơ thể tỉnh dậy trước khi ngồi làm.',
    hero: CollectionExerciseMock(
      name: 'Squat nhẹ',
      glyph: PoseGlyphType.squat,
      meta: '3 hiệp · 8 lần',
      ai: true,
    ),
    small: [
      CollectionExerciseMock(
        name: 'Gập trước đứng',
        glyph: PoseGlyphType.plank,
        meta: '30 giây',
        ai: true,
      ),
      CollectionExerciseMock(
        name: 'Chiến binh I',
        glyph: PoseGlyphType.lunge,
        meta: '30 giây/bên',
        ai: true,
      ),
    ],
  ),
  IntentCollectionMock(
    idx: '02',
    eyebrow: 'TỐI · 12 PHÚT',
    title: 'Tối yên',
    subtitle: 'Sáu tư thế yoga để hạ nhịp tim, dễ ngủ.',
    hero: CollectionExerciseMock(
      name: 'Tư thế em bé',
      glyph: PoseGlyphType.plank,
      meta: '3 phút',
      yoga: true,
    ),
    small: [
      CollectionExerciseMock(
        name: 'Cây cầu',
        glyph: PoseGlyphType.plank,
        meta: '4 phút',
        yoga: true,
      ),
      CollectionExerciseMock(
        name: 'Rắn hổ mang',
        glyph: PoseGlyphType.plank,
        meta: '20s',
        ai: true,
        yoga: true,
      ),
    ],
  ),
  IntentCollectionMock(
    idx: '03',
    eyebrow: 'GIỮA NGÀY · 5 PHÚT',
    title: 'Reset bàn làm việc',
    subtitle: 'Bốn động tác, không cần thay đồ. Đứng dậy, làm liền.',
    hero: CollectionExerciseMock(
      name: 'Wall Push-up',
      glyph: PoseGlyphType.wallPushUp,
      meta: '3 hiệp · 6 lần',
      ai: true,
    ),
    small: [
      CollectionExerciseMock(
        name: 'Plank',
        glyph: PoseGlyphType.plank,
        meta: '20 giây',
        ai: true,
      ),
      CollectionExerciseMock(
        name: 'Chiến binh I',
        glyph: PoseGlyphType.lunge,
        meta: '30s/bên',
        ai: true,
      ),
    ],
  ),
];

@immutable
class AllExerciseRowMock {
  const AllExerciseRowMock({
    required this.idx,
    required this.name,
    required this.cat,
    required this.diff,
    required this.glyph,
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

  /// Maps to a real `ExerciseDefinition.name`. When set, tapping the
  /// row pushes `/exercise` with the matching definition. When null
  /// (yoga / not-yet-implemented), the row is tappable but the action
  /// is stubbed.
  final String? definitionName;
}

// Mocked from real `exerciseDefinitions` in
// lib/models/exercise_definition.dart. Each entry's `definitionName`
// matches the canonical `ExerciseDefinition.name` so a tap can resolve
// via `lookupExerciseDefinition()` and push /exercise.
const List<AllExerciseRowMock> libraryMockAllExercises = [
  AllExerciseRowMock(
    idx: 1,
    name: 'Squat',
    cat: 'Phân tích tư thế · 3×10',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'Squat',
  ),
  AllExerciseRowMock(
    idx: 2,
    name: 'Push Up',
    cat: 'Ngực · Vai · Core · 15 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.wallPushUp,
    definitionName: 'Push Up',
  ),
  AllExerciseRowMock(
    idx: 3,
    name: 'Plank',
    cat: 'McGill Short-Hold · 3×10s',
    diff: 'Dễ – Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Plank',
  ),
  AllExerciseRowMock(
    idx: 4,
    name: 'Lunge',
    cat: 'Đùi · Mông · Hamstring · 10 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Lunge',
  ),
  AllExerciseRowMock(
    idx: 5,
    name: 'Glute Bridge',
    cat: 'Mông · Lưng dưới · 15 reps',
    diff: 'Dễ – Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Glute Bridge',
  ),
  AllExerciseRowMock(
    idx: 6,
    name: 'McGill Curl-up',
    cat: 'Core ổn định · 12 reps',
    diff: 'Dễ – Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'McGill Curl-up',
  ),
  AllExerciseRowMock(
    idx: 7,
    name: 'Jumping Jack',
    cat: 'Cardio nhẹ · 30 reps',
    diff: 'Dễ',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Jumping Jack',
  ),
  // Yoga / non-AI follow-on entries — no `definitionName` (no real
  // ExerciseDefinition exists yet). Tapping them stubs out for now.
  AllExerciseRowMock(
    idx: 8,
    name: 'Gập trước đứng',
    cat: 'Yoga · 30s',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
  ),
  AllExerciseRowMock(
    idx: 9,
    name: 'Rắn hổ mang',
    cat: 'Yoga · 20s',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
  ),
  AllExerciseRowMock(
    idx: 10,
    name: 'Chó cúi mặt',
    cat: 'Yoga · 5 phút',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
  ),
  AllExerciseRowMock(
    idx: 11,
    name: 'Tư thế em bé',
    cat: 'Yoga · 3 phút',
    diff: 'Người mới',
    glyph: PoseGlyphType.plank,
    yoga: true,
  ),
  AllExerciseRowMock(
    idx: 12,
    name: 'Bird Dog',
    cat: 'Core · Lưng dưới · 10 reps',
    diff: 'Cơ bản',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Bird Dog',
  ),
  AllExerciseRowMock(
    idx: 13,
    name: 'Sit-Up',
    cat: 'Cơ bụng · 15 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Sit-Up',
  ),
  AllExerciseRowMock(
    idx: 14,
    name: 'High Plank',
    cat: 'Core · Ngực · 60s',
    diff: 'Cơ bản',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'High Plank',
  ),
  AllExerciseRowMock(
    idx: 15,
    name: 'Mountain Climber',
    cat: 'Cardio · Core · 20 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Mountain Climber',
  ),
  AllExerciseRowMock(
    idx: 16,
    name: 'Superman',
    cat: 'Lưng dưới · Mông · 10 reps',
    diff: 'Cơ bản',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Superman',
  ),
  AllExerciseRowMock(
    idx: 17,
    name: 'Plank Shoulder Tap',
    cat: 'Core · Vai · 20 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Plank Shoulder Tap',
  ),
  AllExerciseRowMock(
    idx: 18,
    name: 'Sphinx Pose',
    cat: 'Lưng dưới · Cột sống · 30s',
    diff: 'Cơ bản',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Sphinx Pose',
  ),
  AllExerciseRowMock(idx: 19, name: 'Chào mặt trời', cat: 'Yoga · Toàn thân · 5 vòng', diff: 'Trung bình', ai: true, yoga: true, glyph: PoseGlyphType.lunge, definitionName: 'Chào mặt trời'),
  AllExerciseRowMock(
    idx: 20,
    name: 'Leg Raises (Supine)',
    cat: 'Bụng dưới · Hông · 15 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Leg Raises (Supine)',
  ),
  AllExerciseRowMock(
    idx: 21,
    name: 'Reverse Crunch',
    cat: 'Bụng dưới · Core · 15 reps',
    diff: 'Khó',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Reverse Crunch',
  ),
  AllExerciseRowMock(
    idx: 22,
    name: 'V-Up',
    cat: 'Toàn bộ bụng · 12 reps',
    diff: 'Khó',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'V-Up',
  ),
  AllExerciseRowMock(
    idx: 23,
    name: 'Lying Leg Raise',
    cat: 'Bụng dưới · 15 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Lying Leg Raise',
  ),
  AllExerciseRowMock(
    idx: 24,
    name: 'Dead Bug',
    cat: 'Core · Khung chậu · 20 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Dead Bug',
  ),
  AllExerciseRowMock(
    idx: 25,
    name: 'Plank Up-Down',
    cat: 'Core · Vai · Ngực · 10 reps',
    diff: 'Khó',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Plank Up-Down',
  ),
  AllExerciseRowMock(
    idx: 26,
    name: 'Bear Plank',
    cat: 'Core · Đùi trước · 45s',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Bear Plank',
  ),
  AllExerciseRowMock(
    idx: 27,
    name: 'Cossack Squat',
    cat: 'Đùi · Mông · Hông · 16 reps',
    diff: 'Khó',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'Cossack Squat',
  ),
  AllExerciseRowMock(
    idx: 28,
    name: 'Walking Lunge',
    cat: 'Đùi trước · Đùi sau · 20 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Walking Lunge',
  ),
  AllExerciseRowMock(
    idx: 29,
    name: 'Tricep Dip (Floor)',
    cat: 'Bắp tay sau · Vai · 15 reps',
    diff: 'Cơ bản',
    ai: true,
    glyph: PoseGlyphType.wallPushUp,
    definitionName: 'Tricep Dip (Floor)',
  ),
  AllExerciseRowMock(
    idx: 30,
    name: 'Russian Twist',
    cat: 'Cơ liên sườn · Core · 20 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Russian Twist',
  ),
  AllExerciseRowMock(
    idx: 31,
    name: 'Standing Knee-to-Elbow',
    cat: 'Core · Cardio · 30 reps',
    diff: 'Cơ bản',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Standing Knee-to-Elbow',
  ),
  AllExerciseRowMock(
    idx: 32,
    name: 'Butterfly Stretch',
    cat: 'Yoga · Hông · 30s',
    diff: 'Cơ bản',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Butterfly Stretch',
  ),
  AllExerciseRowMock(
    idx: 33,
    name: 'Seated Forward Fold',
    cat: 'Yoga · Gân kheo · 2 phút',
    diff: 'Cơ bản',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Seated Forward Fold',
  ),
  AllExerciseRowMock(
    idx: 34,
    name: 'Jump Squat',
    cat: 'Plyometric · Đùi · 12 reps',
    diff: 'Khó',
    ai: true,
    glyph: PoseGlyphType.squat,
    definitionName: 'Jump Squat',
  ),
  AllExerciseRowMock(
    idx: 35,
    name: 'Bow Pose',
    cat: 'Yoga · Lưng · 3 reps',
    diff: 'Trung bình',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Bow Pose',
  ),
  AllExerciseRowMock(
    idx: 36,
    name: 'Side Plank Dip',
    cat: 'Cơ liên sườn · Core · 12 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Side Plank Dip',
  ),
  AllExerciseRowMock(
    idx: 37,
    name: 'Step-Back Burpee',
    cat: 'Cardio · Toàn thân · 15 reps',
    diff: 'Trung bình',
    ai: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Step-Back Burpee',
  ),
  AllExerciseRowMock(
    idx: 38,
    name: 'Pranamasana',
    cat: 'Yoga · Toàn thân · 5s',
    diff: 'Cơ bản',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Pranamasana',
  ),
  AllExerciseRowMock(
    idx: 39,
    name: 'Hasta Uttanasana',
    cat: 'Yoga · Toàn thân · 3s',
    diff: 'Cơ bản',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Hasta Uttanasana',
  ),
  AllExerciseRowMock(
    idx: 40,
    name: 'Hastapaadasana',
    cat: 'Yoga · Toàn thân · 1.5s',
    diff: 'Trung bình',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Hastapaadasana',
  ),
  AllExerciseRowMock(
    idx: 41,
    name: 'Ashwa Sanchalanasana',
    cat: 'Yoga · Toàn thân · 1.5s',
    diff: 'Trung bình',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.lunge,
    definitionName: 'Ashwa Sanchalanasana',
  ),
  AllExerciseRowMock(
    idx: 42,
    name: 'Parvatasana',
    cat: 'Yoga · Toàn thân · 1.5s',
    diff: 'Trung bình',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Parvatasana',
  ),
  AllExerciseRowMock(
    idx: 43,
    name: 'Ashtanga Namaskara',
    cat: 'Yoga · Toàn thân · 1.5s',
    diff: 'Trung bình',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Ashtanga Namaskara',
  ),
  AllExerciseRowMock(
    idx: 44,
    name: 'Cobra Pose',
    cat: 'Yoga · Lưng dưới · 3 reps',
    diff: 'Cơ bản',
    ai: true,
    yoga: true,
    glyph: PoseGlyphType.plank,
    definitionName: 'Cobra',
  ),
];

const List<({String id, String label, int count})> libraryMockFilters = [
  (id: 'all', label: 'Tất cả', count: 100),
  (id: 'ai', label: 'Có camera', count: 20),
  (id: 'yoga', label: 'Yoga', count: 50),
  (id: 'home', label: 'Tại nhà', count: 50),
  (id: 'back', label: 'Lưng', count: 18),
  (id: 'core', label: 'Cốt lõi', count: 22),
];
