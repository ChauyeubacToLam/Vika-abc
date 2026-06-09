import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/streak_tier.dart';

void main() {
  group('streakTierLabel', () {
    test('0 (or negative) weeks has no streak label', () {
      expect(streakTierLabel(0), '');
      expect(streakTierLabel(-3), '');
    });

    test('exact tier boundaries', () {
      expect(streakTierLabel(1), '1 tuần');
      expect(streakTierLabel(2), '2 tuần');
      expect(streakTierLabel(4), '1 tháng');
      expect(streakTierLabel(8), '2 tháng');
      expect(streakTierLabel(12), '1 quý');
      expect(streakTierLabel(26), 'nửa năm');
      expect(streakTierLabel(52), '1 năm');
    });

    test('between boundaries snaps down to the highest tier <= weeks', () {
      expect(streakTierLabel(3), '2 tuần');
      expect(streakTierLabel(5), '1 tháng');
      expect(streakTierLabel(11), '2 tháng');
      expect(streakTierLabel(30), 'nửa năm');
      expect(streakTierLabel(60), '1 năm');
    });

    test('past one year counts whole years', () {
      expect(streakTierLabel(104), '2 năm');
      expect(streakTierLabel(156), '3 năm');
      expect(streakTierLabel(170), '3 năm');
    });
  });

  group('isStreakMilestoneWeek', () {
    test('fires only on tier thresholds and whole years', () {
      for (final w in [1, 2, 4, 8, 12, 26, 52, 104, 156]) {
        expect(isStreakMilestoneWeek(w), isTrue, reason: 'week $w');
      }
      for (final w in [0, 3, 5, 7, 11, 27, 53, 103]) {
        expect(isStreakMilestoneWeek(w), isFalse, reason: 'week $w');
      }
    });
  });

  group('nextStreakMilestoneWeek', () {
    test('smallest threshold strictly above; whole years past 52', () {
      expect(nextStreakMilestoneWeek(0), 1);
      expect(nextStreakMilestoneWeek(4), 8);
      expect(nextStreakMilestoneWeek(26), 52);
      expect(nextStreakMilestoneWeek(52), 104);
      expect(nextStreakMilestoneWeek(60), 104);
    });
  });
}
