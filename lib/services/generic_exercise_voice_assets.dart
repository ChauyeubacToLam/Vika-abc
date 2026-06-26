class GenericExerciseVoiceAssets {
  static const String assetSourcePrefix = 'audio';
  static const String assetBundlePrefix = 'assets/audio';

  static const Map<String, String> commonFiles = {
    'common.ngang_intro': 'common/ngang_intro.mp3',
    'common.thang_intro': 'common/th\u1eb3ng_intro.mp3',
    'common.ready': 'common/ready.mp3',
    'common.start': 'common/start.mp3',
    'common.keep_full_body': 'common/keep_full_body.mp3',
    'common.hold_still': 'common/hold_still.mp3',
    'common.no_count': 'common/no_count.mp3',
    'common.fix_pose': 'common/fix_form.mp3',
    'common.correct': 'common/correct.mp3',
    'common.rest': 'common/rest.mp3',
    'common.set_complete': 'common/set_complete.mp3',
    'common.exercise_complete': 'common/exercise_complete.mp3',
    'common.next_set': 'common/next_set.mp3',
    'common.good_1': 'common/good_1.mp3',
    'common.good_2': 'common/good_2.mp3',
    'common.good_3': 'common/good_3.mp3',
    'common.good_4': 'common/good_4.mp3',
    '1': 'common/count_1.mp3',
    '2': 'common/count_2.mp3',
    '3': 'common/count_3.mp3',
    '4': 'common/count_4.mp3',
    '5': 'common/count_5.mp3',
    '6': 'common/count_6.mp3',
    '7': 'common/count_7.mp3',
    '8': 'common/count_8.mp3',
    '9': 'common/count_9.mp3',
    '10': 'common/count_10.mp3',
    '11': 'common/count_11.mp3',
    '12': 'common/count_12.mp3',
    '13': 'common/count_13.mp3',
    '14': 'common/count_14.mp3',
    '15': 'common/count_15.mp3',
    '16': '16.mp3',
    '17': '17.mp3',
    '18': '18.mp3',
    '19': '19.mp3',
    '20': '20.mp3',
    '21': '21.mp3',
    '22': '22.mp3',
    '23': '23.mp3',
    '24': '24.mp3',
    '25': '25.mp3',
    '26': '26.mp3',
    '27': '27.mp3',
    '28': '28.mp3',
    '29': '29.mp3',
    '30': '30.mp3',
  };

  static const Map<String, GenericExerciseVoiceScript> scriptsByExerciseName = {
    'Squat': GenericExerciseVoiceScript(
      slug: 'squat',
      setupIntroCueId: 'common.thang_intro',
      faultIds: ['heel', 'depth', 'trunk', 'tempo', 'sync'],
    ),
    'Plank': GenericExerciseVoiceScript(
      slug: 'plank',
      cleanCueId: 'hold_good',
      faultIds: ['trunk_sag', 'trunk_pike', 'neck', 'knee'],
    ),
    'Lunge': GenericExerciseVoiceScript(
      slug: 'lunge',
      faultIds: ['depth', 'too_deep', 'heel', 'trunk', 'lumbar'],
    ),
    'Nhảy Dạng': GenericExerciseVoiceScript(
      slug: 'jumping_jack',
      faultIds: ['arms', 'legs', 'tempo_fast', 'tempo_slow'],
    ),
    'Jumping Jack': GenericExerciseVoiceScript(
      slug: 'jumping_jack',
      setupIntroCueId: 'common.thang_intro',
      faultIds: ['arms', 'legs', 'tempo_fast', 'tempo_slow'],
    ),
    'Push Up': GenericExerciseVoiceScript(
      slug: 'push_up',
      faultIds: ['depth', 'tempo', 'sag', 'pike', 'setup_guard'],
    ),
    'Glute Bridge': GenericExerciseVoiceScript(
      slug: 'glute_bridge',
      faultIds: ['hip_extension', 'lumbar', 'knee_angle', 'neck', 'speed'],
    ),
    'McGill Curl-up': GenericExerciseVoiceScript(
      slug: 'curl_up',
      faultIds: ['knee_extension', 'neck_pull', 'trunk_high', 'trunk_low'],
    ),
    'Warrior I': GenericExerciseVoiceScript(
      slug: 'warrior_one',
      cleanCueId: 'hold_good',
      faultIds: ['trunk', 'cervical', 'arms', 'back_knee', 'back_straight'],
    ),
    'Bird Dog': GenericExerciseVoiceScript(
      slug: 'bird_dog',
      faultIds: [
        'opposite_side',
        'alternate',
        'alignment',
        'head',
        'lumbar',
        'hold',
        'trunk',
      ],
    ),
    'V-Up': GenericExerciseVoiceScript(
      slug: 'v_up',
      faultIds: ['sync', 'rom', 'jerking', 'knee', 'tempo'],
    ),
    'Dead Bug': GenericExerciseVoiceScript(
      slug: 'dead_bug',
      faultIds: [
        'opposite_side',
        'alternate',
        'anti_extension',
        'stable_limbs',
        'floor_contact',
        'tempo',
      ],
    ),
    'Plank Up-Down': GenericExerciseVoiceScript(
      slug: 'plank_up_down',
      faultIds: [
        'alternating',
        'arm_extension',
        'hip_rotation',
        'trunk',
        'knee'
      ],
    ),
    'Bear Plank': GenericExerciseVoiceScript(
      slug: 'bear_plank',
      cleanCueId: 'hold_good',
      faultIds: ['knee_hover', 'hip_high', 'back_sag', 'back_arch', 'weight'],
    ),
    'Sit Up': GenericExerciseVoiceScript(
      slug: 'sit_up',
      faultIds: ['jerking', 'rom', 'stability', 'tempo'],
    ),
    'High Plank': GenericExerciseVoiceScript(
      slug: 'high_plank',
      cleanCueId: 'hold_good',
      faultIds: ['sagging', 'piked', 'elbow', 'wall_guard'],
    ),
    'Mountain Climber': GenericExerciseVoiceScript(
      slug: 'mountain_climber',
      faultIds: ['double_knee', 'rom', 'trunk_sag', 'trunk_bounce'],
    ),
    'Superman': GenericExerciseVoiceScript(
      slug: 'superman',
      faultIds: ['elevation_arm', 'elevation_leg', 'hip', 'hold', 'lumbar'],
    ),
    'Plank Shoulder Tap': GenericExerciseVoiceScript(
      slug: 'plank_shoulder_tap',
      faultIds: ['tap', 'hip_rotation', 'tempo', 'trunk'],
    ),
    'Leg Raises': GenericExerciseVoiceScript(
      slug: 'leg_raises',
      faultIds: ['pelvic', 'rom', 'knee', 'tempo', 'arms'],
    ),
    'Reverse Crunch': GenericExerciseVoiceScript(
      slug: 'reverse_crunch',
      faultIds: ['curl', 'momentum', 'tempo', 'arms'],
    ),
    'Bow Pose': GenericExerciseVoiceScript(
      slug: 'bow_pose',
      cleanCueId: 'hold_good',
      faultIds: ['connection', 'hold', 'stability', 'chest', 'thigh'],
    ),
    'Butterfly Stretch': GenericExerciseVoiceScript(
      slug: 'butterfly_stretch',
      setupIntroCueId: 'common.thang_intro',
      cleanCueId: 'hold_good',
      faultIds: ['foot', 'knee', 'posture', 'shoulder'],
    ),
    'Cobra Pose': GenericExerciseVoiceScript(
      slug: 'cobra',
      cleanCueId: 'hold_good',
      faultIds: ['neck', 'descent', 'elbow', 'hip', 'hand', 'stability'],
    ),
    'Cossack Squat': GenericExerciseVoiceScript(
      slug: 'cossack_squat',
      setupIntroCueId: 'common.thang_intro',
      faultIds: [
        'heel',
        'knee_valgus',
        'straight_leg',
        'torso',
        'depth_deep',
        'depth_shallow',
      ],
    ),
    'Jump Squat': GenericExerciseVoiceScript(
      slug: 'jump_squat',
      setupIntroCueId: 'common.thang_intro',
      faultIds: [
        'too_fast',
        'landing_stiff',
        'landing_depth',
        'trunk',
        'takeoff_depth',
      ],
    ),
    'Russian Twist': GenericExerciseVoiceScript(
      slug: 'russian_twist',
      setupIntroCueId: 'common.thang_intro',
      faultIds: ['knee', 'too_upright', 'too_low', 'spine', 'thoracic', 'rom'],
    ),
    'Seated Forward Fold': GenericExerciseVoiceScript(
      slug: 'seated_forward_fold',
      cleanCueId: 'hold_good',
      faultIds: ['ankle', 'knee', 'spine', 'tempo'],
    ),
    'Side Plank with Hip Dip': GenericExerciseVoiceScript(
      slug: 'side_plank_dip',
      setupIntroCueId: 'common.thang_intro',
      faultIds: ['shoulder', 'rotation', 'amplitude'],
    ),
    'Sphinx Pose': GenericExerciseVoiceScript(
      slug: 'sphinx',
      cleanCueId: 'hold_good',
      faultIds: [
        'hip',
        'straight_arm',
        'forearm',
        'upper_arm',
        'shrug',
        'neck'
      ],
    ),
    'Standing Knee-to-Elbow': GenericExerciseVoiceScript(
      slug: 'standing_kte',
      setupIntroCueId: 'common.thang_intro',
      faultIds: [
        'core_drive',
        'cross_rom',
        'knee_valgus',
        'pelvic_drop',
        'setup'
      ],
    ),
    'Step-Back Burpee': GenericExerciseVoiceScript(
      slug: 'step_back_burpee',
      setupIntroCueId: 'common.thang_intro',
      faultIds: ['squat_hinge', 'squat_depth', 'plank_sag', 'plank_extension'],
    ),
    'Tricep Dip (Floor)': GenericExerciseVoiceScript(
      slug: 'tricep_dip',
      faultIds: ['extension', 'hip_thrust', 'shrug', 'rom', 'setup'],
    ),
    'Walking Lunge': GenericExerciseVoiceScript(
      slug: 'walking_lunge',
      setupIntroCueId: 'common.thang_intro',
      faultIds: [
        'front_knee',
        'rear_depth',
        'step_length',
        'torso',
        'hold',
        'framing'
      ],
    ),
    'Surya Namaskar': GenericExerciseVoiceScript(
      slug: 'surya_namaskar',
      cleanCueId: 'common.good_2',
      faultIds: ['pose_wait', 'safety', 'sequence', 'breath'],
    ),
    'Wall Push Up': GenericExerciseVoiceScript(
      slug: 'wall_push_up',
      faultIds: [
        'body_line',
        'cervical',
        'elbow',
        'foot',
        'heel',
        'head',
        'shoulder',
        'hand',
        'tempo',
        'setup',
      ],
    ),
    'Downward Dog': GenericExerciseVoiceScript(
      slug: 'downward_dog',
      cleanCueId: 'hold_good',
      faultIds: ['spine', 'shoulder', 'leg', 'hip'],
    ),
    'Ashtanga Namaskara': GenericExerciseVoiceScript(
      slug: 'ashtanga_namaskara',
      faultIds: ['knees', 'chest', 'hip', 'neck', 'count_guard'],
    ),
    'Low Lunge': GenericExerciseVoiceScript(
      slug: 'low_lunge',
      cleanCueId: 'hold_good',
      faultIds: ['back_knee', 'depth', 'chest', 'cervical', 'knee_travel'],
    ),
    'Prayer Pose': GenericExerciseVoiceScript(
      slug: 'prayer_pose',
      cleanCueId: 'hold_good',
      faultIds: ['posture', 'shoulder', 'drift'],
    ),
    'Raised Arms Pose': GenericExerciseVoiceScript(
      slug: 'raised_arms',
      cleanCueId: 'hold_good',
      faultIds: ['arms', 'cervical', 'lumbar', 'stability'],
    ),
    'Raised Arms': GenericExerciseVoiceScript(
      slug: 'raised_arms',
      cleanCueId: 'hold_good',
      faultIds: ['arms', 'cervical', 'lumbar', 'stability'],
    ),
  };

  static GenericExerciseVoiceScript scriptForExerciseName(String exerciseName) {
    return scriptsByExerciseName[exerciseName] ??
        GenericExerciseVoiceScript(slug: _fallbackSlug(exerciseName));
  }

  static String setupIntroKeyForExerciseName(String exerciseName) {
    final script = scriptForExerciseName(exerciseName);
    if (script.slug == 'jumping_jack') return 'common.thang_intro';
    return script.setupIntroKey;
  }

  static String? resolveAsset(String key) {
    final value = key.trim();
    if (value.isEmpty || value.startsWith('common.')) return null;

    final dotIndex = value.indexOf('.');
    if (dotIndex <= 0 || dotIndex >= value.length - 1) return null;

    final slug = value.substring(0, dotIndex);
    final id = value.substring(dotIndex + 1);
    final dir = _assetDirectoryForSlug(slug);
    final specialCue = _specialCueFilename('$slug.$id');
    if (specialCue != null) {
      return '$dir/$specialCue';
    }

    if (id == 'setup_position' ||
        id == 'active_intro' ||
        id == 'good_clean' ||
        id == 'hold_good' ||
        id == 'set_next_setup') {
      final filename =
          _usesPlainCueFilenames(slug) ? '$id.mp3' : '$slug.$id.mp3';
      return '$dir/$filename';
    }

    if (id.startsWith('set_next_')) return '$dir/$id.mp3';
    return '$dir/$id.mp3';
  }

  static String _assetDirectoryForSlug(String slug) {
    if (slug == 'curl_up') return 'mc_gill_curl_up';
    return slug;
  }

  static bool _usesPlainCueFilenames(String slug) {
    const plainCueSlugs = {
      'cobra',
      'cossack_squat',
      'jump_squat',
      'russian_twist',
      'seated_forward_fold',
      'side_plank_dip',
      'sphinx',
      'standing_kte',
      'step_back_burpee',
      'tricep_dip',
      'walking_lunge',
    };
    return plainCueSlugs.contains(slug);
  }

  static String? _specialCueFilename(String key) {
    const specialCueFiles = {
      'jump_squat.setup_position': 'set_up position.mp3',
      'seated_forward_fold.setup_position': 'set_up position.mp3',
    };
    return specialCueFiles[key];
  }

  static String _fallbackSlug(String value) {
    final buffer = StringBuffer();
    var lastWasUnderscore = false;
    for (final codeUnit in value.toLowerCase().codeUnits) {
      final isAsciiLetter = codeUnit >= 97 && codeUnit <= 122;
      final isAsciiDigit = codeUnit >= 48 && codeUnit <= 57;
      if (isAsciiLetter || isAsciiDigit) {
        buffer.writeCharCode(codeUnit);
        lastWasUnderscore = false;
      } else if (!lastWasUnderscore) {
        buffer.write('_');
        lastWasUnderscore = true;
      }
    }
    return buffer.toString().replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class GenericExerciseVoiceScript {
  const GenericExerciseVoiceScript({
    required this.slug,
    this.setupIntroCueId = 'common.ngang_intro',
    this.cleanCueId = 'good_clean',
    this.faultIds = const [],
  });

  final String slug;
  final String setupIntroCueId;
  final String cleanCueId;
  final List<String> faultIds;

  String get setupIntroKey {
    if (slug == 'jumping_jack') return 'common.thang_intro';
    return cueKey(setupIntroCueId);
  }

  String cueKey(String id) {
    if (id.startsWith('common.')) return id;
    return '$slug.$id';
  }

  String faultKey(String faultId) => '$slug.$faultId';
  String setNextFaultKey(String faultId) => '$slug.set_next_$faultId';

  bool hasFault(String faultId) => faultIds.contains(faultId);
}
