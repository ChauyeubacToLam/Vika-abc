import 'dart:math' as math;
import 'session_persistence.dart';

/// Type of comparison that was found.
/// Ordered from strongest positive signal to weakest fallback.
enum ComparisonType {
  // Positive performance signals
  personalBestFormScore,
  personalBestFault,
  improvementStreak,
  aboveAverage,
  deltaPositive,

  // Fallback supportive tiers (no performance win but something honest to say)
  formSolid,
  consistencyStreak,
  sessionComplete,

  none,
}

/// Result of comparing current session against history.
class SessionComparison {
  final ComparisonType type;
  final String primaryLine;
  final String? secondaryLine;
  final bool isPainLinked;
  final String? faultKey;

  const SessionComparison({
    required this.type,
    required this.primaryLine,
    this.secondaryLine,
    this.isPainLinked = false,
    this.faultKey,
  });
}

class ExerciseComparisonService {
  static const int _minPreviousCountForDelta = 3;
  static const int _formSolidThreshold = 50;
  static const int _consistencyStreakMin = 3;

  /// Walk the priority ladder and return ONE comparison.
  ///
  /// Positive tiers (1-10) fire when there's a performance win.
  /// Fallback tiers (11-13) fire when nothing notable happened but we
  /// still want the banner to show something honest.
  ///
  /// [history] must be oldest-first (matches getSessionHistory return).
  /// [faultLabels] maps fault keys to Vietnamese display names.
  /// [streakLength] is consecutive days of workouts, from UserStats.
  SessionComparison buildExecutiveComparison({
    required int currentFormScore,
    required Map<String, int> currentFaultCounts,
    required List<PreviousSessionSummary> history,
    required List<String> userPainAreas,
    required Map<String, List<String>> painToFaultMap,
    required Map<String, String> faultLabels,
    required int streakLength,
  }) {
    final priorityFaults = <String>{};
    for (final pain in userPainAreas) {
      priorityFaults.addAll(painToFaultMap[pain] ?? []);
    }

    // ═══ Positive tiers ═══

    if (history.isNotEmpty) {
      // Tier 1: PB across all pain-linked faults
      for (final faultKey in priorityFaults) {
        final currentCount = currentFaultCounts[faultKey] ?? 0;
        if (_isFaultCountPB(faultKey, currentCount, history)) {
          final label = faultLabels[faultKey] ?? faultKey;
          return SessionComparison(
            type: ComparisonType.personalBestFault,
            primaryLine:
                '$label thấp nhất từ trước tới giờ — $currentCount lần.',
            isPainLinked: true,
            faultKey: faultKey,
          );
        }
      }

      // Tier 2: Streak across all pain-linked faults
      for (final faultKey in priorityFaults) {
        final currentCount = currentFaultCounts[faultKey] ?? 0;
        final streakStr = _faultStreak(faultKey, currentCount, history);
        if (streakStr != null) {
          final label = faultLabels[faultKey] ?? faultKey;
          return SessionComparison(
            type: ComparisonType.improvementStreak,
            primaryLine: '$label giảm đều 3 buổi rồi: $streakStr.',
            isPainLinked: true,
            faultKey: faultKey,
          );
        }
      }

      // Tier 3: Delta across all pain-linked faults
      for (final faultKey in priorityFaults) {
        final currentCount = currentFaultCounts[faultKey] ?? 0;
        final delta = _faultDelta(faultKey, currentCount, history);
        if (delta != null) {
          final label = faultLabels[faultKey] ?? faultKey;
          return SessionComparison(
            type: ComparisonType.deltaPositive,
            primaryLine: '$label giảm $delta% so với buổi trước đấy.',
            isPainLinked: true,
            faultKey: faultKey,
          );
        }
      }

      // Tier 4: PB on form score
      if (_isFormScorePB(currentFormScore, history)) {
        final maxScore = history.map((s) => s.formScore).reduce(math.max);
        return SessionComparison(
          type: ComparisonType.personalBestFormScore,
          primaryLine:
              'Kỷ lục mới! Form $currentFormScore% — vượt mức cũ $maxScore%.',
        );
      }

      // Tier 5: PB on any fault (non-pain-linked)
      for (final faultKey in currentFaultCounts.keys) {
        final currentCount = currentFaultCounts[faultKey] ?? 0;
        if (_isFaultCountPB(faultKey, currentCount, history)) {
          final label = faultLabels[faultKey] ?? faultKey;
          return SessionComparison(
            type: ComparisonType.personalBestFault,
            primaryLine:
                '$label thấp nhất từ trước tới giờ — $currentCount lần.',
            faultKey: faultKey,
          );
        }
      }

      // Tier 6: Streak on any fault (non-pain-linked)
      for (final faultKey in currentFaultCounts.keys) {
        final currentCount = currentFaultCounts[faultKey] ?? 0;
        final streakStr = _faultStreak(faultKey, currentCount, history);
        if (streakStr != null) {
          final label = faultLabels[faultKey] ?? faultKey;
          return SessionComparison(
            type: ComparisonType.improvementStreak,
            primaryLine: '$label giảm đều 3 buổi rồi: $streakStr.',
            faultKey: faultKey,
          );
        }
      }

      // Tier 7: Delta on any fault (non-pain-linked)
      for (final faultKey in currentFaultCounts.keys) {
        final currentCount = currentFaultCounts[faultKey] ?? 0;
        final delta = _faultDelta(faultKey, currentCount, history);
        if (delta != null) {
          final label = faultLabels[faultKey] ?? faultKey;
          return SessionComparison(
            type: ComparisonType.deltaPositive,
            primaryLine: '$label giảm $delta% so với buổi trước đấy.',
            faultKey: faultKey,
          );
        }
      }

      // Tier 8: Streak on form score
      final formStreakStr = _formScoreStreak(currentFormScore, history);
      if (formStreakStr != null) {
        return SessionComparison(
          type: ComparisonType.improvementStreak,
          primaryLine: 'Form tăng đều 3 buổi rồi: $formStreakStr.',
        );
      }

      // Tier 9: Form score above rolling average by >5%
      final average = history.map((s) => s.formScore).reduce((a, b) => a + b) /
          history.length;
      if (currentFormScore > average * 1.05) {
        return SessionComparison(
          type: ComparisonType.aboveAverage,
          primaryLine: 'Form hôm nay trên mức trung bình.',
          secondaryLine:
              'Buổi này $currentFormScore%, trung bình ${average.round()}%.',
        );
      }

      // Tier 10: Form score delta
      final formDelta = _formScoreDelta(currentFormScore, history);
      if (formDelta != null) {
        return SessionComparison(
          type: ComparisonType.deltaPositive,
          primaryLine: 'Form tăng $formDelta% so với buổi trước.',
        );
      }
    }

    // ═══ Fallback tiers (always reachable, including first session) ═══

    // Tier 11: Form score is solid enough to acknowledge plainly
    if (currentFormScore >= _formSolidThreshold) {
      return SessionComparison(
        type: ComparisonType.formSolid,
        primaryLine: 'Form hôm nay ổn — $currentFormScore%.',
      );
    }

    // Tier 12: Consistency streak (form wasn't great but streak exists)
    if (streakLength >= _consistencyStreakMin) {
      return SessionComparison(
        type: ComparisonType.consistencyStreak,
        primaryLine: '$streakLength ngày liên tiếp rồi đấy. Cứ thế phát huy.',
      );
    }

    // Tier 13: Session complete (factual, no emotional reframe)
    return const SessionComparison(
      type: ComparisonType.sessionComplete,
      primaryLine: 'Hoàn thành buổi tập rồi. Hẹn bạn lần sau.',
    );
  }

  // ─── Helpers ───

  bool _isFaultCountPB(
    String faultKey,
    int currentCount,
    List<PreviousSessionSummary> history,
  ) {
    if (history.length < 2) return false;
    final min =
        history.map((s) => s.faultCounts[faultKey] ?? 9999).reduce(math.min);
    return currentCount < min;
  }

  bool _isFormScorePB(int currentScore, List<PreviousSessionSummary> history) {
    if (history.isEmpty) return false;
    final maxScore = history.map((s) => s.formScore).reduce(math.max);
    return currentScore > maxScore;
  }

  /// history is oldest-first, so history.last = most recent prior session.
  String? _faultStreak(
    String faultKey,
    int currentCount,
    List<PreviousSessionSummary> history,
  ) {
    if (history.length < 2) return null;

    final n1 = history.last.faultCounts[faultKey];
    final n2 = history[history.length - 2].faultCounts[faultKey];

    if (n1 == null || n2 == null) return null;

    if (currentCount < n1 && n1 < n2) {
      return '$n2→$n1→$currentCount';
    }
    return null;
  }

  String? _formScoreStreak(
    int currentScore,
    List<PreviousSessionSummary> history,
  ) {
    if (history.length < 2) return null;

    final s1 = history.last.formScore;
    final s2 = history[history.length - 2].formScore;

    if (currentScore > s1 && s1 > s2) {
      return '$s2%→$s1%→$currentScore%';
    }
    return null;
  }

  int? _faultDelta(
    String faultKey,
    int currentCount,
    List<PreviousSessionSummary> history,
  ) {
    if (history.isEmpty) return null;

    final previousCount = history.last.faultCounts[faultKey] ?? 0;

    if (previousCount < _minPreviousCountForDelta) return null;
    if (currentCount >= previousCount) return null;

    final percentDecrease =
        ((previousCount - currentCount) / previousCount * 100).round();
    return percentDecrease;
  }

  int? _formScoreDelta(int currentScore, List<PreviousSessionSummary> history) {
    if (history.isEmpty) return null;

    final previousScore = history.last.formScore;
    if (previousScore == 0) return null;
    if (currentScore <= previousScore) return null;

    final percentIncrease =
        ((currentScore - previousScore) / previousScore * 100).round();
    return percentIncrease;
  }
}
