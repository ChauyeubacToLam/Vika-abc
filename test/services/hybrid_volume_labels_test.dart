import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/services/workout_launch_service.dart';

final _testClient = SupabaseClient('http://localhost', 'test-key');

class _FakeRecommendationService extends RecommendationService {
  _FakeRecommendationService(this.catalog)
      : super(
          client: _testClient,
          sessions: SessionPersistence(client: _testClient),
        );

  final Map<String, ExerciseLaunchCatalogInfo> catalog;

  @override
  Future<Map<String, ExerciseLaunchCatalogInfo>>
      fetchLaunchCatalogInfoForExerciseIds(Iterable<String> exerciseIds) async {
    return {
      for (final id in exerciseIds)
        if (catalog[id] case final info?) id: info,
    };
  }
}

ExerciseLaunchCatalogInfo _catalogInfo({
  int? reps,
  int? seconds,
  int sets = 3,
}) {
  return ExerciseLaunchCatalogInfo(
    id: 'high_plank',
    classKey: 'high_plank',
    isFormChecked: true,
    baseReps: reps,
    baseSeconds: seconds,
    baseSets: sets,
  );
}

void main() {
  test('catalog labels show repeated hold count only when above one', () {
    expect(_catalogInfo(reps: 3, seconds: 20).volumeLabel, '3 x 3 x 20 giây');
    expect(_catalogInfo(reps: 1, seconds: 20).volumeLabel, '3 x 20 giây');
    expect(_catalogInfo(seconds: 20).volumeLabel, '3 x 20 giây');
    expect(_catalogInfo(reps: 8).volumeLabel, '3 x 8 rep');
  });

  test('workout labels prefer seconds and preserve rep-only wording', () {
    expect(
      workoutVolumeLabel(
        const VolumePrescription(
          sets: 3,
          reps: 3,
          seconds: 20,
          restSeconds: 30,
        ),
      ),
      '3 x 3 x 20 giây',
    );
    expect(
      workoutVolumeLabel(
        const VolumePrescription(
          sets: 3,
          reps: 1,
          seconds: 20,
          restSeconds: 30,
        ),
      ),
      '3 x 20 giây',
    );
    expect(
      workoutVolumeLabel(
        const VolumePrescription(sets: 3, reps: 8, restSeconds: 60),
      ),
      '3 x 8 rep',
    );
  });

  test('direct catalog launch keeps both hybrid targets', () async {
    final catalogInfo = _catalogInfo(reps: 3, seconds: 20);
    final service = WorkoutLaunchService(
      recommendations: _FakeRecommendationService({
        catalogInfo.id: catalogInfo,
      }),
    );

    final sequence =
        await service.buildSequenceFromCatalogIds([catalogInfo.id]);

    expect(sequence, hasLength(1));
    expect(sequence.single.prescription?.reps, 3);
    expect(sequence.single.prescription?.seconds, 20);
  });
}
