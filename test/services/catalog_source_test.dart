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

  test('hybrid hold entry carries per-hold seconds AND a hold-count reps', () {
    // Plank-model (07-12): high_plank is hybrid — base_reps is the HOLD COUNT
    // (3 holds), base_seconds the per-hold duration (20s). The label keeps the
    // count because it is above one. Mirrors prod + the bundled JSON.
    final highPlank = source.lookup('high__plank')!; // by definition id
    expect(highPlank.baseSeconds, 20);
    expect(highPlank.baseReps, 3);
    expect(highPlank.volumeLabel, '1 x 3 x 20 giây');
  });

  test('former static holds are now 1-hold hybrids (reps=1 + seconds)', () {
    // Two-modality flip (ADR 07-12): every hold row carries base_reps. These
    // three were seconds-only; they became single-hold hybrids (reps=1). Shape
    // differs per row now — verified against prod + the resynced JSON 07-12.
    // reps==1 keeps the label at "sets x seconds giây" (count hidden above 1).
    final sidePlank = source.lookup('side_plank_dip')!;
    expect(sidePlank.baseSets, 3);
    expect(sidePlank.baseReps, 1);
    expect(sidePlank.baseSeconds, 15);
    expect(sidePlank.volumeLabel, '3 x 15 giây');

    for (final id in ['seated_forward_fold', 'sphinx']) {
      final exercise = source.lookup(id)!;
      expect(exercise.baseSets, 1, reason: id);
      expect(exercise.baseReps, 1, reason: id);
      expect(exercise.baseSeconds, 30, reason: id);
      expect(exercise.volumeLabel, '1 x 30 giây', reason: id);
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
