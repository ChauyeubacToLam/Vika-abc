import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Pure aggregations behind the Progress tab sections wired off mock data:
//   • weeklySummary       (TỔNG QUAN TUẦN NÀY)
//   • personalRecords     (KỶ LỤC CÁ NHÂN)
//   • nextStreakMilestone (streak tier thresholds, in consecutive active weeks)
//
// weeklySummary is now program-week-relative: deriveWeeklySummaryForTest takes
// two PRE-BUCKETED completed sample lists (current program week, then the prior
// week). The windowing moved into weeklySummary(), so these samples are
// date-free — just form score + duration.
void main() {
  ({int? formScore, int? durationSeconds}) wk({int? form, int? secs}) =>
      (formScore: form, durationSeconds: secs);

  group('weeklySummary', () {
    test('no sessions -> zero stats, deltas null', () {
      final r =
          SessionPersistence.deriveWeeklySummaryForTest(const [], const []);

      expect(r.sessions, 0);
      expect(r.totalSeconds, 0);
      expect(r.avgForm, isNull);
      expect(r.sessionsDelta, isNull);
      expect(r.secondsDelta, isNull);
      expect(r.avgFormDelta, isNull);
    });

    test('current program week 1 (no prior) -> sums + avg, deltas null', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [
          wk(form: 70, secs: 600),
          wk(form: 80, secs: 900),
          wk(form: 90, secs: 300),
        ],
        const [],
      );

      expect(r.sessions, 3);
      expect(r.totalSeconds, 1800);
      expect(r.avgForm, 80); // mean(70, 80, 90)
      expect(r.sessionsDelta, isNull);
      expect(r.secondsDelta, isNull);
      expect(r.avgFormDelta, isNull);
    });

    test('current week 5 (3 sessions) vs prior week 4 (2) -> deltas revealed',
        () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [
          wk(form: 80, secs: 1000),
          wk(form: 90, secs: 1000),
          wk(form: 85, secs: 1000),
        ],
        [wk(form: 60, secs: 500), wk(form: 70, secs: 500)],
      );

      expect(r.sessions, 3);
      expect(r.totalSeconds, 3000);
      expect(r.avgForm, 85); // mean(80, 90, 85)
      expect(r.sessionsDelta, 1); // 3 - 2
      expect(r.secondsDelta, 2000); // 3000 - 1000
      expect(r.avgFormDelta, 20); // 85 - mean(60, 70)=65
    });

    test('a single prior session is enough to reveal deltas (min = 1)', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [wk(form: 80, secs: 600)],
        [wk(form: 60, secs: 400)],
      );

      expect(r.sessionsDelta, 0); // 1 - 1
      expect(r.secondsDelta, 200); // 600 - 400
      expect(r.avgFormDelta, 20); // 80 - 60
    });

    test('avgForm null when no current session carries a score', () {
      final r = SessionPersistence.deriveWeeklySummaryForTest(
        [wk(form: null, secs: 300)],
        const [],
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

  group('nextStreakMilestone (consecutive active weeks)', () {
    test('returns the smallest tier threshold above the streak', () {
      expect(SessionPersistence.nextStreakMilestone(0), 1);
      expect(SessionPersistence.nextStreakMilestone(1), 2);
      expect(SessionPersistence.nextStreakMilestone(3), 4);
      expect(SessionPersistence.nextStreakMilestone(10), 12);
      expect(SessionPersistence.nextStreakMilestone(26), 52);
    });

    test('past the final fixed tier it returns the next whole year', () {
      expect(SessionPersistence.nextStreakMilestone(52), 104);
      expect(SessionPersistence.nextStreakMilestone(60), 104);
      expect(SessionPersistence.nextStreakMilestone(104), 156);
    });
  });
}
