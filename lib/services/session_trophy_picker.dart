import 'dart:math' as math;

import '../models/workout_session_report.dart';

enum TrophyTier {
  allTimePb,
  streakMilestone,
  recentPb,
  cleanSession,
  volume,
  showedUp,
}

class Trophy {
  final TrophyTier tier;
  final String value;
  final String label;
  final String tag;
  final String? exerciseName;

  const Trophy({
    required this.tier,
    required this.value,
    required this.label,
    required this.tag,
    this.exerciseName,
  });
  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'value': value,
        'label': label,
        'tag': tag,
        if (exerciseName != null) 'exercise_name': exerciseName,
      };
}

class SessionTrophyPicker {
  const SessionTrophyPicker._();

  static const int _pbMargin = 3;
  static const int _pbFloor = 60;
  static const Set<int> _streakMilestones = {3, 7, 14, 30};

  /// Canonical streak milestones, exposed so other surfaces (e.g. the Progress
  /// streak card's "next milestone" hint) stay in lockstep with the trophy.
  static Set<int> get streakMilestones => _streakMilestones;
  static const int _rollingWindow = 5;
  static const int _cleanCut = 85;
  static const int _volumeFloor = 30;
  static const int _solidFloor = 50;

  static int get solidFloor => _solidFloor;

  static Trophy pick({
    required List<ExerciseSessionReport> reports,
    required int sessionRawFormScore,
    required int streakDays,
    required List<int> priorSessionForms,
    required Map<String, List<int>> priorExerciseForms,
  }) {
    final allTimePb = _bestAllTimePb(
      reports: reports,
      sessionRawFormScore: sessionRawFormScore,
      priorSessionForms: priorSessionForms,
      priorExerciseForms: priorExerciseForms,
    );
    if (allTimePb != null) return allTimePb;

    if (_streakMilestones.contains(streakDays)) {
      return Trophy(
        tier: TrophyTier.streakMilestone,
        value: '$streakDays',
        label: '$streakDays ngày liên tiếp',
        tag: 'CHUỖI',
      );
    }

    // Future gap: first-time milestone tiers can slot in here.

    final recentPb = _bestRecentPb(
      reports: reports,
      sessionRawFormScore: sessionRawFormScore,
      priorSessionForms: priorSessionForms,
      priorExerciseForms: priorExerciseForms,
    );
    if (recentPb != null) return recentPb;

    // Future gap: within-session micro-moment tiers can slot in here.

    final cleanSession = _cleanSessionTrophy(
      reports: reports,
      sessionRawFormScore: sessionRawFormScore,
    );
    if (cleanSession != null) return cleanSession;

    final goodReps =
        reports.fold<int>(0, (sum, report) => sum + (report.goodReps ?? 0));
    if (goodReps >= _volumeFloor) {
      return Trophy(
        tier: TrophyTier.volume,
        value: '$goodReps',
        label: '$goodReps rep đúng form',
        tag: 'KHỐI LƯỢNG',
      );
    }

    if (sessionRawFormScore >= _solidFloor) {
      return Trophy(
        tier: TrophyTier.showedUp,
        value: '$sessionRawFormScore',
        label: 'Buổi giữ form ổn',
        tag: 'VỮNG',
      );
    }

    final completedCount = math.max(reports.length, 1);
    return Trophy(
      tier: TrophyTier.showedUp,
      value: '$completedCount',
      label: 'Có mặt là thắng rồi',
      tag: 'CÓ MẶT',
    );
  }

  static Trophy? _bestAllTimePb({
    required List<ExerciseSessionReport> reports,
    required int sessionRawFormScore,
    required List<int> priorSessionForms,
    required Map<String, List<int>> priorExerciseForms,
  }) {
    _PbCandidate? best;

    final sessionMargin = _clearedPbMargin(
      current: sessionRawFormScore,
      baseline: priorSessionForms,
      margin: _pbMargin,
      floor: _pbFloor,
    );
    if (sessionMargin != null) {
      best = _PbCandidate.session(
        margin: sessionMargin,
        score: sessionRawFormScore,
      );
    }

    for (final report in reports) {
      final exerciseMargin = _clearedPbMargin(
        current: report.formScore,
        baseline:
            priorExerciseForms[_exerciseHistoryKey(report)] ?? const <int>[],
        margin: _pbMargin,
        floor: _pbFloor,
      );
      if (exerciseMargin == null) continue;
      if (best != null && exerciseMargin <= best.margin) continue;

      best = _PbCandidate.exercise(
        margin: exerciseMargin,
        score: report.formScore,
        exerciseName: report.exerciseName,
      );
    }

    if (best == null) return null;

    return Trophy(
      tier: TrophyTier.allTimePb,
      value: '${best.score}',
      label: best.exerciseName == null
          ? 'Buổi sạch nhất từ trước tới giờ'
          : '${best.exerciseName} sạch nhất từ trước tới giờ',
      tag: 'KỶ LỤC',
      exerciseName: best.exerciseName,
    );
  }

  static Trophy? _bestRecentPb({
    required List<ExerciseSessionReport> reports,
    required int sessionRawFormScore,
    required List<int> priorSessionForms,
    required Map<String, List<int>> priorExerciseForms,
  }) {
    _PbCandidate? best;

    final sessionMargin = _recentPbMargin(
      current: sessionRawFormScore,
      allTimeBaseline: priorSessionForms,
    );
    if (sessionMargin != null) {
      best = _PbCandidate.session(
        margin: sessionMargin,
        score: sessionRawFormScore,
      );
    }

    for (final report in reports) {
      final history =
          priorExerciseForms[_exerciseHistoryKey(report)] ?? const <int>[];
      final exerciseMargin = _recentPbMargin(
        current: report.formScore,
        allTimeBaseline: history,
      );
      if (exerciseMargin == null) continue;
      if (best != null && exerciseMargin <= best.margin) continue;

      best = _PbCandidate.exercise(
        margin: exerciseMargin,
        score: report.formScore,
        exerciseName: report.exerciseName,
      );
    }

    if (best == null) return null;

    return Trophy(
      tier: TrophyTier.recentPb,
      value: '${best.score}',
      label: best.exerciseName == null
          ? 'Phong độ cao nhất $_rollingWindow buổi gần đây'
          : '${best.exerciseName} đỉnh $_rollingWindow buổi gần đây',
      tag: 'PHONG ĐỘ',
      exerciseName: best.exerciseName,
    );
  }

  static Trophy? _cleanSessionTrophy({
    required List<ExerciseSessionReport> reports,
    required int sessionRawFormScore,
  }) {
    if (reports.isEmpty) return null;

    if (reports.every((report) => report.formScore >= _cleanCut)) {
      return Trophy(
        tier: TrophyTier.cleanSession,
        value: '$sessionRawFormScore',
        label: 'Cả buổi sạch form',
        tag: 'SẠCH',
      );
    }

    final best = reports.reduce(
      (currentBest, report) =>
          currentBest.formScore >= report.formScore ? currentBest : report,
    );
    if (best.formScore < _cleanCut) return null;

    return Trophy(
      tier: TrophyTier.cleanSession,
      value: '${best.formScore}',
      label: '${best.exerciseName} form đỉnh',
      tag: 'ĐỈNH',
      exerciseName: best.exerciseName,
    );
  }

  static int? _recentPbMargin({
    required int current,
    required List<int> allTimeBaseline,
  }) {
    final allTimeMargin = _clearedPbMargin(
      current: current,
      baseline: allTimeBaseline,
      margin: _pbMargin,
      floor: _pbFloor,
    );
    if (allTimeMargin != null) {
      return null;
    }

    return _clearedPbMargin(
      current: current,
      baseline: _lastValues(allTimeBaseline, _rollingWindow),
      margin: _pbMargin,
      floor: _pbFloor,
    );
  }

  static int? _clearedPbMargin({
    required int current,
    required List<int> baseline,
    required int margin,
    required int floor,
  }) {
    if (baseline.isEmpty) return null;
    if (current < floor) return null;

    final bestEver = baseline.reduce(math.max);
    final clearedBy = current - bestEver;
    return clearedBy >= margin ? clearedBy : null;
  }

  static List<int> _lastValues(List<int> values, int count) {
    if (values.length <= count) return values;
    return values.sublist(values.length - count);
  }

  /// Key for per-exercise PB history lookups.
  ///
  /// This is the persisted `exercise_sessions.exercise_id`, not
  /// `definition.id`; catalog-launched aliases such as `mcgill_curlup` can
  /// resolve to builder IDs such as `curl_up`, so PB reads must use the same
  /// raw key that was written.
  static String _exerciseHistoryKey(ExerciseSessionReport report) =>
      report.exerciseKey;
}

class _PbCandidate {
  const _PbCandidate({
    required this.margin,
    required this.score,
    this.exerciseName,
  });

  factory _PbCandidate.session({
    required int margin,
    required int score,
  }) {
    return _PbCandidate(margin: margin, score: score);
  }

  factory _PbCandidate.exercise({
    required int margin,
    required int score,
    required String exerciseName,
  }) {
    return _PbCandidate(
      margin: margin,
      score: score,
      exerciseName: exerciseName,
    );
  }

  final int margin;
  final int score;
  final String? exerciseName;
}
