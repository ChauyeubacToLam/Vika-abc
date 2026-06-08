import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_persistence.dart';

// Pure per-exercise improvement ranking behind the Progress tab
// BÀI TẬP NỔI BẬT cards (SessionPersistence.deriveRankedInsightsForTest).
//
// The x-axis for every slope is the session order index (0,1,2…), so the
// fixtures only need to be ordered oldest-first — no timestamps. Theil-Sen
// over a clean linear series returns exactly the underlying slope + intercept,
// which makes the fitted from/to values predictable.
void main() {
  // Builds one session row. Faults default to none; reps default to 10 so a
  // fault_count of N reads as a (10·N)% rate.
  RankInsightSession sess(
    String id,
    int form, {
    Map<String, int> faults = const {},
    int reps = 10,
  }) =>
      (exerciseId: id, formScore: form, faultCounts: faults, totalReps: reps);

  // Squat-shaped metadata: 'knee' pain → depth fault; both faults labelled.
  const squatMeta = (
    painToFaultMap: {
      'knee': ['depth_fails_count'],
    },
    praiseMetricNames: {
      'depth_fails_count': 'Độ sâu',
      'heel_fails_count': 'Gót chân',
    },
  );

  List<RankInsightHeadline> derive(
    Iterable<RankInsightSession> sessions, {
    Set<String> pain = const {},
    Map<String, RankInsightMeta> meta = const {},
  }) =>
      SessionPersistence.deriveRankedInsightsForTest(
        sessions: sessions,
        activePainAreas: pain,
        metaByExercise: meta,
      );

  group('qualification', () {
    test('fewer than 3 sessions -> exercise skipped entirely', () {
      final r = derive([sess('squat', 60), sess('squat', 80)]);
      expect(r, isEmpty);
    });

    test('flat form, no faults -> nothing qualifies', () {
      final r = derive([sess('squat', 70), sess('squat', 70), sess('squat', 70)]);
      expect(r, isEmpty);
    });

    test('declining form -> not a qualifying candidate', () {
      final r = derive([sess('squat', 80), sess('squat', 70), sess('squat', 60)]);
      expect(r, isEmpty);
    });
  });

  group('form tier', () {
    test('form slope below the form gate is skipped', () {
      final r = derive([sess('squat', 60), sess('squat', 61), sess('squat', 62)]);
      expect(r, isEmpty);
    });

    test('rising form -> form headline with fitted from/to', () {
      final r = derive([sess('squat', 60), sess('squat', 67), sess('squat', 74)]);

      expect(r, hasLength(1));
      final h = r.single;
      expect(h.tier, InsightTier.form);
      expect(h.faultKey, isNull);
      expect(h.metricLabel, isNull);
      expect(h.slopeMagnitude, closeTo(7, 1e-9));
      expect(h.fromValue, 60);
      expect(h.toValue, 74);
      // Bar chart is fed the actual per-session form scores; higher = better.
      expect(h.series, [60, 67, 74]);
      expect(h.lowerIsBetter, isFalse);
    });

    test('fitted endpoints clamp into 0..100', () {
      // Slope +20/session from a high base would project past 100.
      final r = derive([sess('squat', 70), sess('squat', 90), sess('squat', 100)]);
      final h = r.single;
      expect(h.tier, InsightTier.form);
      expect(h.toValue, lessThanOrEqualTo(100));
    });

    test('exercise with no metadata entry can still produce a form headline', () {
      // Models the GenericReportBuilder fallback (empty maps).
      final r = derive([sess('plank', 50), sess('plank', 60), sess('plank', 70)]);
      expect(r.single.tier, InsightTier.form);
    });
  });

  group('fault tiers', () {
    test('fault-rate slope below the fault gate is skipped', () {
      final r = derive(
        [
          sess('squat', 70, faults: {'depth_fails_count': 10}, reps: 10000),
          sess('squat', 70, faults: {'depth_fails_count': 10}, reps: 10000),
          sess('squat', 70, faults: {'depth_fails_count': 9}, reps: 10000),
        ],
        pain: {'knee'},
        meta: {'squat': squatMeta},
      );

      expect(r, isEmpty);
    });

    test('active pain-linked fault outranks a rising form on the same exercise',
        () {
      // Form rises AND the knee-linked depth fault falls — pain tier wins.
      final r = derive(
        [
          sess('squat', 60, faults: {'depth_fails_count': 4}),
          sess('squat', 67, faults: {'depth_fails_count': 2}),
          sess('squat', 74, faults: {'depth_fails_count': 0}),
        ],
        pain: {'knee'},
        meta: {'squat': squatMeta},
      );

      final h = r.single;
      expect(h.tier, InsightTier.pain);
      expect(h.faultKey, 'depth_fails_count');
      expect(h.metricLabel, 'Độ sâu');
      // Rate 40% -> 0%, sign-flipped slope = +20/session.
      expect(h.slopeMagnitude, closeTo(20, 1e-9));
      expect(h.fromValue, 40);
      expect(h.toValue, 0);
      // Bar chart gets the actual per-session rate %; lower = better.
      expect(h.series, [40, 20, 0]);
      expect(h.lowerIsBetter, isTrue);
    });

    test('falling fault with no active pain link -> generic tier', () {
      final r = derive(
        [
          sess('squat', 70, faults: {'heel_fails_count': 3}),
          sess('squat', 70, faults: {'heel_fails_count': 2}),
          sess('squat', 70, faults: {'heel_fails_count': 1}),
        ],
        // 'knee' active, but heel isn't pain-linked -> stays generic.
        pain: {'knee'},
        meta: {'squat': squatMeta},
      );

      final h = r.single;
      expect(h.tier, InsightTier.generic);
      expect(h.faultKey, 'heel_fails_count');
      expect(h.metricLabel, 'Gót chân');
      expect(h.fromValue, 30);
      expect(h.toValue, 10);
    });

    test('unlabelled falling fault is unrenderable -> no headline', () {
      // Flat form + a falling fault that has NO praiseMetricNames label.
      final r = derive(
        [
          sess('squat', 70, faults: {'mystery_fails_count': 3}),
          sess('squat', 70, faults: {'mystery_fails_count': 2}),
          sess('squat', 70, faults: {'mystery_fails_count': 1}),
        ],
        meta: {'squat': squatMeta},
      );
      expect(r, isEmpty);
    });

    test('fault rate is rep-volume adjusted, not raw count', () {
      // Same raw counts each session, but reps grow -> rate still falls.
      final r = derive(
        [
          sess('squat', 70, faults: {'heel_fails_count': 2}, reps: 10), // 20%
          sess('squat', 70, faults: {'heel_fails_count': 2}, reps: 20), // 10%
          sess('squat', 70, faults: {'heel_fails_count': 2}, reps: 40), // 5%
        ],
        meta: {'squat': squatMeta},
      );
      // A by-count view would read flat (2,2,2); the rate view improves.
      expect(r.single.tier, InsightTier.generic);
      expect(r.single.fromValue, greaterThan(r.single.toValue));
    });
  });

  group('cross-exercise ranking', () {
    test('tier rank orders pain before form before generic', () {
      final r = derive(
        [
          // squat: pain-linked depth fault falling.
          sess('squat', 60, faults: {'depth_fails_count': 4}),
          sess('squat', 60, faults: {'depth_fails_count': 2}),
          sess('squat', 60, faults: {'depth_fails_count': 0}),
          // plank: rising form (no meta -> form only).
          sess('plank', 50),
          sess('plank', 60),
          sess('plank', 70),
          // pushup: generic heel fault falling, no active pain link.
          sess('pushup', 70, faults: {'heel_fails_count': 3}),
          sess('pushup', 70, faults: {'heel_fails_count': 2}),
          sess('pushup', 70, faults: {'heel_fails_count': 1}),
        ],
        pain: {'knee'},
        meta: {'squat': squatMeta, 'pushup': squatMeta},
      );

      expect(r.map((h) => h.exerciseId).toList(), ['squat', 'plank', 'pushup']);
      expect(r.map((h) => h.tier).toList(),
          [InsightTier.pain, InsightTier.form, InsightTier.generic]);
    });

    test('within a tier, steeper slope ranks first', () {
      final r = derive([
        // gentle +2/session
        sess('plank', 60),
        sess('plank', 62),
        sess('plank', 64),
        // steep +10/session
        sess('squat', 50),
        sess('squat', 60),
        sess('squat', 70),
      ]);

      expect(r.map((h) => h.exerciseId).toList(), ['squat', 'plank']);
    });

    test('equal slope -> deterministic, stable tiebreak (not render-random)', () {
      // Identical rising series; only the order the exercises arrive in differs
      // (each series stays oldest-first). The tiebreak must not depend on it.
      final alpha = [sess('alpha', 60), sess('alpha', 67), sess('alpha', 74)];
      final bravo = [sess('bravo', 60), sess('bravo', 67), sess('bravo', 74)];

      final first = derive([...alpha, ...bravo]).map((h) => h.exerciseId).toList();
      final second = derive([...bravo, ...alpha]).map((h) => h.exerciseId).toList();
      expect(first, second);
    });
  });
}
