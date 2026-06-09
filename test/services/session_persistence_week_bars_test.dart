import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Weekly recent-activity strip for the Progress "Chuỗi" section. Shares the
// streak's local-ISO-week-Monday bucketing + active-week definition, so the
// trailing run of filled cells equals the current streak.
//
// Anchor: now = Wed 2026-06-10 (week of Mon Jun 8). The 12 weeks, oldest-first,
// are the Mondays Mar 23 … Jun 8; index 11 = the current week.
void main() {
  final now = DateTime(2026, 6, 10, 12);

  // The Monday of each of the last 12 weeks, current-week-first.
  List<DateTime> mondays() =>
      List.generate(12, (i) => DateTime(2026, 6, 8).subtract(Duration(days: 7 * i)));

  test('all 12 weeks active -> every cell filled, length 12', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      mondays(),
      now: now,
    );

    expect(bars.length, 12);
    expect(bars.every((active) => active), isTrue);
  });

  test('a 3-week gap leaves exactly three empty cells in the right place', () {
    // Drop weeks 3,4,5 back from current (= oldest-first indices 8,7,6).
    final all = mondays();
    final withGap = [
      for (var i = 0; i < 12; i++)
        if (i < 3 || i > 5) all[i],
    ];

    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      withGap,
      now: now,
    );

    expect(bars.where((active) => !active).length, 3);
    expect(bars[6], isFalse);
    expect(bars[7], isFalse);
    expect(bars[8], isFalse);
    expect(bars[5], isTrue); // neighbours stay filled
    expect(bars[9], isTrue);
  });

  test('a session in the current week fills the last cell only', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      [DateTime(2026, 6, 10, 8)],
      now: now,
    );

    expect(bars.length, 12);
    expect(bars.last, isTrue); // current week = rightmost
    expect(bars.sublist(0, 11).every((active) => !active), isTrue);
  });

  test('weekCount is respected; ordering is oldest-first (last = current)', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      [
        DateTime(2026, 6, 10, 8), // current week (Jun 8)
        DateTime(2026, 5, 27, 8), // two weeks back (May 25 week)
      ],
      weekCount: 4,
      now: now,
    );

    // 4 weeks oldest-first: [May 18, May 25, Jun 1, Jun 8].
    expect(bars.length, 4);
    expect(bars.last, isTrue); // current week
    expect(bars[1], isTrue); // May 25 week
    expect(bars[0], isFalse); // May 18 week
    expect(bars[2], isFalse); // Jun 1 week
  });

  test('trailing filled run length == current streak (semantics aligned)', () {
    // Current week active + two prior active weeks, then a gap and an older
    // isolated week. Streak (no grace needed — this week is active) = 3.
    final data = [
      DateTime(2026, 6, 8), // this week
      DateTime(2026, 6, 3), // Jun 1 week
      DateTime(2026, 5, 27), // May 25 week
      DateTime(2026, 4, 20), // Apr 20 week (isolated, older)
    ];

    final streak = SessionPersistence.deriveCurrentStreakForTest(data, now: now);
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(data, now: now);

    var trailingRun = 0;
    for (var i = bars.length - 1; i >= 0 && bars[i]; i--) {
      trailingRun++;
    }

    expect(streak, 3);
    expect(trailingRun, streak);
  });
}
