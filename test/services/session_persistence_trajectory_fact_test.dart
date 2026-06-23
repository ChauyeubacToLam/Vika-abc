import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Pure trajectory-fact selection for the Progress tab ĐIỂM FORM gauge. The
// fact is a factual one-liner about the trend (NOT coaching). Priority-ordered,
// first match wins; rows 4–9 never fire below N >= 3.
//
// [trend] is the window's session form scores oldest-first; [netChange] is the
// Theil-Sen fitted change across the span (fitted last − fitted first), and
// [average] is the window mean (the gauge headline). Both mirror the gauge gate
// (null below the 3-session baseline).
void main() {
  String fact(List<int> trend, {int? net, int? avg, int high = 80}) =>
      SessionPersistence.deriveTrajectoryFactForTest(
        trend: trend,
        netChange: net,
        average: avg,
        highThreshold: high,
      );

  test('empty trend -> empty string', () {
    expect(fact(const []), '');
  });

  group('row 1 — new all-time high (to == max, N >= 2)', () {
    test('rising series ending at its max', () {
      expect(fact(const [60, 65, 74], net: 14, avg: 66),
          'Điểm form cao nhất từ trước đến giờ.');
    });

    test('two-session series ending at its max beats the N==2 row', () {
      expect(fact(const [70, 78], avg: 74),
          'Điểm form cao nhất từ trước đến giờ.');
    });

    test('does NOT fire at N == 1 (no prior point to be "high")', () {
      expect(fact(const [90], avg: 90),
          'Buổi đầu đã xong, Vika bắt đầu theo dõi form.');
    });
  });

  group('rows 2 / 3 — pre-baseline framing', () {
    test('single session', () {
      expect(fact(const [55], avg: 55),
          'Buổi đầu đã xong, Vika bắt đầu theo dõi form.');
    });

    test('two sessions not at a new high', () {
      expect(fact(const [78, 70], avg: 74),
          'Hai buổi rồi, thêm một buổi nữa là thấy xu hướng.');
    });
  });

  group('rows 4–9 — only with a baseline (N >= 3, netChange + average)', () {
    // Each case ends below its own max so row 1 doesn't pre-empt it.
    test('row 4 — strong climb (netChange >= +8), interpolates N', () {
      expect(
          fact(const [60, 75, 70], net: 10, avg: 68), 'Form lên rõ qua 3 buổi.');
    });

    test('row 5 — gentle climb (+3..+7)', () {
      expect(fact(const [70, 80, 75], net: 5, avg: 75), 'Form đang đi lên.');
    });

    test('row 6 — flat & high (-2..+2, average >= high)', () {
      expect(fact(const [86, 90, 85], net: 0, avg: 87, high: 80),
          'Giữ vững phong độ cao.');
    });

    test('row 7 — flat & not high (-2..+2, average < high)', () {
      expect(
          fact(const [70, 74, 71], net: 1, avg: 72, high: 80), 'Form ổn định.');
    });

    test('row 8 — mild dip (-3..-7)', () {
      expect(fact(const [80, 78, 75], net: -5, avg: 78),
          'Form chững lại một chút so với đầu giai đoạn.');
    });

    test('row 9 — steep dip (<= -8)', () {
      expect(fact(const [85, 80, 74], net: -11, avg: 80),
          'Form thấp hơn đầu giai đoạn.');
    });

    test('boundary: netChange == +8 is a strong climb, not gentle', () {
      expect(
          fact(const [60, 75, 68], net: 8, avg: 68), 'Form lên rõ qua 3 buổi.');
    });

    test('boundary: netChange == -2 is flat, not a dip', () {
      expect(fact(const [76, 80, 74], net: -2, avg: 77, high: 80),
          'Form ổn định.');
    });
  });
}
