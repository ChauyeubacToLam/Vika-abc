import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../models/exercise_lookup.dart';
import '../recommendation/recommendation_service.dart'
    show ExerciseLaunchCatalogInfo;

/// Read-only source of default training volume (sets + rep/second target +
/// type), keyed by any exercise alias — catalog id, definition id, or class
/// key. This is the app's single source of truth for launch volume and for the
/// numbers shown on list/catalog surfaces.
///
/// [AssetCatalogSource] reads a build-time export of the Supabase
/// `exercise_catalog` table, so it works offline. The contract is deliberately
/// minimal and implementation-agnostic: a future SupabaseSyncedCatalogSource
/// can implement it as a drop-in replacement.
abstract class CatalogSource {
  /// Idempotent; safe to await repeatedly. Resolves once the catalog is ready.
  Future<void> ensureLoaded();

  /// Synchronous lookup by catalog id, definition id, or class key. Returns
  /// null if the catalog is not loaded yet or the id is unknown.
  ExerciseLaunchCatalogInfo? lookup(String id);

  /// Resolves many ids at once, keyed by the REQUESTED id so callers get back
  /// exactly what they asked for. Unknown ids are omitted.
  Map<String, ExerciseLaunchCatalogInfo> lookupMany(Iterable<String> ids);

  /// The shared instance. Reassign in tests, or to a runtime-synced source.
  static CatalogSource instance = AssetCatalogSource();
}

class AssetCatalogSource implements CatalogSource {
  AssetCatalogSource({AssetBundle? bundle, String assetPath = _defaultAssetPath})
      : _bundle = bundle,
        _assetPath = assetPath;

  static const _defaultAssetPath = 'assets/data/exercise_catalog.json';

  final AssetBundle? _bundle;
  final String _assetPath;

  Future<void>? _loading;
  final Map<String, ExerciseLaunchCatalogInfo> _byKey = {};

  AssetBundle get _assets => _bundle ?? rootBundle;

  @override
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _assets.loadString(_assetPath);
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final e in list) {
        final info = ExerciseLaunchCatalogInfo(
          id: e['catalogId'] as String,
          isFormChecked: e['isFormChecked'] == true,
          vietnameseName: e['vietnameseName'] as String?,
          englishName: e['englishName'] as String?,
          classKey: e['classKey'] as String?,
          baseReps: (e['reps'] as num?)?.toInt(),
          baseSeconds: (e['seconds'] as num?)?.toInt(),
          baseSets: (e['sets'] as num?)?.toInt(),
        );
        // Index under EVERY alias so a lookup by catalog id OR definition id OR
        // class key resolves to the same entry — this is the id-mismatch fix
        // (e.g. catalog 'vup' and definition 'v__up' both land here).
        for (final alias in [
          e['catalogId'],
          e['definitionId'],
          e['classKey'],
        ]) {
          if (alias is String && alias.isNotEmpty) {
            _byKey[normalizeExerciseKey(alias)] = info;
          }
        }
      }
    } catch (error, stack) {
      debugPrint('[CatalogSource] failed to load $_assetPath: $error');
      debugPrintStack(stackTrace: stack);
      // Leave the index empty; callers fall through to their never-crash floor.
    }
  }

  @override
  ExerciseLaunchCatalogInfo? lookup(String id) {
    final direct = _byKey[normalizeExerciseKey(id)];
    if (direct != null) return direct;
    // Bridge engine aliases (e.g. 'pushups') through the definition table, then
    // re-index by the resolved definition id.
    final def = lookupExerciseDefinition(id);
    if (def != null) return _byKey[normalizeExerciseKey(def.id)];
    return null;
  }

  @override
  Map<String, ExerciseLaunchCatalogInfo> lookupMany(Iterable<String> ids) {
    final out = <String, ExerciseLaunchCatalogInfo>{};
    for (final id in ids) {
      final info = lookup(id);
      if (info != null) out[id] = info;
    }
    return out;
  }
}
