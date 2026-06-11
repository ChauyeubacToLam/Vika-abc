import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Pure windowing/averaging for the Home "FORM 7 NGÀY" vitals block.
// Anchored to a fixed `now` so the rolling windows are deterministic:
//   now          = 2026-06-10 12:00
//   current      = [2026-06-03 12:00, 2026-06-10 12:00]
//   prior        = [2026-05-27 12:00, 2026-06-03 12:00)
// A delta only reveals once the prior window holds >= 3 sessions.
({DateTime completedAt, int formScore}) sample(DateTime at, int score) =>
    (completedAt: at, formScore: score);

void main() {
  final now = DateTime(2026, 6, 10, 12);

  test('no sessions in 14d -> percent/delta null, week empty', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      const [],
      now: now,
    );

    expect(r.percent, isNull);
    expect(r.delta, isNull);
    expect(r.week, isEmpty);
  });

  test('one current session -> percent shows, delta hidden, single-point week',
      () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [sample(DateTime(2026, 6, 9, 10), 80)],
      now: now,
    );

    expect(r.percent, 80);
    expect(r.delta, isNull);
    expect(r.week, [80]);
  });

  test('two current, zero prior -> percent + week, delta hidden', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 6, 5, 9), 70),
        sample(DateTime(2026, 6, 9, 9), 80),
      ],
      now: now,
    );

    expect(r.percent, 75);
    expect(r.delta, isNull);
    expect(r.week, [70, 80]);
  });

  test('three current, three prior -> percent + positive delta + week', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 5, 28, 9), 80),
        sample(DateTime(2026, 5, 29, 9), 60),
        sample(DateTime(2026, 5, 31, 9), 70),
        sample(DateTime(2026, 6, 4, 9), 70),
        sample(DateTime(2026, 6, 6, 9), 80),
        sample(DateTime(2026, 6, 9, 9), 90),
      ],
      now: now,
    );

    expect(r.percent, 80); // mean(70, 80, 90)
    expect(r.delta, 10); // 80 - mean(80, 60, 70) = 80 - 70
    expect(r.week, [70, 80, 90]);
  });

  test('negative delta keeps its sign', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 5, 28, 9), 80),
        sample(DateTime(2026, 5, 29, 9), 90),
        sample(DateTime(2026, 5, 30, 9), 100),
        sample(DateTime(2026, 6, 8, 9), 50),
        sample(DateTime(2026, 6, 9, 9), 60),
      ],
      now: now,
    );

    expect(r.percent, 55);
    expect(r.delta, -35); // 55 - mean(80, 90, 100) = 55 - 90
  });

  test('prior with two sessions is not enough -> delta null', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 5, 29, 9), 60),
        sample(DateTime(2026, 5, 31, 9), 70),
        sample(DateTime(2026, 6, 9, 9), 80),
      ],
      now: now,
    );

    expect(r.percent, 80);
    expect(r.delta, isNull);
  });

  test('prior with a single session is not a baseline -> delta null', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 5, 29, 9), 60),
        sample(DateTime(2026, 6, 9, 9), 80),
      ],
      now: now,
    );

    expect(r.percent, 80);
    expect(r.delta, isNull);
  });

  test('genuine zero delta is rendered, not collapsed to null', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 5, 28, 9), 80),
        sample(DateTime(2026, 5, 29, 9), 80),
        sample(DateTime(2026, 5, 31, 9), 80),
        sample(DateTime(2026, 6, 8, 9), 80),
        sample(DateTime(2026, 6, 9, 9), 80),
      ],
      now: now,
    );

    expect(r.percent, 80);
    expect(r.delta, 0);
  });

  test('mean rounds half away from zero', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 6, 8, 9), 70),
        sample(DateTime(2026, 6, 9, 9), 75),
      ],
      now: now,
    );

    expect(r.percent, 73); // 72.5 -> 73
  });

  test('week is oldest-first regardless of input order', () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 6, 9, 9), 90),
        sample(DateTime(2026, 6, 4, 9), 70),
        sample(DateTime(2026, 6, 6, 9), 80),
      ],
      now: now,
    );

    expect(r.week, [70, 80, 90]);
  });

  test('window edges: now-7d is current, now-14d is prior, older is excluded',
      () {
    final r = SessionPersistence.deriveHomeFormSummaryForTest(
      [
        sample(DateTime(2026, 6, 3, 12), 100), // exactly now-7d -> current
        sample(DateTime(2026, 6, 3, 11), 50), // just before -> prior
        sample(DateTime(2026, 5, 30, 9), 30), // mid prior window -> prior
        sample(DateTime(2026, 5, 27, 12), 40), // exactly now-14d -> prior
        sample(DateTime(2026, 5, 27, 11), 999), // before window -> excluded
      ],
      now: now,
    );

    expect(r.week, [100]);
    expect(r.percent, 100);
    expect(r.delta, 60); // 100 - mean(50, 30, 40) = 100 - 40
  });
}
