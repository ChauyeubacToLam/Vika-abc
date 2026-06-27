// Verifies the bundled-asset CatalogSource: that it loads, and that the alias
// index resolves an exercise by catalog id, definition id, OR class key — the
// fix for the catalog/definition id mismatch (vup vs v__up, mcgill_curlup vs
// curl_up, ...).

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/catalog/catalog_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AssetCatalogSource source;

  setUp(() async {
    source = AssetCatalogSource();
    await source.ensureLoaded();
  });

  test('ensureLoaded is idempotent and resolves the same entry by every alias',
      () async {
    await source.ensureLoaded(); // second call is a no-op
    final byCatalogId = source.lookup('vup');
    final byDefinitionId = source.lookup('v__up');
    expect(byCatalogId, isNotNull);
    expect(byDefinitionId, isNotNull);
    expect(byDefinitionId!.id, 'vup');
    expect(byDefinitionId.baseReps, byCatalogId!.baseReps);
  });

  test('double-underscore definition id resolves to its catalog entry', () {
    // 'curl_up' (definition id) → 'mcgill_curlup' (catalog id).
    final info = source.lookup('curl_up');
    expect(info, isNotNull);
    expect(info!.id, 'mcgill_curlup');
    expect(info.baseReps, 6);
    expect(info.baseSets, 3);
  });

  test('rep entry carries reps; plank is 1 set x 3 reps', () {
    final plank = source.lookup('plank')!;
    expect(plank.baseReps, 3);
    expect(plank.baseSets, 1);
    expect(plank.baseSeconds, isNull);
    expect(plank.volumeLabel, '1 x 3 rep');
  });

  test('hold entry carries seconds, not reps', () {
    final highPlank = source.lookup('high__plank')!; // by definition id
    expect(highPlank.baseSeconds, 20);
    expect(highPlank.baseReps, isNull);
    expect(highPlank.volumeLabel, '1 x 20 giây');
  });

  test('updated static holds use three sets of fifteen seconds', () {
    for (final id in ['side_plank_dip', 'seated_forward_fold', 'sphinx']) {
      final exercise = source.lookup(id)!;
      expect(exercise.baseSets, 3, reason: id);
      expect(exercise.baseSeconds, 15, reason: id);
      expect(exercise.baseReps, isNull, reason: id);
    }
  });

  test('form-unchecked yoga rows still resolve', () {
    final surya = source.lookup('surya_namaskar')!;
    expect(surya.isFormChecked, isFalse);
    expect(surya.baseReps, 3);
    expect(surya.baseSets, 1);
  });

  test('lookupMany keys by the requested id and omits unknowns', () {
    final m = source.lookupMany(['squat', 'curl_up', 'definitely_not_real']);
    expect(m.keys, containsAll(<String>['squat', 'curl_up']));
    expect(m.containsKey('definitely_not_real'), isFalse);
    expect(m['squat']!.baseReps, 8);
  });
}
