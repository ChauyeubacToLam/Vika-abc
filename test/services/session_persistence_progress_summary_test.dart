import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/widgets/progress/period_tabs.dart';

// Pure average/direction/trend aggregation for the Progress tab ĐIỂM FORM gauge
// and ĐƯỜNG TIẾN BỘ trend. Input is the window's raw form scores, oldest-first
// (the period windowing happens server-side in progressFormSummary). The gauge
// headline is the window AVERAGE; the trend chip reads the Theil-Sen slope
// direction over the window, gated on the same 3-session baseline.
void main() {
  test('no sessions -> average null, direction none, trend empty', () {
    final r = SessionPersistence.deriveProgressFormSummaryForTest(const []);

    expect(r.average, isNull);
    expect(r.direction, FormTrendDirection.none);
    expect(r.trend, isEmpty);
  });

  test('single session -> average shows, direction none (no baseline)', () {
    final r = SessionPersistence.deriveProgressFormSummaryForTest(const [72]);

    expect(r.average, 72);
    expect(r.direction, FormTrendDirection.none);
    expect(r.trend, [72]);
  });

  test('two sessions -> average is the mean, direction still none (< 3)', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [70, 78]);

    expect(r.average, 74); // (70 + 78) / 2
    expect(r.direction, FormTrendDirection.none);
    expect(r.trend, [70, 78]);
  });

  test('rising series -> average is the mean, direction up', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [60, 65, 74]);

    expect(r.average, 66); // (60 + 65 + 74) / 3 = 66.33 -> 66
    expect(r.direction, FormTrendDirection.up);
    expect(r.trend, [60, 65, 74]);
  });

  test('declining series -> direction down (neutral chip, not alarming)', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [74, 70, 60]);

    expect(r.average, 68); // (74 + 70 + 60) / 3 = 68
    expect(r.direction, FormTrendDirection.down);
  });

  test('flat series (slope within +-threshold) -> direction flat', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [72, 72, 72]);

    expect(r.average, 72);
    expect(r.direction, FormTrendDirection.flat);
  });

  test('average is the window mean, not an endpoint; trend preserves order', () {
    final r =
        SessionPersistence.deriveProgressFormSummaryForTest(const [50, 90, 70]);

    expect(r.trend, [50, 90, 70]);
    expect(r.average, 70); // mean of (50, 90, 70), not the last value
  });
}
