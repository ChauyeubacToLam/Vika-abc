import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_persistence.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.displayName,
    required this.initial,
    required this.streakDays,
    this.email,
    this.avatarUrl,
    this.createdAt,
    this.lastWorkoutAt,
    this.heightCm,
    this.weightKg,
    this.age,
    this.fitnessLevel,
    this.goal,
  });

  final String id;
  final String displayName;
  final String initial;
  final String? email;
  final String? avatarUrl;
  final int streakDays;
  final DateTime? createdAt;
  final DateTime? lastWorkoutAt;
  final int? heightCm;
  final int? weightKg;
  final int? age;
  final String? fitnessLevel;
  final String? goal;

  String get memberSinceLabel {
    final date = createdAt;
    if (date == null) return 'ngày đầu';
    return '${date.day}/${date.month}/${date.year}';
  }

  String get bmiLabel {
    final bmi = bmiValue;
    if (bmi == null) return '--';
    return bmi.toStringAsFixed(1);
  }

  double? get bmiValue {
    final height = heightCm;
    final weight = weightKg;
    if (height == null || weight == null || height <= 0 || weight <= 0) {
      return null;
    }
    final meters = height / 100;
    return weight / (meters * meters);
  }

  String get bmiCategory {
    final bmi = bmiValue;
    if (bmi == null) return 'Chưa đủ dữ liệu';
    if (bmi < 18.5) return 'Hơi nhẹ';
    if (bmi < 23) return 'Cân đối';
    if (bmi < 25) return 'Hơi cao';
    return 'Cần theo dõi';
  }

  AppUserProfile copyWith({
    String? displayName,
    String? initial,
    String? email,
    String? avatarUrl,
    int? streakDays,
    DateTime? createdAt,
    DateTime? lastWorkoutAt,
    int? heightCm,
    int? weightKg,
    int? age,
    String? fitnessLevel,
    String? goal,
  }) {
    return AppUserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      initial: initial ?? this.initial,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      streakDays: streakDays ?? this.streakDays,
      createdAt: createdAt ?? this.createdAt,
      lastWorkoutAt: lastWorkoutAt ?? this.lastWorkoutAt,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      goal: goal ?? this.goal,
    );
  }
}

class UserProfileService {
  UserProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const avatarBucket = 'avatars';

  Future<AppUserProfile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final oauthName = _firstString([
      metadata['display_name'],
      metadata['full_name'],
      metadata['name'],
      user.email,
    ]);
    final oauthAvatar = _firstString([
      metadata['avatar_url'],
      metadata['picture'],
    ]);

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select(
            'id, display_name, avatar_url, created_at, updated_at, '
            'last_workout_at, height_cm, weight_kg, age, fitness_level, goals',
          )
          .eq('id', user.id)
          .maybeSingle();
    } catch (e) {
      debugPrint('[UserProfileService] profile fetch failed: $e');
    }

    final displayName =
        _firstString([row?['display_name'], oauthName]) ?? 'Bạn';
    final avatarUrl = _firstString([row?['avatar_url'], oauthAvatar]);
    final goalsList = (row?['goals'] as List?)?.cast<String>();
    final streakDays =
        await SessionPersistence(client: _client).currentStreak();
    final profile = AppUserProfile(
      id: user.id,
      displayName: displayName,
      initial: _initialFor(displayName),
      email: user.email,
      avatarUrl: avatarUrl,
      streakDays: streakDays,
      createdAt: _dateTimeOrNull(row?['created_at']) ??
          _dateTimeOrNull(user.createdAt),
      lastWorkoutAt: _dateTimeOrNull(row?['last_workout_at']),
      heightCm: (row?['height_cm'] as num?)?.round(),
      weightKg: (row?['weight_kg'] as num?)?.round(),
      age: (row?['age'] as num?)?.toInt(),
      fitnessLevel: row?['fitness_level'] as String?,
      goal: (goalsList != null && goalsList.isNotEmpty) ? goalsList.first : null,
    );

    await _syncProfileIdentityIfNeeded(
      userId: user.id,
      row: row,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    return profile;
  }

  /// Saves display name + avatar, and optionally requests an auth email
  /// change. [email] should be non-null only when it actually differs from
  /// the current address; Supabase then sends a confirmation link and the
  /// new address only takes effect once the user confirms it.
  Future<AppUserProfile?> saveCurrentProfile({
    required String displayName,
    File? avatarFile,
    String? email,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final cleanName = displayName.trim().isEmpty ? 'Bạn' : displayName.trim();
    final cleanEmail = email?.trim();
    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _uploadAvatar(user.id, avatarFile);
    }

    final payload = <String, dynamic>{
      'id': user.id,
      'display_name': cleanName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    await _client.from('profiles').upsert(payload, onConflict: 'id');
    await _client.auth.updateUser(
      UserAttributes(
        email: (cleanEmail != null && cleanEmail.isNotEmpty) ? cleanEmail : null,
        data: {
          'display_name': cleanName,
          'full_name': cleanName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (avatarUrl != null) 'picture': avatarUrl,
        },
      ),
    );
    return fetchCurrentProfile();
  }

  /// Updates a subset of plan-input fields on `profiles` (body stats + goal)
  /// from the Profile tab editors. Only non-null fields are written; the goal
  /// is stored as a single-element `goals` array to match onboarding. Returns
  /// the refreshed profile.
  Future<AppUserProfile?> updateProfileFields({
    int? heightCm,
    int? weightKg,
    int? age,
    String? goal,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final payload = <String, dynamic>{
      'id': user.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (age != null) 'age': age,
      if (goal != null) 'goals': [goal],
    };

    await _client.from('profiles').upsert(payload, onConflict: 'id');
    return fetchCurrentProfile();
  }

  /// Raw `profiles.gender` for the current user ('male' / 'female' / 'other'),
  /// or null when signed out, absent, or on error. Callers decide how to map
  /// it (e.g. the Progress pain reporter defaults anything non-'female' to the
  /// male silhouette).
  Future<String?> fetchGender() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('gender')
          .eq('id', user.id)
          .maybeSingle();
      return row?['gender'] as String?;
    } catch (e) {
      debugPrint('[UserProfileService] gender fetch failed: $e');
      return null;
    }
  }

  Future<String> _uploadAvatar(String userId, File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    final safeExtension = switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => extension,
      _ => 'jpg',
    };
    final contentType = switch (safeExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    await _client.storage.from(avatarBucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    return _client.storage.from(avatarBucket).getPublicUrl(path);
  }

  Future<void> _syncProfileIdentityIfNeeded({
    required String userId,
    required Map<String, dynamic>? row,
    required String displayName,
    required String? avatarUrl,
  }) async {
    if (row != null &&
        _firstString([row['display_name']]) != null &&
        (avatarUrl == null || _firstString([row['avatar_url']]) != null)) {
      return;
    }

    try {
      await _client.from('profiles').upsert(
        {
          'id': userId,
          'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );
    } catch (e) {
      debugPrint('[UserProfileService] identity sync failed: $e');
    }
  }
}

String? _firstString(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is! String) continue;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _initialFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'V';
  return trimmed[0].toUpperCase();
}

DateTime? _dateTimeOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return DateTime.tryParse(value.toString());
}
