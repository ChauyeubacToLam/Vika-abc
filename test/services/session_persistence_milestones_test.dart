import 'package:flutter_test/flutter_test.dart';
import 'package:vika/data/milestones.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/widgets/progress/milestone_rail.dart';

// Pure unlock computation for the Progress-tab CỘT MỐC rail, plus the rail's
// visible-rung selection. Streak / Sessions / Form / Consistency rungs are all
// all-time; consistency needs a weekly scheduled count.
void main() {
  ({DateTime completedAt, int? rawFormScore}) s(DateTime at, {int? form}) =>
      (completedAt: at, rawFormScore: form);

  Milestone rung(List<Milestone> ms, MilestoneCategory cat, int threshold) =>
      ms.firstWhere((m) => m.category == cat && m.threshold == threshold);

  group('deriveUnlockedMilestones', () {
    test('empty history -> every rung locked, full catalog returned', () {
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        const [],
        scheduledPerWeek: 3,
      );

      expect(ms.length, milestoneCatalog.length);
      expect(ms.every((m) => !m.unlocked), isTrue);
      expect(ms.every((m) => m.unlockedOn == null), isTrue);
    });

    test('sessions count unlocks rungs at/under the count, dates the nth', () {
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [
          for (var d = 1; d <= 5; d++) s(DateTime(2026, 6, d), form: 50),
        ],
        scheduledPerWeek: 7, // high -> consistency stays out of the way
      );

      expect(rung(ms, MilestoneCategory.sessions, 1).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.sessions, 5).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.sessions, 5).unlockedOn, '5/6');
      expect(rung(ms, MilestoneCategory.sessions, 10).unlocked, isFalse);
    });

    test('form unlocks on best raw score; dates the first session to reach it',
        () {
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [
          s(DateTime(2026, 6, 1), form: 70),
          s(DateTime(2026, 6, 3), form: 92),
          s(DateTime(2026, 6, 5), form: 88),
        ],
        scheduledPerWeek: 3,
      );

      expect(rung(ms, MilestoneCategory.form, 80).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.form, 80).unlockedOn, '3/6');
      expect(rung(ms, MilestoneCategory.form, 90).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.form, 100).unlocked, isFalse);
    });

    test('streak uses the longest consecutive active-WEEK run; dates crossing',
        () {
      // Four consecutive Mondays (Jun 8 2026 is a Monday): weeks May 18, May
      // 25, Jun 1, Jun 8 — a 4-week run.
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [
          s(DateTime(2026, 5, 18)),
          s(DateTime(2026, 5, 25)),
          s(DateTime(2026, 6, 1)),
          s(DateTime(2026, 6, 8)),
        ],
        scheduledPerWeek: 99,
      );

      // Crossing date = the Monday of the week that pushed the run to each
      // threshold.
      expect(rung(ms, MilestoneCategory.streak, 1).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.streak, 1).unlockedOn, '18/5');
      expect(rung(ms, MilestoneCategory.streak, 2).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.streak, 2).unlockedOn, '25/5');
      expect(rung(ms, MilestoneCategory.streak, 4).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.streak, 4).unlockedOn, '8/6');
      expect(rung(ms, MilestoneCategory.streak, 8).unlocked, isFalse);
    });

    test('multiple sessions in one week count as a single active week', () {
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [
          s(DateTime(2026, 6, 1, 8)), // week of Jun 1
          s(DateTime(2026, 6, 3, 20)), // same week
          s(DateTime(2026, 6, 8)), // week of Jun 8
        ],
        scheduledPerWeek: 99,
      );

      // Longest run is 2 WEEKS -> the 2-week rung opens, the 4-week stays shut.
      expect(rung(ms, MilestoneCategory.streak, 2).unlocked, isTrue);
      expect(rung(ms, MilestoneCategory.streak, 4).unlocked, isFalse);
    });

    test('Tuần trọn vẹn unlocks when a Mon–Sun week meets the schedule', () {
      // Jun 8 2026 is a Monday; 9/10/11 sit in the same Mon–Sun week.
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [
          s(DateTime(2026, 6, 9)),
          s(DateTime(2026, 6, 10)),
          s(DateTime(2026, 6, 11)),
        ],
        scheduledPerWeek: 3,
      );

      final week = rung(ms, MilestoneCategory.consistency, kConsistencyWeek);
      expect(week.unlocked, isTrue);
      expect(week.unlockedOn, '11/6'); // the session that completed the week
      // Month target = 3 * 4 = 12 sessions; nowhere near.
      expect(rung(ms, MilestoneCategory.consistency, kConsistencyMonth).unlocked,
          isFalse);
    });

    test('consistency stays locked when no schedule is set (0 disables it)', () {
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [
          for (var d = 8; d <= 14; d++) s(DateTime(2026, 6, d)),
        ],
        scheduledPerWeek: 0,
      );

      expect(rung(ms, MilestoneCategory.consistency, kConsistencyWeek).unlocked,
          isFalse);
      expect(rung(ms, MilestoneCategory.consistency, kConsistencyMonth).unlocked,
          isFalse);
    });
  });

  group('selectRailMilestones', () {
    test('per category: unlocked rungs then the next locked chase target', () {
      // Sessions: 5 done -> rungs 1 & 5 unlocked; next target = 10.
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        [for (var d = 1; d <= 5; d++) s(DateTime(2026, 6, d), form: 50)],
        scheduledPerWeek: 3,
      );

      final sessionRungs = selectRailMilestones(ms)
          .where((m) => m.category == MilestoneCategory.sessions)
          .toList();

      expect(sessionRungs.map((m) => m.threshold), [1, 5, 10]);
      expect(sessionRungs[0].unlocked, isTrue);
      expect(sessionRungs[1].unlocked, isTrue);
      expect(sessionRungs[2].unlocked, isFalse); // the chase target
    });

    test('never blank — a fresh account shows the first locked rung per category',
        () {
      final ms = SessionPersistence.deriveUnlockedMilestonesForTest(
        const [],
        scheduledPerWeek: 3,
      );
      final rail = selectRailMilestones(ms);

      // One locked target per category, in render order.
      expect(rail.length, 4);
      expect(rail.map((m) => m.category), [
        MilestoneCategory.streak,
        MilestoneCategory.sessions,
        MilestoneCategory.form,
        MilestoneCategory.consistency,
      ]);
      expect(rail.every((m) => !m.unlocked), isTrue);
      // The chase target is the smallest threshold in each category.
      expect(rung(rail, MilestoneCategory.streak, 1).threshold, 1);
      expect(rung(rail, MilestoneCategory.sessions, 1).threshold, 1);
    });
  });
}
