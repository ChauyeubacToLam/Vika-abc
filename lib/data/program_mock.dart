// Completion-anchored mock for the redesigned Plan screen.
//
// THE MODEL SHIFT: progression advances by COMPLETING sessions, never by
// calendar date. There are no dates, no weekday pins, no "this week = 7
// dates". A "block" is a progression unit (a.k.a. "Tuần N · <phase>"), and
// its sessions are an ordered sequence ("Buổi 1 / 2 / 3") done whenever the
// user shows up. Status is derived ONLY from completion:
//   done · current (the single next-up) · upcoming
//
// This mock MIRRORS the real recommendation-engine shape so wiring later is a
// single provider swap (see loadMockProgramPlan + its TODO(wiring) seam):
//
//   ProgramPlan      ⇄  Plan            (lib/services/recommendation/models/plan.dart)
//   ProgramBlock     ⇄  WeekPlan        (blockNumber⇄weekNumber, phaseNumber, phaseName, isDeload)
//   PlanSession      ⇄  SessionPlan     (index⇄sessionIndex)
//   SessionExercise  ⇄  SlotAssignment  (name⇄exerciseId lookup, volumeLabel⇄VolumePrescription)
//   ProgramRetest    ⇄  PlanRetest      (end-of-program retest)
//
// Fields the real model does NOT carry (status, formScore, difficulty,
// coachNote) are derived at wiring time from completion records + logged
// session results + the coaching copy layer. They are hardcoded here.

import 'package:flutter/foundation.dart';

/// The ONLY driver of block / session / retest state. No calendar input.
enum ProgramStatus { done, current, upcoming }

/// Overall difficulty the user logged after a completed session (and,
/// optionally, per exercise). Maps to the per-set difficulty system the
/// engine already records.
enum SessionDifficulty { light, moderate, hard }

typedef PlanLedgerSessionKey = (int weekNumber, int sessionIndex);

typedef PlanLedgerExerciseResult = ({
  int? formScore,
  String? difficulty,
});

typedef PlanLedgerSessionResult = ({
  int? sessionFormScore,
  Map<String, PlanLedgerExerciseResult> exercises,
});

typedef PlanLedgerSessionResults
    = Map<PlanLedgerSessionKey, PlanLedgerSessionResult>;

extension SessionDifficultyX on SessionDifficulty {
  /// Vietnamese glanceable label.
  String get label => switch (this) {
        SessionDifficulty.light => 'Nhẹ',
        SessionDifficulty.moderate => 'Vừa sức',
        SessionDifficulty.hard => 'Nặng',
      };
}

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════

@immutable
class SessionExercise {
  const SessionExercise({
    required this.name,
    required this.volumeLabel,
    this.exerciseId,
    this.hasAi = false,
    this.formScore,
    this.difficulty,
  });

  /// Display name, e.g. "Squat". Maps from SlotAssignment.exerciseId via the
  /// exercise catalog at wiring time.
  final String name;

  /// Short prescription label, e.g. "3 × 8 rep" or "3 × 30 giây". Maps from
  /// VolumePrescription (sets × reps|seconds).
  final String volumeLabel;

  /// Catalog id so a row tap can launch the right exercise screen later.
  final String? exerciseId;

  /// True when the camera-AI form coach is available for this slot (drives
  /// the gold AI dot, matching Home's convention).
  final bool hasAi;

  /// Logged form 0–100. Null until the exercise has been performed.
  final int? formScore;

  /// Logged difficulty. Null until performed.
  final SessionDifficulty? difficulty;
}

@immutable
class PlanSession {
  const PlanSession({
    required this.index,
    required this.label,
    required this.status,
    required this.coachNote,
    required this.exercises,
    this.title = '',
    this.durationLabel = '',
    this.formScore,
    this.difficulty,
  });

  /// 0-based position within the block. Mirrors SessionPlan.sessionIndex.
  final int index;

  /// Sequence label, e.g. "Buổi 02". Derived from [index] + 1.
  final String label;

  final ProgramStatus status;

  /// Warm Vietnamese coach voice line for this session.
  final String coachNote;

  final List<SessionExercise> exercises;

  /// Optional human title for the session focus, e.g. "Chân & Cốt lõi".
  final String title;

  /// Estimated duration label, e.g. "15 phút". Display-only.
  final String durationLabel;

  /// Overall logged form 0–105 for a DONE session. Null otherwise.
  final int? formScore;

  /// Overall logged difficulty for a DONE session. Null otherwise.
  final SessionDifficulty? difficulty;

  int get exerciseCount => exercises.length;
  bool get isNext => status == ProgramStatus.current;
}

@immutable
class ProgramBlock {
  const ProgramBlock({
    required this.blockNumber,
    required this.phaseNumber,
    required this.phaseName,
    required this.status,
    required this.coachNote,
    required this.sessions,
    this.isDeload = false,
    this.focusLabel = '',
  });

  /// 1-indexed. Mirrors WeekPlan.weekNumber. Surfaced to the user as
  /// "Tuần {blockNumber}".
  final int blockNumber;

  /// Which phase this block belongs to. Mirrors WeekPlan.phaseNumber.
  final int phaseNumber;

  /// Snapshotted phase name, e.g. "Nền tảng". Mirrors WeekPlan.phaseName.
  final String phaseName;

  final ProgramStatus status;

  /// Warm Vietnamese coach voice line for the block as a whole.
  final String coachNote;

  final List<PlanSession> sessions;

  /// True for the deload block (different copy: "nhẹ hơn có chủ đích").
  final bool isDeload;

  /// Short body-focus label for this block, e.g. "Chân & Core".
  final String focusLabel;

  int get sessionsTotal => sessions.length;

  int get sessionsDone =>
      sessions.where((s) => s.status == ProgramStatus.done).length;

  /// The single next-up session inside this block, if any.
  PlanSession? get nextSession {
    for (final s in sessions) {
      if (s.status == ProgramStatus.current) return s;
    }
    return null;
  }

  /// Average logged form across this block's done sessions. Null if none done.
  int? get averageForm {
    final scored = sessions
        .where((s) => s.status == ProgramStatus.done && s.formScore != null)
        .map((s) => s.formScore!)
        .toList(growable: false);
    if (scored.isEmpty) return null;
    final sum = scored.fold(0, (a, b) => a + b);
    return (sum / scored.length).round();
  }
}

@immutable
class ProgramRetest {
  const ProgramRetest({
    required this.title,
    required this.description,
    required this.coachNote,
    required this.status,
    required this.exercises,
  });

  /// e.g. "Kiểm tra lại thể lực". Mirrors PlanRetest.vietnameseTitle.
  final String title;

  /// Mirrors PlanRetest.vietnameseDescription.
  final String description;

  /// Warm Vietnamese coach voice line for the retest.
  final String coachNote;

  final ProgramStatus status;

  /// Assessment exercises. Mirrors PlanRetest.exercises (RetestExercise).
  final List<SessionExercise> exercises;
}

@immutable
class ProgramPlan {
  const ProgramPlan({
    required this.blocks,
    required this.retest,
    this.programTitle = '',
  });

  final List<ProgramBlock> blocks;

  /// End-of-program retest beat. Mirrors Plan.endOfPlanRetest. Null if none.
  final ProgramRetest? retest;

  /// Short program label for editorial copy, e.g. "Khoẻ hơn rõ rệt".
  final String programTitle;

  int get blocksTotal => blocks.length;

  int get blocksDone =>
      blocks.where((b) => b.status == ProgramStatus.done).length;

  /// Index of the current block (the single in-progress block). Falls back to
  /// 0 if none is current — used as the screen's default selection.
  int get currentBlockIndex {
    final i = blocks.indexWhere((b) => b.status == ProgramStatus.current);
    return i == -1 ? 0 : i;
  }

  /// The current block (the single in-progress block). Falls back to the
  /// first block if, somehow, none is current.
  ProgramBlock get currentBlock {
    for (final b in blocks) {
      if (b.status == ProgramStatus.current) return b;
    }
    return blocks.first;
  }

  /// True when every block is done — gates the end-of-program retest unlock.
  /// Completion-only: never time- or date-gated.
  bool get allBlocksDone => blocks.every((b) => b.status == ProgramStatus.done);

  /// The single next-up session across the whole program — the one thing the
  /// user should tap. Null only if the program is fully complete.
  PlanSession? get nextSession => currentBlock.nextSession;
}

// ═══════════════════════════════════════════════════════════════
// PROVIDER SEAM
// ═══════════════════════════════════════════════════════════════

/// The redesigned PlanScreen consumes a [ProgramPlan] and nothing else.
///
/// TODO(wiring): replace the body with a real mapper, e.g.
/// ```dart
/// final snapshot = await RecommendationService().ensurePlanForCurrentUser(...);
/// final completion = await SessionPersistence().fetchCompletion(...);
/// final pendingRetest = await FitnessRetestService().fetchPendingRetest...();
/// return ProgramPlanMapper.fromSnapshot(snapshot, completion, pendingRetest);
/// ```
/// Mapping is mechanical because this model mirrors the engine shape:
///   WeekPlan → ProgramBlock, SessionPlan → PlanSession,
///   SlotAssignment+VolumePrescription → SessionExercise.
/// `status` comes from the completion record; `formScore`/`difficulty` from
/// logged session results; `coachNote` from the coaching copy layer.
/// Swapping this single function for the real mapper is the entire wiring task.
/// The legacy real-data loading + workout-launch code lives in
/// plan_screen_legacy.dart for reference.
ProgramPlan loadMockProgramPlan() => kMockProgramPlan;

// ═══════════════════════════════════════════════════════════════
// MOCK DATA — a mid-program user.
//
// Blocks 1–2 done · Block 3 current (1 of 3 sessions done, so "Buổi 02" is
// the single NEXT session) · Blocks 4–6 upcoming (Phát triển) · Block 7
// upcoming deload (Phục hồi) · then the end-of-program retest.
//
// Phase map mirrors the engine: Phase 1 "Nền tảng" = blocks 1–3,
// Phase 2 "Phát triển" = blocks 4–6, Phase 3 "Phục hồi" = block 7 (deload).
// ═══════════════════════════════════════════════════════════════

const ProgramPlan kMockProgramPlan = ProgramPlan(
  programTitle: 'Khoẻ hơn rõ rệt',
  blocks: [
    // ─── Block 1 · Nền tảng · DONE ───────────────────────────────────────
    ProgramBlock(
      blockNumber: 1,
      phaseNumber: 1,
      phaseName: 'Nền tảng',
      status: ProgramStatus.done,
      focusLabel: 'Làm quen',
      coachNote: 'Tuần nền tảng. Mình xây thói quen trước, sức mạnh theo sau.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Toàn thân nhẹ',
          status: ProgramStatus.done,
          durationLabel: '12 phút',
          formScore: 64,
          difficulty: SessionDifficulty.moderate,
          coachNote: 'Buổi đầu tiên. Làm quen với nhịp thở và form chuẩn đã.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 8 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 72,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '3 × 8 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
              formScore: 68,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 20 giây',
              hasAi: false,
              formScore: 52,
              difficulty: SessionDifficulty.hard,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '3 × 10 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
              formScore: 66,
              difficulty: SessionDifficulty.light,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Chân & Cốt lõi',
          status: ProgramStatus.done,
          durationLabel: '14 phút',
          formScore: 70,
          difficulty: SessionDifficulty.moderate,
          coachNote: 'Squat sâu hơn buổi trước. Glute bridge giữ ổn định.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 10 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 76,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
              formScore: 78,
              difficulty: SessionDifficulty.light,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '3 × 10 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
              formScore: 58,
              difficulty: SessionDifficulty.hard,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '2 × 8 rep',
              hasAi: false,
              formScore: 64,
              difficulty: SessionDifficulty.moderate,
            ),
          ],
        ),
        PlanSession(
          index: 2,
          label: 'Buổi 03',
          title: 'Toàn thân',
          status: ProgramStatus.done,
          durationLabel: '15 phút',
          formScore: 73,
          difficulty: SessionDifficulty.moderate,
          coachNote: 'Đỉnh tuần. Squat đạt 80% — cốt lõi đang lên đều.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 10 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 80,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '3 × 10 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
              formScore: 72,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 25 giây',
              hasAi: false,
              formScore: 62,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
              formScore: 66,
              difficulty: SessionDifficulty.moderate,
            ),
          ],
        ),
      ],
    ),

    // ─── Block 2 · Nền tảng · DONE ───────────────────────────────────────
    ProgramBlock(
      blockNumber: 2,
      phaseNumber: 1,
      phaseName: 'Nền tảng',
      status: ProgramStatus.done,
      focusLabel: 'Củng cố',
      coachNote: 'Giữ nhịp đều — cốt lõi đang theo kịp rồi.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Cốt lõi sâu',
          status: ProgramStatus.done,
          durationLabel: '15 phút',
          formScore: 72,
          difficulty: SessionDifficulty.moderate,
          coachNote: 'Plank lên rõ — tiến bộ lớn nhất so với tuần đầu.',
          exercises: [
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 30 giây',
              hasAi: false,
              formScore: 78,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
              formScore: 70,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
              formScore: 74,
              difficulty: SessionDifficulty.light,
            ),
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 10 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 79,
              difficulty: SessionDifficulty.moderate,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Chân & Mông',
          status: ProgramStatus.done,
          durationLabel: '16 phút',
          formScore: 78,
          difficulty: SessionDifficulty.hard,
          coachNote: 'Glute bridge mạnh nhất tuần. Squat depth đã chuẩn.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 82,
              difficulty: SessionDifficulty.hard,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '3 × 10 rep',
              hasAi: false,
              formScore: 76,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '3 × 14 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
              formScore: 84,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Wall Sit',
              volumeLabel: '3 × 30 giây',
              hasAi: false,
              formScore: 72,
              difficulty: SessionDifficulty.hard,
            ),
          ],
        ),
        PlanSession(
          index: 2,
          label: 'Buổi 03',
          title: 'Toàn thân',
          status: ProgramStatus.done,
          durationLabel: '15 phút',
          formScore: 75,
          difficulty: SessionDifficulty.moderate,
          coachNote:
              'Đều và ổn. Nền tảng đã đủ chắc để bước sang giai đoạn mạnh hơn.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 80,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
              formScore: 74,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 30 giây',
              hasAi: false,
              formScore: 72,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '3 × 10 rep',
              hasAi: false,
              formScore: 73,
              difficulty: SessionDifficulty.moderate,
            ),
          ],
        ),
      ],
    ),

    // ─── Block 3 · Nền tảng · CURRENT (1/3 done → Buổi 02 is NEXT) ────────
    ProgramBlock(
      blockNumber: 3,
      phaseNumber: 1,
      phaseName: 'Nền tảng',
      status: ProgramStatus.current,
      focusLabel: 'Chân & Core',
      coachNote:
          'Khép lại nền tảng. Chậm mà chắc, để bước sang giai đoạn mạnh hơn.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Toàn thân nhẹ',
          status: ProgramStatus.done,
          durationLabel: '15 phút',
          formScore: 81,
          difficulty: SessionDifficulty.moderate,
          coachNote: 'Mở tuần nhẹ nhàng. Form giữ rất tốt — 81 điểm.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
              formScore: 84,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
              formScore: 78,
              difficulty: SessionDifficulty.moderate,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '3 × 14 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
              formScore: 83,
              difficulty: SessionDifficulty.light,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
              formScore: 76,
              difficulty: SessionDifficulty.moderate,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Chân & Cốt lõi',
          status: ProgramStatus.current,
          durationLabel: '15 phút',
          coachNote: 'Hôm nay tập trung vào chân và core. '
              'Giữ form chậm và chắc nhé.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '3 × 14 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '3 × 14 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '3 × 10 rep',
              hasAi: false,
            ),
          ],
        ),
        PlanSession(
          index: 2,
          label: 'Buổi 03',
          title: 'Toàn thân',
          status: ProgramStatus.upcoming,
          durationLabel: '16 phút',
          coachNote: 'Buổi khép tuần. Tổng hợp lại tất cả những gì đã xây.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '3 × 12 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 35 giây',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Warrior I',
              volumeLabel: '2 × 30 giây',
              exerciseId: 'warrior_i',
              hasAi: true,
            ),
          ],
        ),
      ],
    ),

    // ─── Block 4 · Phát triển · UPCOMING ─────────────────────────────────
    ProgramBlock(
      blockNumber: 4,
      phaseNumber: 2,
      phaseName: 'Phát triển',
      status: ProgramStatus.upcoming,
      focusLabel: 'Tăng lực',
      coachNote: 'Bước sang giai đoạn phát triển. Khối lượng tăng dần — '
          'cơ thể bạn đã sẵn sàng cho việc này.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Chân khoẻ',
          status: ProgramStatus.upcoming,
          durationLabel: '17 phút',
          coachNote: 'Mở giai đoạn mới. Tập trung vào sức mạnh thân dưới.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '4 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '3 × 12 rep',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Sit',
              volumeLabel: '3 × 40 giây',
              hasAi: false,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Thân trên',
          status: ProgramStatus.upcoming,
          durationLabel: '16 phút',
          coachNote: 'Đẩy mạnh thân trên. Giữ vai ổn định trong từng rep.',
          exercises: [
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '4 × 12 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 40 giây',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Cobra',
              volumeLabel: '2 × 30 giây',
              exerciseId: 'cobra',
              hasAi: true,
            ),
          ],
        ),
        PlanSession(
          index: 2,
          label: 'Buổi 03',
          title: 'Toàn thân mạnh',
          status: ProgramStatus.upcoming,
          durationLabel: '18 phút',
          coachNote: 'Tổng hợp toàn thân với khối lượng cao hơn.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '4 × 12 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '4 × 12 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 40 giây',
              hasAi: false,
            ),
          ],
        ),
      ],
    ),

    // ─── Block 5 · Phát triển · UPCOMING ─────────────────────────────────
    ProgramBlock(
      blockNumber: 5,
      phaseNumber: 2,
      phaseName: 'Phát triển',
      status: ProgramStatus.upcoming,
      focusLabel: 'Bền sức',
      coachNote: 'Giữ vững khối lượng, thêm chút sức bền.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Chân & Mông',
          status: ProgramStatus.upcoming,
          durationLabel: '18 phút',
          coachNote: 'Thân dưới tiếp tục mạnh lên. Kiên nhẫn với từng rep.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '4 × 12 rep',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '4 × 16 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Sit',
              volumeLabel: '3 × 45 giây',
              hasAi: false,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Cốt lõi & dẻo dai',
          status: ProgramStatus.upcoming,
          durationLabel: '16 phút',
          coachNote: 'Kết hợp cốt lõi và độ dẻo. Thở sâu, giữ tư thế.',
          exercises: [
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 45 giây',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Warrior I',
              volumeLabel: '3 × 30 giây',
              exerciseId: 'warrior_i',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Standing Forward Fold',
              volumeLabel: '2 × 30 giây',
              exerciseId: 'standing_forward_fold',
              hasAi: true,
            ),
          ],
        ),
        PlanSession(
          index: 2,
          label: 'Buổi 03',
          title: 'Toàn thân',
          status: ProgramStatus.upcoming,
          durationLabel: '18 phút',
          coachNote: 'Buổi tổng hợp. Cảm nhận sự khác biệt so với tuần đầu.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '4 × 14 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '4 × 16 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 45 giây',
              hasAi: false,
            ),
          ],
        ),
      ],
    ),

    // ─── Block 6 · Phát triển · UPCOMING ─────────────────────────────────
    ProgramBlock(
      blockNumber: 6,
      phaseNumber: 2,
      phaseName: 'Phát triển',
      status: ProgramStatus.upcoming,
      focusLabel: 'Đỉnh khối',
      coachNote:
          'Tuần cao điểm. Sau đó là lúc cho cơ thể hồi lại — bạn sắp về đích.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Chân tối đa',
          status: ProgramStatus.upcoming,
          durationLabel: '19 phút',
          coachNote:
              'Đẩy thân dưới đến giới hạn an toàn. Form là ưu tiên số một.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '4 × 15 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Lunge',
              volumeLabel: '4 × 12 rep',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '4 × 18 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Sit',
              volumeLabel: '3 × 50 giây',
              hasAi: false,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Thân trên tối đa',
          status: ProgramStatus.upcoming,
          durationLabel: '17 phút',
          coachNote: 'Thân trên ở mức cao nhất. Nghỉ đủ giữa các hiệp.',
          exercises: [
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '4 × 15 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 50 giây',
              hasAi: false,
            ),
            SessionExercise(
              name: 'Curl-Up',
              volumeLabel: '4 × 16 rep',
              exerciseId: 'mcgill_curl_up',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Cobra',
              volumeLabel: '3 × 30 giây',
              exerciseId: 'cobra',
              hasAi: true,
            ),
          ],
        ),
        PlanSession(
          index: 2,
          label: 'Buổi 03',
          title: 'Toàn thân đỉnh',
          status: ProgramStatus.upcoming,
          durationLabel: '20 phút',
          coachNote: 'Buổi mạnh nhất chương trình. Bạn đã đi một chặng dài.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '4 × 15 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Wall Push-Up',
              volumeLabel: '4 × 15 rep',
              exerciseId: 'wall_pushup',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '4 × 18 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Plank',
              volumeLabel: '3 × 50 giây',
              hasAi: false,
            ),
          ],
        ),
      ],
    ),

    // ─── Block 7 · Phục hồi · UPCOMING (deload) ──────────────────────────
    ProgramBlock(
      blockNumber: 7,
      phaseNumber: 3,
      phaseName: 'Phục hồi',
      status: ProgramStatus.upcoming,
      isDeload: true,
      focusLabel: 'Giảm tải',
      coachNote: 'Tuần này nhẹ hơn có chủ đích. Cho cơ thể hồi lại — '
          'đây là lúc tiến bộ được hấp thụ.',
      sessions: [
        PlanSession(
          index: 0,
          label: 'Buổi 01',
          title: 'Phục hồi nhẹ',
          status: ProgramStatus.upcoming,
          durationLabel: '12 phút',
          coachNote: 'Giữ nhẹ, chậm và chắc. Không cần cố sức tuần này.',
          exercises: [
            SessionExercise(
              name: 'Squat',
              volumeLabel: '2 × 10 rep',
              exerciseId: 'squat_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Glute Bridge',
              volumeLabel: '2 × 12 rep',
              exerciseId: 'glute_bridge_bw',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Standing Forward Fold',
              volumeLabel: '2 × 30 giây',
              exerciseId: 'standing_forward_fold',
              hasAi: true,
            ),
          ],
        ),
        PlanSession(
          index: 1,
          label: 'Buổi 02',
          title: 'Giãn & thở',
          status: ProgramStatus.upcoming,
          durationLabel: '12 phút',
          coachNote: 'Dành cho hơi thở và độ dẻo. Thả lỏng toàn thân.',
          exercises: [
            SessionExercise(
              name: 'Warrior I',
              volumeLabel: '2 × 30 giây',
              exerciseId: 'warrior_i',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Cobra',
              volumeLabel: '2 × 25 giây',
              exerciseId: 'cobra',
              hasAi: true,
            ),
            SessionExercise(
              name: 'Standing Forward Fold',
              volumeLabel: '2 × 30 giây',
              exerciseId: 'standing_forward_fold',
              hasAi: true,
            ),
          ],
        ),
      ],
    ),
  ],

  // ─── End-of-program retest — the final beat ────────────────────────────
  retest: ProgramRetest(
    title: 'Kiểm tra lại thể lực',
    description: 'Làm lại bài kiểm tra ngắn để Vika đo tiến bộ và '
        'định hình lộ trình tiếp theo từ kết quả mới.',
    coachNote: 'Về đích rồi. Đo lại một lần để thấy mình đã đi xa thế nào.',
    status: ProgramStatus.upcoming,
    exercises: [
      SessionExercise(
        name: 'Squat assessment',
        volumeLabel: 'Đo lực chân',
        exerciseId: 'squat_bw',
        hasAi: true,
      ),
      SessionExercise(
        name: 'Wall Push-Up assessment',
        volumeLabel: 'Đo lực thân trên',
        exerciseId: 'wall_pushup',
        hasAi: true,
      ),
    ],
  ),
);
