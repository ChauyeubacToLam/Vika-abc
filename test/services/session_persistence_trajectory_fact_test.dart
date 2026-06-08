import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Pure trajectory-fact selection for the Progress tab ĐIỂM FORM gauge. The
// fact is a factual one-liner about the trend (NOT coaching). Priority-ordered,
// first match wins; rows 4–9 never fire below N >= 3.
//
// [trend] is the window's session form scores oldest-first; [delta] mirrors the
// gauge gate (null below the 3-session baseline).
void main() {
  String fact(List<int> trend, int? delta, {int high = 80}) =>
      SessionPersistence.deriveTrajectoryFactForTest(
        trend: trend,
        delta: delta,
        highThreshold: high,
      );

  test('empty trend -> empty string', () {
    expect(fact(const [], null), '');
  });

  group('row 1 — new all-time high (to == max, N >= 2)', () {
    test('rising series ending at its max', () {
      expect(fact(const [60, 65, 74], 14),
          'Điểm form cao nhất từ trước đến giờ.');
    });

    test('two-session series ending at its max beats the N==2 row', () {
      expect(fact(const [70, 78], null),
          'Điểm form cao nhất từ trước đến giờ.');
    });

    test('does NOT fire at N == 1 (no prior point to be "high")', () {
      expect(fact(const [90], null),
          'Buổi đầu đã xong, Vika bắt đầu theo dõi form.');
    });
  });

  group('rows 2 / 3 — pre-baseline framing', () {
    test('single session', () {
      expect(fact(const [55], null),
          'Buổi đầu đã xong, Vika bắt đầu theo dõi form.');
    });

    test('two sessions not at a new high', () {
      expect(fact(const [78, 70], null),
          'Hai buổi rồi, thêm một buổi nữa là thấy xu hướng.');
    });
  });

  group('rows 4–9 — only with a baseline (N >= 3)', () {
    // Each case ends below its own max so row 1 doesn't pre-empt it.
    test('row 4 — strong climb (delta >= +8), interpolates N', () {
      expect(fact(const [60, 75, 70], 10), 'Form lên rõ qua 3 buổi.');
    });

    test('row 5 — gentle climb (+3..+7)', () {
      expect(fact(const [70, 80, 75], 5), 'Form đang đi lên.');
    });

    test('row 6 — flat & high (-2..+2, to >= high)', () {
      expect(fact(const [86, 90, 85], 0, high: 80), 'Giữ vững phong độ cao.');
    });

    test('row 7 — flat & not high (-2..+2, to < high)', () {
      expect(fact(const [70, 74, 71], 1, high: 80), 'Form ổn định.');
    });

    test('row 8 — mild dip (-3..-7)', () {
      expect(fact(const [80, 78, 75], -5),
          'Form chững lại một chút so với đầu giai đoạn.');
    });

    test('row 9 — steep dip (<= -8)', () {
      expect(fact(const [85, 80, 74], -11), 'Form thấp hơn đầu giai đoạn.');
    });

    test('boundary: delta == +8 is a strong climb, not gentle', () {
      expect(fact(const [60, 75, 68], 8), 'Form lên rõ qua 3 buổi.');
    });

    test('boundary: delta == -2 is flat, not a dip', () {
      expect(fact(const [76, 80, 74], -2, high: 80), 'Form ổn định.');
    });
  });
}
