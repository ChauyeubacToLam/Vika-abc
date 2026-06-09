import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Weekly recent-activity strip for the Progress "Chuỗi" section. Shares the
// streak's local-ISO-week-Monday bucketing + active-week definition, so the
// trailing run of filled cells equals the current streak.
//
// The window is ANCHORED at the user's first active week and grows forward,
// capped at weekCount (gold-standard convention: never pad before the user
// joined). Anchor: now = Wed 2026-06-10 (week of Mon Jun 8).
void main() {
  final now = DateTime(2026, 6, 10, 12);

  // The Monday of each of the last N weeks, current-week-first.
  List<DateTime> mondays([int count = 12]) =>
      List.generate(count, (i) => DateTime(2026, 6, 8).subtract(Duration(days: 7 * i)));

  test('no activity -> empty strip (no dead pre-join cells)', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest([], now: now);
    expect(bars, isEmpty);
  });

  test('first session this week -> a single current cell, not 12', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      [DateTime(2026, 6, 10, 8)],
      now: now,
    );
    expect(bars, [true]);
  });

  test('anchors at the first active week; window grows forward only', () {
    // First session 3 weeks back (May 25 week). Window = [May 25, Jun 1, Jun 8].
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      [
        DateTime(2026, 5, 27, 8), // first active week (May 25)
        DateTime(2026, 6, 8, 8), // current week
      ],
      now: now,
    );
    expect(bars.length, 3);
    expect(bars.first, isTrue); // first week = anchor, active
    expect(bars[1], isFalse); // Jun 1 — rest week the user lived through
    expect(bars.last, isTrue); // current week
  });

  test('all 12 weeks active -> every cell filled, length 12', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      mondays(),
      now: now,
    );

    expect(bars.length, 12);
    expect(bars.every((active) => active), isTrue);
  });

  test('caps at weekCount once history exceeds it (rolling window)', () {
    // 16 weeks of continuous activity — only the last 12 are shown.
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      mondays(16),
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

    expect(bars.length, 12); // first active week is still 11 weeks back
    expect(bars.where((active) => !active).length, 3);
    expect(bars[6], isFalse);
    expect(bars[7], isFalse);
    expect(bars[8], isFalse);
    expect(bars[5], isTrue); // neighbours stay filled
    expect(bars[9], isTrue);
  });

  test('weekCount is respected; ordering is oldest-first (last = current)', () {
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(
      [
        DateTime(2026, 6, 10, 8), // current week (Jun 8)
        DateTime(2026, 5, 18, 8), // first active week (May 18) — anchor
      ],
      weekCount: 4,
      now: now,
    );

    // Anchored at May 18, oldest-first: [May 18, May 25, Jun 1, Jun 8].
    expect(bars.length, 4);
    expect(bars.last, isTrue); // current week
    expect(bars.first, isTrue); // May 18 anchor
    expect(bars[1], isFalse); // May 25 week
    expect(bars[2], isFalse); // Jun 1 week
  });

  test('trailing filled run length == current streak (semantics aligned)', () {
    // Current week active + two prior active weeks, then a gap and an older
    // isolated week. Streak (no grace needed — this week is active) = 3.
    final data = [
      DateTime(2026, 6, 8), // this week
      DateTime(2026, 6, 3), // Jun 1 week
      DateTime(2026, 5, 27), // May 25 week
      DateTime(2026, 4, 20), // Apr 20 week (isolated, older) — first active
    ];

    final streak = SessionPersistence.deriveCurrentStreakForTest(data, now: now);
    final bars = SessionPersistence.deriveStreakWeekBarsForTest(data, now: now);

    var trailingRun = 0;
    for (var i = bars.length - 1; i >= 0 && bars[i]; i--) {
      trailingRun++;
    }

    expect(streak, 3);
    expect(trailingRun, streak);
    expect(bars.first, isTrue); // Apr 20 anchor is the leftmost cell
  });
}
