import 'session_trophy_picker.dart';

enum CoachWatchKind { fault, perfect }

enum SessionDifficulty { easy, moderate, hard }

class FaultCandidate {
  final String exerciseId;
  final String exerciseName;
  final double exerciseFormScore;
  final String faultKey;
  final double rate;
  final bool isPainLinked;
  final int criticalityRank;
  final int sortIndex;
  final String watchCopy;
  final String nextCopy;

  const FaultCandidate({
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseFormScore,
    required this.faultKey,
    required this.rate,
    required this.isPainLinked,
    required this.criticalityRank,
    required this.sortIndex,
    required this.watchCopy,
    required this.nextCopy,
  });
}

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
}

class SessionCoachBuilder {
  const SessionCoachBuilder._();

  static const double _gateRate = 0.10;

  static const String _perfectWatch =
      'Buổi tập hoàn hảo, không có gì phải chỉnh. Cứ đà này nhé!';
  static const String _easyNext = 'Buổi sau thử thêm 2-3 rep mỗi set xem sao.';
  static const String _moderateNext =
      'Giữ nguyên mức này, buổi sau sẽ mượt hơn nữa.';
  static const String _hardNext =
      'Buổi sau cứ giữ nhịp này, cơ thể sẽ quen dần.';
  static const String _faultQuoteTail = 'Tinh chỉnh chút xíu nữa là chuẩn.';
  static const String _perfectQuoteTail = 'Giữ vững nhé!';

  static SessionCoach build({
    required List<FaultCandidate> candidates,
    required Trophy trophy,
    required SessionDifficulty difficulty,
  }) {
    final chosen = _selectWatchCandidate(candidates);
    if (chosen == null) {
      return SessionCoach(
        quote: _composeQuote(trophy: trophy, tail: _perfectQuoteTail),
        watch: _perfectWatch,
        next: _progressionNudge(difficulty),
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

    final criticalityOrder = a.criticalityRank.compareTo(b.criticalityRank);
    if (criticalityOrder != 0) return criticalityOrder;

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

  static String _progressionNudge(SessionDifficulty difficulty) {
    switch (difficulty) {
      case SessionDifficulty.easy:
        return _easyNext;
      case SessionDifficulty.moderate:
        return _moderateNext;
      case SessionDifficulty.hard:
        return _hardNext;
    }
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
