import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gathers the signed-in user's own data into a single JSON document for the
/// "Tải dữ liệu của bạn" (data export) flow.
///
/// Read-only. Each table is scoped to the current user (`profiles` by `id`,
/// everything else by `user_id`). A failure on any single table is recorded
/// under that table's key instead of aborting the whole export, so the user
/// still gets whatever could be read.
class DataExportService {
  DataExportService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Builds a pretty-printed JSON string of the user's data, or null if no
  /// user is signed in.
  Future<String?> buildExportJson() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final export = <String, dynamic>{
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'user': {
        'id': user.id,
        'email': user.email,
      },
      'profile': await _fetchOne('profiles', column: 'id', value: user.id),
      'workout_sessions': await _fetchMany('workout_sessions', user.id),
      'exercise_sessions': await _fetchMany('exercise_sessions', user.id),
      'user_pain_areas': await _fetchMany('user_pain_areas', user.id),
      'fitness_retests': await _fetchMany('fitness_retests', user.id),
      'recommendations_log': await _fetchMany('recommendations_log', user.id),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(export);
  }

  Future<dynamic> _fetchOne(
    String table, {
    required String column,
    required String value,
  }) async {
    try {
      return await _client.from(table).select().eq(column, value).maybeSingle();
    } catch (e) {
      debugPrint('[DataExportService] $table fetch failed: $e');
      return {'_error': 'không tải được'};
    }
  }

  Future<dynamic> _fetchMany(String table, String userId) async {
    try {
      return await _client.from(table).select().eq('user_id', userId);
    } catch (e) {
      debugPrint('[DataExportService] $table fetch failed: $e');
      return {'_error': 'không tải được'};
    }
  }
}
