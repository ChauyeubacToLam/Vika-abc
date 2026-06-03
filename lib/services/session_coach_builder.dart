import '../models/fault_candidate.dart';
import 'session_trophy_picker.dart';

enum CoachWatchKind { fault, perfect, lowForm }

class SessionCoach {
  final String quote;
  final String watch;
  final String next;
  final CoachWatchKind kind;
  final String? watchExerciseName;

  const SessionCoach({
    required this.quote,
    required this.watch,
    required this.next,
    required this.kind,
    this.watchExerciseName,
  });
  Map<String, dynamic> toJson() => {
        'quote': quote,
        'watch': watch,
        'next': next,
        'kind': kind.name,
        if (watchExerciseName != null) 'watch_exercise_name': watchExerciseName,
      };
}

class SessionCoachBuilder {
  const SessionCoachBuilder._();

  static const double _gateRate = 0.10;

  static const String _perfectWatch =
      'Buổi tập hoàn hảo, chuẩn không cần chỉnh';
  static const String _perfectNext =
      'Giữ nguyên mức này, buổi sau sẽ mượt hơn nữa.';
  static const String _faultQuoteTail = 'Tinh chỉnh chút xíu nữa là chuẩn.';
  static const String _perfectQuoteTail = 'Giữ vững nhé!';

  static SessionCoach build({
    required List<FaultCandidate> candidates,
    required Trophy trophy,
    required int lowestFormScore,
  }) {
    final chosen = _selectWatchCandidate(candidates);
    if (chosen == null) {
      if (lowestFormScore <= SessionTrophyPicker.solidFloor) {
        return SessionCoach(
            quote: 'Buổi nay chưa vào form lắm, nhưng bạn đã tập xong rồi đó.',
            watch:
                'Nhiều rep chưa vào đúng form, nhưng chuyện đó bình thường thôi.',
            next:
                'Buổi sau mình thử chậm lại, ít rep thôi nhưng chắc từng cái nhé.',
            kind: CoachWatchKind.lowForm);
      }
      return SessionCoach(
        quote: _composeQuote(trophy: trophy, tail: _perfectQuoteTail),
        watch: _perfectWatch,
        next: _perfectNext,
        kind: CoachWatchKind.perfect,
      );
    }

    return SessionCoach(
      quote: _composeQuote(trophy: trophy, tail: _faultQuoteTail),
      watch: chosen.watchCopy,
      next: chosen.nextCopy,
      kind: CoachWatchKind.fault,
      watchExerciseName:
          _hasMultipleExercises(candidates) ? chosen.exerciseName : null,
    );
  }

  static FaultCandidate? _selectWatchCandidate(
    List<FaultCandidate> candidates,
  ) {
    FaultCandidate? best;
    for (final candidate in candidates) {
      if (candidate.rate < _gateRate) continue;
      if (best == null || _compareWatchCandidates(candidate, best) < 0) {
        best = candidate;
      }
    }
    return best;
  }

  static int _compareWatchCandidates(
    FaultCandidate a,
    FaultCandidate b,
  ) {
    if (a.isPainLinked != b.isPainLinked) {
      return a.isPainLinked ? -1 : 1;
    }

    final formScoreOrder = a.exerciseFormScore.compareTo(b.exerciseFormScore);
    if (formScoreOrder != 0) return formScoreOrder;

    final rateOrder = b.rate.compareTo(a.rate);
    if (rateOrder != 0) return rateOrder;

    if (a.isCritical != b.isCritical) return a.isCritical ? -1 : 1;

    return a.sortIndex.compareTo(b.sortIndex);
  }

  static bool _hasMultipleExercises(List<FaultCandidate> candidates) {
    String? firstExerciseId;
    for (final candidate in candidates) {
      firstExerciseId ??= candidate.exerciseId;
      if (candidate.exerciseId != firstExerciseId) return true;
    }
    return false;
  }

  static String _composeQuote({
    required Trophy trophy,
    required String tail,
  }) {
    return '${_positiveLead(trophy)} $tail';
  }

  static String _positiveLead(Trophy trophy) {
    switch (trophy.tier) {
      case TrophyTier.streakMilestone:
        return 'Chuỗi ${trophy.value} ngày, quá đỉnh!';
      case TrophyTier.allTimePb:
      case TrophyTier.recentPb:
        return 'Phong độ lên rõ rồi đó!';
      case TrophyTier.cleanSession:
        return 'Buổi tập sạch form thật sự!';
      case TrophyTier.volume:
      case TrophyTier.showedUp:
        return 'Buổi nay làm tốt lắm!';
    }
  }
}
