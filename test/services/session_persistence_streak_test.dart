import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Streak is now consecutive ACTIVE WEEKS (an ISO week, local tz, with >= 1
// completed session). Jun 8 2026 is a Monday, so the week buckets used below
// are: Mon Jun 8 (this week), Mon Jun 1, Mon May 25.
void main() {
  // A Wednesday in the week of Mon Jun 8 2026.
  final now = DateTime(2026, 6, 10, 12);

  test('no completions returns 0', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      const [],
      now: now,
    );

    expect(streak, 0);
  });

  test('assume this week complete with empty history returns 1', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      const [],
      assumeTodayComplete: true,
      now: now,
    );

    expect(streak, 1);
  });

  test('three consecutive active weeks including this week returns 3', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 10, 8), // this week (Mon Jun 8)
        DateTime(2026, 6, 3, 18), // week of Mon Jun 1
        DateTime(2026, 5, 27, 7), // week of Mon May 25
      ],
      now: now,
    );

    expect(streak, 3);
  });

  test('a single missed week (gap) ends the run at this week', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 10, 8), // this week
        DateTime(2026, 5, 27, 18), // two weeks ago; LAST week is empty
      ],
      now: now,
    );

    expect(streak, 1);
  });

  test('latest active week two or more weeks ago returns 0', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [DateTime(2026, 5, 27, 18)], // week of May 25; this & last week empty
      now: now,
    );

    expect(streak, 0);
  });

  test('this week still empty but last week active counts from last week', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 3, 8), // week of Mon Jun 1 (last week)
        DateTime(2026, 5, 27, 8), // week of Mon May 25
      ],
      now: now,
    );

    expect(streak, 2);
  });

  test('several sessions (and rest days) in one week count as one active week',
      () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 8, 8), // Monday
        DateTime(2026, 6, 10, 20), // Wednesday — same week, after a rest day
      ],
      now: now,
    );

    expect(streak, 1);
  });

  test('a late Sunday-night session is bucketed into its own ISO week', () {
    // Stored UTC; .toLocal() lands on Sun Jun 7 23:30 → week of Mon Jun 1,
    // NOT the following week. Paired with a this-week session that gives a
    // 2-week run only if the Sunday landed in last week's bucket.
    final lateSundayStoredUtc = DateTime(2026, 6, 7, 23, 30).toUtc();
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 10, 8), // this week (Jun 8)
        lateSundayStoredUtc, // week of Jun 1
      ],
      now: now,
    );

    expect(lateSundayStoredUtc.toLocal().day, 7);
    expect(streak, 2);
  });
}
