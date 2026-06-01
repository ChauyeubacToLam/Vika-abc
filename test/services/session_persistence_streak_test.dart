import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

void main() {
  test('no completions returns 0', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      const [],
      now: DateTime(2026, 6, 10, 12),
    );

    expect(streak, 0);
  });

  test('assume today complete with empty history returns 1', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      const [],
      assumeTodayComplete: true,
      now: DateTime(2026, 6, 10, 12),
    );

    expect(streak, 1);
  });

  test('three consecutive days including today returns 3', () {
    final now = DateTime(2026, 6, 10, 12);
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 10, 8),
        DateTime(2026, 6, 9, 18),
        DateTime(2026, 6, 8, 7),
      ],
      now: now,
    );

    expect(streak, 3);
  });

  test('today plus day-before-yesterday with yesterday missing returns 1', () {
    final now = DateTime(2026, 6, 10, 12);
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 10, 8),
        DateTime(2026, 6, 8, 18),
      ],
      now: now,
    );

    expect(streak, 1);
  });

  test('latest completion two or more days ago returns 0', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [DateTime(2026, 6, 8, 18)],
      now: DateTime(2026, 6, 10, 12),
    );

    expect(streak, 0);
  });

  test('two workouts on the same local day count as one streak day', () {
    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [
        DateTime(2026, 6, 10, 8),
        DateTime(2026, 6, 10, 20),
      ],
      now: DateTime(2026, 6, 10, 21),
    );

    expect(streak, 1);
  });

  test('late-night UTC timestamp is attributed to its local day', () {
    final now = DateTime(2026, 6, 2, 12);
    final lateYesterdayStoredUtc = DateTime(2026, 6, 1, 23, 30).toUtc();
    final priorLocalDayStoredUtc = DateTime(2026, 5, 31, 9).toUtc();

    final streak = SessionPersistence.deriveCurrentStreakForTest(
      [lateYesterdayStoredUtc, priorLocalDayStoredUtc],
      now: now,
    );

    expect(lateYesterdayStoredUtc.toLocal().day, 1);
    expect(streak, 2);
  });
}
