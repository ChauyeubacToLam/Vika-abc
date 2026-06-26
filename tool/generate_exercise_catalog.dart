// Regenerates assets/data/exercise_catalog.json from the live Supabase
// `exercise_catalog` table — the single source of truth for default training
// volume. Run from the repo root:
//
//   dart run tool/generate_exercise_catalog.dart
//
// Reads SUPABASE_URL / SUPABASE_ANON_KEY from the environment or the bundled
// `.env`. Each catalog row is resolved to an ExerciseDefinition using the SAME
// order as WorkoutLaunchService._lookupLaunchDefinition (id → class_key →
// english_name). The tool FAILS LOUDLY (non-zero exit) if any row does not
// resolve to a definition, or violates the exactly-one-of-reps/seconds or
// sets >= 1 invariants — never silently drops a row.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vika/models/exercise_lookup.dart';

const _select = 'id,class_key,vietnamese_name,english_name,'
    'is_form_checked,base_reps,base_seconds,base_sets';
const _outputPath = 'assets/data/exercise_catalog.json';

Future<void> main() async {
  final env = _loadEnv();
  final url = env['SUPABASE_URL'];
  final key = env['SUPABASE_ANON_KEY'] ?? env['SUPABASE_KEY'];
  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    stderr.writeln('Missing SUPABASE_URL / SUPABASE_ANON_KEY (.env or env vars).');
    exit(1);
  }

  final uri = Uri.parse('$url/rest/v1/exercise_catalog?select=$_select&order=id');
  final resp = await http.get(uri, headers: {
    'apikey': key,
    'Authorization': 'Bearer $key',
  });
  if (resp.statusCode != 200) {
    stderr.writeln('Catalog fetch failed: HTTP ${resp.statusCode}\n${resp.body}');
    exit(1);
  }

  final rows = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  final entries = <Map<String, dynamic>>[];
  final unresolved = <String>[];

  for (final row in rows) {
    final id = row['id'] as String;
    final classKey = (row['class_key'] as String?)?.trim();
    final english = (row['english_name'] as String?)?.trim();
    final reps = (row['base_reps'] as num?)?.toInt();
    final seconds = (row['base_seconds'] as num?)?.toInt();
    final sets = (row['base_sets'] as num?)?.toInt() ?? 0;

    // Same resolution order as _lookupLaunchDefinition: id, then class_key,
    // then english_name. lookupExerciseDefinition handles the alias bridges
    // (vup→v__up, mcgill_curlup→curl_up, bow_pose→bow_, ...).
    final def = lookupExerciseDefinition(id) ??
        (classKey != null && classKey.isNotEmpty
            ? lookupExerciseDefinition(classKey)
            : null) ??
        (english != null && english.isNotEmpty
            ? lookupExerciseDefinition(english)
            : null);
    if (def == null) {
      unresolved.add(id);
      continue;
    }
    if ((reps == null) == (seconds == null)) {
      stderr.writeln('Row "$id": exactly one of base_reps/base_seconds required.');
      exit(1);
    }
    if (sets < 1) {
      stderr.writeln('Row "$id": base_sets must be >= 1 (got $sets).');
      exit(1);
    }

    entries.add({
      'catalogId': id,
      'definitionId': def.id,
      'classKey': classKey ?? id,
      'isFormChecked': row['is_form_checked'] == true,
      'sets': sets,
      'reps': reps,
      'seconds': seconds,
      'vietnameseName': row['vietnamese_name'],
      'englishName': english,
    });
  }

  if (unresolved.isNotEmpty) {
    stderr.writeln('Unresolved catalog ids (no matching ExerciseDefinition): '
        '${unresolved.join(', ')}');
    exit(1);
  }

  const encoder = JsonEncoder.withIndent('  ');
  File(_outputPath).writeAsStringSync('${encoder.convert(entries)}\n');
  stdout.writeln('Wrote ${entries.length} entries to $_outputPath');
}

/// Loads key=value pairs from the process environment, overlaid with `.env`.
Map<String, String> _loadEnv() {
  final result = <String, String>{...Platform.environment};
  final file = File('.env');
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final i = trimmed.indexOf('=');
      if (i <= 0) continue;
      final k = trimmed.substring(0, i).trim();
      var v = trimmed.substring(i + 1).trim();
      if (v.length >= 2 &&
          ((v.startsWith('"') && v.endsWith('"')) ||
              (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1);
      }
      result[k] = v;
    }
  }
  return result;
}
