import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/interpreter/intepreting_map.dart';

import '../screens/onboarding/onboarding_data.dart';
import 'issues_service.dart';

/// Persists v5 onboarding outputs on S16 completion.
///
/// Writes split across three tables:
///   profiles            — identity + plan inputs (single upsert)
///   user_pain_areas     — S04 painAreas + S09 candidate-derived regions,
///                         all source='self_reported'
///   user_detected_issues — camera detections from squat assessment
///                         (delegated to IssuesService)
///
/// All Supabase writes are best-effort; failures are logged and the
/// SharedPreferences flag set in `_complete()` is enough for the entry
/// gate to route to home. A failed sync retries on next launch.
class OnboardingPersistence {
  final _client = Supabase.instance.client;
  final _issues = IssuesService();

  Future<bool> persist(
    OnboardingData data, {
    bool markComplete = true,
    // S13 generates the plan early, then S16 marks onboarding complete.
    // Keep side-table writes one-shot so pain counts and fork audit rows do
    // not duplicate when both checkpoints run in the same onboarding session.
    bool writeSignals = true,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[OnboardingPersistence] no auth user, skipping persist');
      return false;
    }

    final ok = await _writeProfile(
      user.id,
      data,
      markComplete: markComplete,
    );

    if (!ok) return false;

    if (!writeSignals) return true;

    await _writePainAreas(user.id, data);
    await _writeForkDecision(user.id, data);

    // Camera-detected from squat assessment. Future interpreters
    // (push-up, warrior, fold) plug in here as they exist.
    final interpreter = data.squatInterpreterOrNull;
    if (interpreter != null) {
      await _issues.insertCameraDetectedIssues(
        userId: user.id,
        interpreter: interpreter,
        sessionId: null,
      );
    }

    return true;
  }

  // ─── profiles ─────────────────────────────────────────────────────

  Future<bool> _writeProfile(
    String userId,
    OnboardingData data, {
    required bool markComplete,
  }) async {
    final payload = <String, dynamic>{
      'id': userId,
      'onboarding_complete': markComplete,
      'gender': data.gender,
      'height_cm': data.heightCm,
      'weight_kg': data.weightKg,
      'age': data.age,
      'why_primary': data.whyStep1,
      'why_secondary': data.whyStep2,
      'intent_quote': data.whyCustomText.trim().isNotEmpty
          ? data.whyCustomText.trim()
          : null,
      'goals': data.goal != null ? [data.goal] : null,
      'training_duration': data.trainingDuration,
      'fork': data.fork,
      'fitness_level': data.level,
      'schedule_sessions':
          data.scheduleSessions.isNotEmpty ? data.scheduleSessions : null,
    };

    try {
      await _client.from('profiles').upsert(payload, onConflict: 'id');
      return true;
    } catch (e) {
      debugPrint('[OnboardingPersistence] profile upsert failed: $e');
      return false;
    }
  }

  // ─── user_pain_areas (S04 + S09) ──────────────────────────────────

  Future<void> _writePainAreas(String userId, OnboardingData data) async {
    // Count occurrences per body region across S04 + S09. The same region
    // flagged twice in one onboarding (e.g. S04 'lower_back' + S09
    // 'low_back_pain') counts as two flags — both are genuine user signals.
    final regionCounts = <String, int>{};
    final regionNotes = <String, String?>{};

    if (!data.noPain) {
      for (final region in data.painAreas) {
        regionCounts[region] = (regionCounts[region] ?? 0) + 1;
        if (region == 'other' &&
            (data.painOtherText?.trim().isNotEmpty ?? false)) {
          regionNotes[region] = data.painOtherText!.trim();
        }
      }
    }

    for (final picks in data.feedbackByExercise.values) {
      for (final candidateId in picks) {
        final def = interpretingMap[candidateId];
        if (def == null) continue; // 'none' or unknown candidate id
        regionCounts[def.bodyRegion] = (regionCounts[def.bodyRegion] ?? 0) + 1;
      }
    }

    if (regionCounts.isEmpty) return;

    try {
      final existing = await _client
          .from('user_pain_areas')
          .select('id, body_region, flag_count')
          .eq('user_id', userId)
          .eq('status', 'active');

      final existingByRegion = <String, Map<String, dynamic>>{
        for (final row in (existing as List))
          (row as Map<String, dynamic>)['body_region'] as String: row,
      };

      final now = DateTime.now().toIso8601String();
      final toInsert = <Map<String, dynamic>>[];

      for (final entry in regionCounts.entries) {
        final region = entry.key;
        final count = entry.value;
        final notes = regionNotes[region];

        if (existingByRegion.containsKey(region)) {
          // Reaffirm: increment flag_count by this onboarding's contribution.
          // Read-modify-write — not atomic, but onboarding is single-user
          // single-call so contention isn't a concern.
          final row = existingByRegion[region]!;
          final newCount = ((row['flag_count'] as int?) ?? 1) + count;
          await _client.from('user_pain_areas').update({
            'last_reaffirmed_at': now,
            'flag_count': newCount,
          }).eq('id', row['id']);
        } else {
          toInsert.add({
            'user_id': userId,
            'body_region': region,
            'source': 'self_reported',
            'status': 'active',
            'first_flagged_at': now,
            'last_reaffirmed_at': now,
            'flag_count': count, // not 1 — could be 2+ from S04+S09 merge
            if (notes != null) 'notes': notes,
          });
        }
      }

      if (toInsert.isNotEmpty) {
        await _client.from('user_pain_areas').insert(toInsert);
      }
    } catch (e) {
      debugPrint('[OnboardingPersistence] pain areas write failed: $e');
    }
  }

  Future<void> _writeForkDecision(String userId, OnboardingData data) async {
    final rec = data.forkRec;
    if (rec == null || data.fork == null) {
      debugPrint('[OnboardingPersistence] no forkRec, skipping fork_decisions');
      return;
    }

    try {
      await _client.from('fork_decisions').insert({
        'user_id': userId,
        'fork_recommended': rec.fork,
        'fork_chosen': data.fork,
        'raw_score': rec.rawScore,
        'confidence': rec.confidence,
        'dominant_signal': rec.dominantSignal,
        'reason_text': rec.reason,
        'contribution_goal': rec.signalContributions['goal'],
        'contribution_pain': rec.signalContributions['pain'],
        'contribution_why': rec.signalContributions['why'],
        'contribution_duration': rec.signalContributions['duration'],
        'algorithm_version': 'v1.0',
      });
    } catch (e) {
      debugPrint('[OnboardingPersistence] fork_decision insert failed: $e');
    }
  }
}
