import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/services/session_trophy_picker.dart';

// Pure aggregations behind the Progress tab sections wired off mock data:
//   • weeklySummary       (TUẦN NÀY MỘT NHÌN)
//   • personalRecords     (KỶ LỤC CÁ NHÂN)
//   • streakBars          (CHUỖI LIÊN TIẾP)
//   • nextStreakMilestone (streak card footer)
//
// Anchored to a fixed `now` so the rolling windows + day buckets are
// deterministic:
//   now      = 2026-06-10 12:00
//   current  = [2026-06-03 12:00, 2026-06-10 12:00]
//   prior    = [2026-05-27 12:00, 2026-06-03 12:00)
void main() {
  final now = DateTime(2026, 6, 10, 12);

  ({DateTime completedAt, int? formScore, int? durationSeconds}) wk(
    DateTime at, {
    int? form,
    int? secs,
  }) =>
      (completedAt: at, formScore: form, durationSeconds: secs);

  group('weeklySummary', () {
    test('no sessions this week -> zero stats, deltas null', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(const [], now: now);

      expect(r.sessions, 0);
      expect(r.totalSeconds, 0);
      expect(r.avgForm, isNull);
      expect(r.sessionsDelta, isNull);
      expect(r.secondsDelta, isNull);
      expect(r.avgFormDelta, isNull);
    });

    test('current sessions sum + average; deltas hidden when prior < 3', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [
          wk(DateTime(2026, 6, 4, 9), form: 70, secs: 600),
          wk(DateTime(2026, 6, 6, 9), form: 80, secs: 900),
          wk(DateTime(2026, 6, 9, 9), form: 90, secs: 300),
          // prior window holds only 2 -> no baseline.
          wk(DateTime(2026, 5, 29, 9), form: 60, secs: 600),
          wk(DateTime(2026, 5, 31, 9), form: 60, secs: 600),
        ],
        now: now,
      );

      expect(r.sessions, 3);
      expect(r.totalSeconds, 1800);
      expect(r.avgForm, 80); // mean(70, 80, 90)
      expect(r.sessionsDelta, isNull);
      expect(r.secondsDelta, isNull);
      expect(r.avgFormDelta, isNull);
    });

    test('deltas reveal once the prior window holds >= 3 sessions', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [
          wk(DateTime(2026, 6, 4, 9), form: 80, secs: 1000),
          wk(DateTime(2026, 6, 6, 9), form: 90, secs: 1000),
          // prior: 3 sessions, mean form 60, total 1500s.
          wk(DateTime(2026, 5, 28, 9), form: 60, secs: 500),
          wk(DateTime(2026, 5, 29, 9), form: 60, secs: 500),
          wk(DateTime(2026, 5, 31, 9), form: 60, secs: 500),
        ],
        now: now,
      );

      expect(r.sessions, 2);
      expect(r.totalSeconds, 2000);
      expect(r.avgForm, 85);
      expect(r.sessionsDelta, -1); // 2 - 3
      expect(r.secondsDelta, 500); // 2000 - 1500
      expect(r.avgFormDelta, 25); // 85 - 60
    });

    test('avgForm null when no current session carries a score', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [wk(DateTime(2026, 6, 9, 9), form: null, secs: 300)],
        now: now,
      );

      expect(r.sessions, 1);
      expect(r.totalSeconds, 300);
      expect(r.avgForm, isNull);
    });
  });

  group('personalRecords', () {
    ({String exerciseId, int formScore, DateTime completedAt}) ex(
      String id,
      int score,
      DateTime at,
    ) =>
        (exerciseId: id, formScore: score, completedAt: at);

    test('no sessions -> empty', () {
      expect(
        SessionPersistence.derivePersonalRecordsForTest(const []),
        isEmpty,
      );
    });

    test('best per exercise; previousBest = next-best; achievedAt = first peak',
        () {
      final records = SessionPersistence.derivePersonalRecordsForTest([
        ex('squat', 70, DateTime(2026, 6, 1)),
        ex('squat', 85, DateTime(2026, 6, 5)),
        ex('squat', 80, DateTime(2026, 6, 8)),
        ex('plank', 60, DateTime(2026, 6, 2)),
      ]);

      expect(records.length, 2);
      // Sorted highest-score-first.
      expect(records.first.exerciseId, 'squat');
      expect(records.first.bestScore, 85);
      expect(records.first.previousBest, 80);
      expect(records.first.achievedAt, DateTime(2026, 6, 5));

      expect(records[1].exerciseId, 'plank');
      expect(records[1].bestScore, 60);
      expect(records[1].previousBest, isNull); // single session
    });

    test('single occurrence of the best leaves previousBest null', () {
      final records = SessionPersistence.derivePersonalRecordsForTest([
        ex('lunge', 90, DateTime(2026, 6, 5)),
      ]);

      expect(records.single.bestScore, 90);
      expect(records.single.previousBest, isNull);
    });

    test('best reached twice -> earliest is achievedAt, previousBest = best',
        () {
      final records = SessionPersistence.derivePersonalRecordsForTest([
        ex('squat', 88, DateTime(2026, 6, 8)),
        ex('squat', 88, DateTime(2026, 6, 2)),
      ]);

      expect(records.single.bestScore, 88);
      expect(records.single.achievedAt, DateTime(2026, 6, 2));
      // The other (later) 88 is the previous best.
      expect(records.single.previousBest, 88);
    });
  });

  group('streakBars', () {
    test('empty history -> all false, length dayCount, last = today', () {
      final bars = SessionPersistence.deriveStreakBarsForTest(
        const [],
        dayCount: 14,
        now: now,
      );

      expect(bars.length, 14);
      expect(bars.every((b) => !b), isTrue);
    });

    test('marks the local day of each completion; last entry is today', () {
      final bars = SessionPersistence.deriveStreakBarsForTest(
        [
          DateTime(2026, 6, 10, 8), // today
          DateTime(2026, 6, 8, 18), // 2 days ago
        ],
        dayCount: 14,
        now: now,
      );

      expect(bars.last, isTrue); // today
      expect(bars[bars.length - 3], isTrue); // 2 days ago
      expect(bars[bars.length - 2], isFalse); // yesterday
    });

    test('two completions on the same local day collapse to one bar', () {
      final bars = SessionPersistence.deriveStreakBarsForTest(
        [
          DateTime(2026, 6, 9, 8),
          DateTime(2026, 6, 9, 20),
        ],
        dayCount: 7,
        now: now,
      );

      expect(bars.where((b) => b).length, 1);
      expect(bars[bars.length - 2], isTrue); // yesterday
    });

    test('completions older than the window are dropped', () {
      final bars = SessionPersistence.deriveStreakBarsForTest(
        [DateTime(2026, 5, 1, 8)],
        dayCount: 14,
        now: now,
      );

      expect(bars.every((b) => !b), isTrue);
    });
  });

  group('nextStreakMilestone', () {
    test('returns the smallest canonical milestone above the streak', () {
      expect(SessionPersistence.nextStreakMilestone(0), 3);
      expect(SessionPersistence.nextStreakMilestone(3), 7);
      expect(SessionPersistence.nextStreakMilestone(10), 14);
      expect(SessionPersistence.nextStreakMilestone(14), 30);
    });

    test('null once past the final milestone', () {
      expect(SessionPersistence.nextStreakMilestone(30), isNull);
      expect(SessionPersistence.nextStreakMilestone(45), isNull);
    });

    test('milestones stay in lockstep with the trophy picker set', () {
      expect(SessionTrophyPicker.streakMilestones, {3, 7, 14, 30});
    });
  });
}
