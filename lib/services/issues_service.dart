import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/interpreter/intepreting_map.dart';
import 'package:vika/interpreter/interpreter_base.dart';

/// Reads + writes for `user_detected_issues`, the camera-detection
/// pipeline log. Also handles the cross-table write into
/// `user_pain_areas` when a user confirms a popup.
///
/// Three flows:
///   1. insertCameraDetectedIssues — interpreter emitted, status='queued'
///   2. respondToIssue             — user answered the popup
///   3. getQueuedIssues            — UI reads what to ask
///
/// S04 and S09 self-reports do NOT go through this service. They go
/// straight to `user_pain_areas` via `OnboardingPersistence`.
class IssuesService {
  final _client = Supabase.instance.client;

  // ─── 1. Camera-detected (interpreter → DB) ────────────────────────

  /// Inserts one queued row per evidence the interpreter produced.
  /// Pulls `exerciseSource` off each evidence so this works for any
  /// future interpreter (plank, push-up, warrior...) without changes.
  Future<void> insertCameraDetectedIssues({
    required String userId,
    required InterpreterBase interpreter,
    String? sessionId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rows = <Map<String, dynamic>>[];

    for (final bucket in interpreter.evidences) {
      for (final evidence in bucket) {
        final def = interpretingMap[evidence.issueId];
        if (def == null) continue; // unknown id, interpreter/map drift
        rows.add({
          'user_id': userId,
          'session_id': sessionId, // null on onboarding
          'exercise_id': evidence.exerciseSource,
          'issue_id': evidence.issueId,
          'body_region': def.bodyRegion,
          'priority': def.priority,
          'source': 'camera',
          'status': 'queued',
          'confidence': evidence.confidence,
          'trigger_reason': evidence.rawSignal,
          'detected_at': now,
        });
      }
    }

    if (rows.isEmpty) return;
    try {
      await _client.from('user_detected_issues').insert(rows);
    } catch (e) {
      debugPrint('[IssuesService] camera insert failed: $e');
    }
  }

  // ─── 2. User responds to popup ────────────────────────────────────

  /// Updates a queued row when the user answers the "did you feel X?"
  /// popup. If `confirmed=true`, also reflects the pain into
  /// `user_pain_areas` (insert new active row or reaffirm existing).
  ///
  /// `userId` and `bodyRegion` are required so we skip a round-trip
  /// to re-read the detected row — the UI already has them from
  /// `getQueuedIssues`.
  Future<void> respondToIssue({
    required String issueRowId,
    required String userId,
    required String bodyRegion,
    required bool confirmed,
    int? severity,
    bool? aggravatedByExercise,
  }) async {
    final now = DateTime.now().toIso8601String();

    // Step 1: update the detected row. Never delete.
    try {
      await _client.from('user_detected_issues').update({
        'status': confirmed ? 'confirmed' : 'declined',
        'response': confirmed ? 'yes' : 'no',
        'asked_at': now,
        if (severity != null) 'reported_severity': severity,
        if (aggravatedByExercise != null)
          'aggravated_by_exercise': aggravatedByExercise,
      }).eq('id', issueRowId);
    } catch (e) {
      debugPrint('[IssuesService] respondToIssue update failed: $e');
      return;
    }

    if (!confirmed) return;

    // Step 2: reflect into user_pain_areas. Reaffirm existing active
    // row for the region (upgrading source from 'self_reported' to
    // 'confirmed' when camera + user now agree), otherwise insert new.
    try {
      final existing = await _client
    .from('user_pain_areas')
    .select('id, source, flag_count')   
    .eq('user_id', userId)
    .eq('body_region', bodyRegion)
    .eq('status', 'active')
    .maybeSingle();

if (existing != null) {
  final updates = <String, dynamic>{
    'last_reaffirmed_at': now,
    'flag_count': ((existing as Map)['flag_count'] as int? ?? 1) + 1,
  };
  if (existing['source'] == 'self_reported') {
    updates['source'] = 'confirmed';
  }
  await _client
      .from('user_pain_areas')
      .update(updates)
      .eq('id', existing['id']);
}
    } catch (e) {
      debugPrint(
          '[IssuesService] respondToIssue pain area write failed: $e');
    }
  }

  // ─── 3. Read helper ───────────────────────────────────────────────

  /// Returns queued rows for a user, optionally filtered by exercise.
  /// Used by the in-session UI to surface "did you feel this?" prompts.
  Future<List<Map<String, dynamic>>> getQueuedIssues({
    required String userId,
    String? exerciseId,
  }) async {
    try {
      var query = _client
          .from('user_detected_issues')
          .select()
          .eq('user_id', userId)
          .eq('status', 'queued');
      if (exerciseId != null) {
        query = query.eq('exercise_id', exerciseId);
      }
      final result = await query;
      return List<Map<String, dynamic>>.from(result as List);
    } catch (e) {
      debugPrint('[IssuesService] getQueuedIssues failed: $e');
      return const [];
    }
  }
}