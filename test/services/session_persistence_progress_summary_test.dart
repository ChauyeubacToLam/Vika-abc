import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Pure to/from/delta/trend aggregation for the Progress tab ĐIỂM FORM gauge
// and ĐƯỜNG TIẾN BỘ trend. Input is the window's raw form scores, oldest-first
// (the period windowing happens server-side in progressFormSummary).
void main() {
  test('no sessions -> to/from/delta null, trend empty', () {
    final r = SessionPersistence.deriveProgressFormSummaryForTest(const []);

    expect(r.to, isNull);
    expect(r.from, isNull);
    expect(r.delta, isNull);
    expect(r.trend, isEmpty);
  });

  test('single session -> to shows, from/delta hidden (no baseline)', () {
    final r = SessionPersistence.deriveProgressFormSummaryForTest(const [72]);

    expect(r.to, 72);
    expect(r.from, isNull);
    expect(r.delta, isNull);
    expect(r.trend, [72]);
  });

  test('two sessions -> to shows, from/delta still hidden (< 3 baseline)', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [70, 78]);

    expect(r.to, 78);
    expect(r.from, isNull);
    expect(r.delta, isNull);
    expect(r.trend, [70, 78]);
  });

  test('rising series -> to=last, from=first, positive delta', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [60, 65, 74]);

    expect(r.to, 74);
    expect(r.from, 60);
    expect(r.delta, 14);
    expect(r.trend, [60, 65, 74]);
  });

  test('declining series -> negative delta (meta renders "-N")', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [74, 70, 60]);

    expect(r.to, 60);
    expect(r.from, 74);
    expect(r.delta, -14);
  });

  test('trend preserves input order; to/from read the ends, not the extremes',
      () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [50, 90, 70]);

    expect(r.trend, [50, 90, 70]);
    expect(r.to, 70); // last, not the max
    expect(r.from, 50); // first, not the min
    expect(r.delta, 20);
  });
}
