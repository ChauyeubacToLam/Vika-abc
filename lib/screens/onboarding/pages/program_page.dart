import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vika/interpreter/intepreting_map.dart';
import 'package:vika/widgets/pose_silhouette.dart';
import 'package:vika/widgets/vf_primitives.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

const _proPurple = Color(0xFFCBB8F0);
const _tileDark = Color(0xFF101512);

class ProgramPage extends StatefulWidget {
  const ProgramPage({
    super.key,
    required this.data,
    required this.onComplete,
  });

  final OnboardingData data;
  final VoidCallback onComplete;

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _dayDates = [14, 15, 16, 17, 18, 19, 20];
  static const _weekTiles = [
    (number: '1', title: 'Học form', sessions: 0),
    (number: '2', title: 'Tăng rep', sessions: 0),
    (number: '3', title: 'Sức mạnh', sessions: 1),
    (number: '4', title: 'Đánh giá lại', sessions: 0),
  ];

  static const _goalExercisePatterns = <String, List<List<String>>>{
    'health': [
      ['squat', 'plank', 'glute_bridge', 'bird_dog'],
      ['lunge', 'bird_dog', 'plank', 'squat'],
      ['squat', 'glute_bridge', 'bird_dog', 'plank'],
    ],
    'body': [
      ['squat', 'lunge', 'plank', 'glute_bridge'],
      ['glute_bridge', 'mcgill_curl_up', 'jumping_jack', 'squat'],
      ['squat', 'plank', 'lunge', 'glute_bridge'],
    ],
    'strength': [
      ['squat', 'glute_bridge', 'plank', 'push_up'],
      ['push_up', 'plank', 'mcgill_curl_up', 'squat'],
      ['squat', 'glute_bridge', 'plank', 'push_up'],
    ],
    'flexible': [
      ['squat', 'bird_dog', 'cat_cow', 'plank'],
      ['glute_bridge', 'plank', 'bird_dog', 'cat_cow'],
      ['squat', 'cat_cow', 'plank', 'bird_dog'],
    ],
  };

  static const _exerciseRegistry = <String, _ExerciseData>{
    'squat': _ExerciseData(name: 'Squat', sets: '3×8', pose: 'squat'),
    'plank': _ExerciseData(name: 'Plank', sets: '3×20s', pose: 'plank'),
    'glute_bridge':
        _ExerciseData(name: 'Glute Bridge', sets: '3×10', pose: 'bridge'),
    'lunge': _ExerciseData(name: 'Lunge', sets: '3×8', pose: 'lunge'),
    'bird_dog': _ExerciseData(name: 'Bird Dog', sets: '3×8', pose: 'birddog'),
    'mcgill_curl_up':
        _ExerciseData(name: 'McGill Curl-up', sets: '3×8', pose: 'curlup'),
    'jumping_jack':
        _ExerciseData(name: 'Jumping Jack', sets: '3×15', pose: 'jump'),
    'push_up': _ExerciseData(name: 'Push-up', sets: '3×6', pose: 'pushup'),
    'cat_cow': _ExerciseData(name: 'Cat-Cow', sets: '3×8', pose: 'catcow'),
  };

  static const _correctiveRegistry = <String, _ExerciseData>{
    'wall_calf_stretch': _ExerciseData(
      name: 'Wall Calf Stretch',
      sets: '30s ×3',
      pose: 'stretch',
      isCorrective: true,
    ),
    'kneeling_hip_flexor_stretch': _ExerciseData(
      name: 'Kneeling Hip Flexor Stretch',
      sets: '30s ×3',
      pose: 'stretch',
      isCorrective: true,
    ),
    'floor_glute_bridge': _ExerciseData(
      name: 'Floor Glute Bridge',
      sets: '3×10',
      pose: 'bridge',
      isCorrective: true,
    ),
    'wall_squat': _ExerciseData(
      name: 'Wall Squat',
      sets: '20s ×3',
      pose: 'squat',
      isCorrective: true,
    ),
    'bird_dog': _ExerciseData(
      name: 'Bird Dog',
      sets: '3×8',
      pose: 'birddog',
      isCorrective: true,
    ),
    'hip_flexor_stretch': _ExerciseData(
      name: 'Hip Flexor Stretch',
      sets: '30s ×3',
      pose: 'stretch',
      isCorrective: true,
    ),
    'bodyweight_squat_to_box': _ExerciseData(
      name: 'Squat ghế',
      sets: '3×8',
      pose: 'squat',
      isCorrective: true,
    ),
    'seated_toe_raise': _ExerciseData(
      name: 'Nâng mũi chân',
      sets: '3×15',
      pose: 'stretch',
      isCorrective: true,
    ),
  };

  static const _exerciseMuscles = <String, List<String>>{
    'Squat': ['Đùi', 'Mông', 'Core'],
    'Lunge': ['Đùi', 'Mông', 'Hông'],
    'Glute Bridge': ['Mông', 'Hông', 'Core'],
    'Plank': ['Core', 'Vai', 'Thân trên'],
    'Push-up': ['Ngực', 'Vai', 'Core'],
    'Bird Dog': ['Core', 'Lưng', 'Hông'],
    'McGill Curl-up': ['Core', 'Bụng'],
    'Jumping Jack': ['Cardio', 'Toàn thân'],
    'Cat-Cow': ['Cột sống', 'Core'],
  };

  // TODO: Replace with real subscription check
  bool _isPro = false;

  late final List<_WorkoutData> _workouts;
  int _selectedWorkoutDay = 0;

  @override
  void initState() {
    super.initState();
    _workouts = _buildWorkouts();
    _loadProState();
  }

  Future<void> _loadProState() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool('user_is_pro') ?? false;
    if (!mounted) return;
    setState(() => _isPro = isPro);
  }

  List<int> get _workoutDays {
    final days = widget.data.workoutDays.isEmpty
        ? [0, 2, 4]
        : List<int>.from(widget.data.workoutDays)
      ..sort();
    return days;
  }

  String get _levelLabel {
    switch (widget.data.confirmedLevel ?? 'beginner') {
      case 'advanced':
        return 'Advanced';
      case 'intermediate':
        return 'Intermediate';
      default:
        return 'Beginner';
    }
  }

  String _goalKey(String? goal) {
    switch (goal) {
      case 'health':
      case 'Sức khỏe':
        return 'health';
      case 'body':
      case 'shape':
      case 'Vóc dáng':
        return 'body';
      case 'strength':
      case 'Sức mạnh':
        return 'strength';
      case 'flexible':
      case 'flexibility':
      case 'Linh hoạt':
        return 'flexible';
      default:
        return 'health';
    }
  }

  String? _getTopIssue() {
    if (widget.data.detectedIssues.isNotEmpty) {
      return widget.data.detectedIssues.first;
    }
    try {
      return widget.data.squatInterpreter.getPrimaryIssueId();
    } catch (_) {
      return null;
    }
  }

  String _bodyRegionLabel([String? bodyRegion]) {
    final issueId = _getTopIssue();
    final region = bodyRegion?.isNotEmpty == true
        ? bodyRegion!
        : interpretingMap[issueId]?.bodyRegion ?? '';
    const labels = {
      'ankle': 'Cổ chân của bạn',
      'hip': 'Hông của bạn',
      'core': 'Core của bạn',
      'shoulder': 'Vai của bạn',
    };
    return labels[region] ?? '';
  }

  String _issueSubtitle([String? bodyRegion]) {
    final issueId = _getTopIssue();
    final region = bodyRegion?.isNotEmpty == true
        ? bodyRegion!
        : interpretingMap[issueId]?.bodyRegion ?? '';
    const labels = {
      'ankle': 'Cải thiện cổ chân',
      'hip': 'Cải thiện hông',
      'core': 'Tăng cường core',
      'shoulder': 'Cải thiện vai',
    };
    return labels[region] ?? '';
  }

  List<_WorkoutData> _buildWorkouts() {
    final days = _workoutDays;
    final goalPatterns = _goalExercisePatterns[_goalKey(widget.data.goal)] ??
        _goalExercisePatterns['health']!;

    return List.generate(days.length, (dayIndex) {
      final pattern = goalPatterns[dayIndex % goalPatterns.length];
      final mainExerciseIds = pattern.take(3).toList(growable: false);
      final mainExercises = mainExerciseIds
          .map((id) => _exerciseRegistry[id] ?? _exerciseRegistry['plank']!)
          .toList(growable: false);
      final corrective = _buildCorrectiveExercise(
        dayIndex,
        mainExerciseIds,
        mainExercises,
      );
      final fallback = _fallbackMainExercise(pattern, mainExercises);
      final summary = _summarizeWorkout(mainExercises);

      return _WorkoutData(
        title: summary.title,
        duration: summary.duration,
        muscles: summary.muscles,
        exercises: [
          ...mainExercises,
          corrective ?? fallback,
        ],
      );
    });
  }

  _ExerciseData? _buildCorrectiveExercise(
    int dayIndex,
    List<String> mainExerciseIds,
    List<_ExerciseData> mainExercises,
  ) {
    final issueId = _getTopIssue();
    if (issueId == null) {
      return null;
    }

    final definition = interpretingMap[issueId];
    if (definition == null || definition.correctives.isEmpty) {
      return null;
    }

    final mainKeys = mainExerciseIds.map(_movementKey).toSet();
    for (var offset = 0; offset < definition.correctives.length; offset++) {
      final correctiveId = definition
          .correctives[(dayIndex + offset) % definition.correctives.length];
      final base = _correctiveRegistry[correctiveId];
      if (base == null) {
        continue;
      }
      if (mainKeys.contains(_movementKey(correctiveId)) ||
          mainExercises.any((exercise) => exercise.name == base.name)) {
        continue;
      }
      return _ExerciseData(
        name: base.name,
        sets: base.sets,
        pose: base.pose,
        isCorrective: true,
        bodyRegion: definition.bodyRegion,
      );
    }

    return null;
  }

  String _movementKey(String exerciseId) {
    switch (exerciseId) {
      case 'floor_glute_bridge':
        return 'glute_bridge';
      default:
        return exerciseId;
    }
  }

  _ExerciseData _fallbackMainExercise(
    List<String> pattern,
    List<_ExerciseData> mainExercises,
  ) {
    for (final fallbackId in pattern.skip(3)) {
      final candidate = _exerciseRegistry[fallbackId];
      if (candidate == null) {
        continue;
      }
      if (!mainExercises.any((exercise) => exercise.name == candidate.name)) {
        return candidate;
      }
    }

    return _exerciseRegistry.values.firstWhere(
      (candidate) =>
          !mainExercises.any((exercise) => exercise.name == candidate.name),
      orElse: () => _exerciseRegistry['plank']!,
    );
  }

  _WorkoutSummary _summarizeWorkout(List<_ExerciseData> mainExercises) {
    const lowerBody = {'Squat', 'Lunge', 'Glute Bridge'};
    const coreHeavy = {
      'Plank',
      'Bird Dog',
      'McGill Curl-up',
      'Push-up',
      'Cat-Cow',
    };
    const mixed = {'Jumping Jack'};

    var lowerScore = 0;
    var coreScore = 0;
    var mixedScore = 0;

    for (final exercise in mainExercises) {
      if (lowerBody.contains(exercise.name)) {
        lowerScore++;
      }
      if (coreHeavy.contains(exercise.name)) {
        coreScore++;
      }
      if (mixed.contains(exercise.name)) {
        mixedScore++;
      }
    }

    final title = lowerScore >= 2
        ? 'Chân & Mông'
        : coreScore >= 2 && mixedScore == 0
            ? 'Core & Thân trên'
            : 'Toàn thân';

    final duration = switch (title) {
      'Chân & Mông' => '15 phút',
      'Core & Thân trên' => '12 phút',
      _ => '18 phút',
    };

    final muscles = <String>[];
    for (final exercise in mainExercises) {
      for (final muscle
          in _exerciseMuscles[exercise.name] ?? const <String>[]) {
        if (!muscles.contains(muscle)) {
          muscles.add(muscle);
        }
      }
    }

    return _WorkoutSummary(
      title: title,
      duration: duration,
      muscles: muscles.isEmpty ? const ['Toàn thân'] : muscles.take(4).toList(),
    );
  }

  String _silhouetteType(String pose) {
    switch (pose) {
      case 'stretch':
        return 'lunge';
      case 'birddog':
        return 'plank';
      case 'catcow':
        return 'bridge';
      default:
        return pose;
    }
  }

  Widget _buildExerciseTile(BuildContext context, _ExerciseData exercise) {
    if (exercise.isCorrective && !_isPro) {
      return GestureDetector(
        onTap: () => _showPaywall(context, exercise),
        child: _buildLockedCorrective(context, exercise),
      );
    }
    if (exercise.isCorrective && _isPro) {
      return _buildUnlockedCorrective(context, exercise);
    }
    return _buildMainExerciseTile(context, exercise);
  }

  Widget _buildMainExerciseTile(BuildContext context, _ExerciseData exercise) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * s),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34 * s,
            height: 34 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10 * s),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            alignment: Alignment.center,
            child: PoseSilhouette(
              type: _silhouetteType(exercise.pose),
              size: 18 * s,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VF.textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),
                SizedBox(height: 2 * s),
                Row(
                  children: [
                    Text(
                      'AI FORM',
                      style: VF.textStyle(
                        context,
                        size: 9,
                        weight: FontWeight.w600,
                        color: VF.jadeGlow.withValues(alpha: 0.45),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '  ·  ${exercise.sets}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VF.textStyle(
                          context,
                          size: 9,
                          weight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedCorrective(
    BuildContext context,
    _ExerciseData exercise,
  ) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * s),
        color: _tileDark,
        border: Border.all(color: _proPurple.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34 * s,
            height: 34 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10 * s),
              color: _proPurple.withValues(alpha: 0.10),
            ),
            alignment: Alignment.center,
            child: PoseSilhouette(
              type: _silhouetteType(exercise.pose),
              size: 18 * s,
              color: _proPurple.withValues(alpha: 0.70),
            ),
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VF.textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: _proPurple.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 2 * s),
                Row(
                  children: [
                    Text(
                      'Ai FORM',
                      style: VF.textStyle(
                        context,
                        size: 9,
                        weight: FontWeight.w500,
                        color: _proPurple.withValues(alpha: 0.45),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '  ·  ${exercise.sets}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VF.textStyle(
                          context,
                          size: 9,
                          weight: FontWeight.w500,
                          color: _proPurple.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2 * s),
                Text(
                  _issueSubtitle(exercise.bodyRegion),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VF.textStyle(
                    context,
                    size: 9,
                    weight: FontWeight.w500,
                    color: _proPurple.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedCorrective(BuildContext context, _ExerciseData exercise) {
    final s = VF.scale(context);
    final regionLabel = _bodyRegionLabel(exercise.bodyRegion);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * s),
        color: _tileDark,
        border: Border.all(color: _proPurple.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14 * s),
        child: Stack(
          children: [
            Opacity(
              opacity: 0.25,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Padding(
                  padding: EdgeInsets.all(10 * s),
                  child: Row(
                    children: [
                      Container(
                        width: 34 * s,
                        height: 34 * s,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10 * s),
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                        alignment: Alignment.center,
                        child: PoseSilhouette(
                          type: _silhouetteType(exercise.pose),
                          size: 18 * s,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              exercise.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VF.textStyle(
                                context,
                                size: 12,
                                weight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.80),
                              ),
                            ),
                            SizedBox(height: 2 * s),
                            Text(
                              'CHO BẠN  ·  ${exercise.sets}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VF.textStyle(
                                context,
                                size: 9,
                                weight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.40),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(
                  color: _tileDark.withValues(alpha: 0.26),
                ),
              ),
            ),
            Positioned(
              top: 7 * s,
              right: 7 * s,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * s,
                  vertical: 2 * s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5 * s),
                  color: VF.jadeGlow.withValues(alpha: 0.80),
                ),
                child: Text(
                  'PRO',
                  style: VF.textStyle(
                    context,
                    size: 7,
                    weight: FontWeight.w800,
                    color: const Color(0xFF0A1F17),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16 * s,
                      color: _proPurple.withValues(alpha: 0.50),
                    ),
                    SizedBox(height: 5 * s),
                    Text(
                      regionLabel.isEmpty ? 'Bài tập của bạn' : regionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VF.textStyle(
                        context,
                        size: 9,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2 * s),
                    Text(
                      'Xem với PRO',
                      style: VF.textStyle(
                        context,
                        size: 8,
                        weight: FontWeight.w500,
                        color: VF.jadeGlow.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context, _ExerciseData exercise) {
    final s = VF.scale(context);
    final region = _bodyRegionLabel(exercise.bodyRegion);
    final title = region.isEmpty
        ? 'Bài tập dành riêng cho bạn'
        : 'Bài tập dành riêng cho $region';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _tileDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24 * s)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24 * s, 28 * s, 24 * s, 32 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40 * s,
              height: 4 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2 * s),
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            SizedBox(height: 24 * s),
            Icon(
              Icons.lock_outline_rounded,
              size: 28 * s,
              color: _proPurple.withValues(alpha: 0.50),
            ),
            SizedBox(height: 12 * s),
            Text(
              title,
              textAlign: TextAlign.center,
              style: VF.textStyle(
                context,
                size: 18,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8 * s),
            Text(
              'AI đã phân tích form của bạn và tìm ra bài tập phù hợp',
              textAlign: TextAlign.center,
              style: VF.textStyle(
                context,
                size: 13,
                weight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.30),
                height: 1.5,
              ),
            ),
            SizedBox(height: 24 * s),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('user_is_pro', true);
                  if (!mounted) return;
                  setState(() => _isPro = true);
                  navigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VF.jadeGlow,
                  foregroundColor: const Color(0xFF0A1F17),
                  padding: EdgeInsets.symmetric(vertical: 16 * s),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16 * s),
                  ),
                ),
                child: Text(
                  'Nâng cấp PRO',
                  style: VF.textStyle(
                    context,
                    size: 16,
                    weight: FontWeight.w700,
                    color: const Color(0xFF0A1F17),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * s),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Để sau',
                style: VF.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final top = MediaQuery.of(context).padding.top + 12 * s;
    final days = _workoutDays;
    final selectedWorkout = _workouts.isEmpty
        ? const _WorkoutData(
            title: '',
            duration: '',
            muscles: [],
            exercises: [],
          )
        : _workouts[_selectedWorkoutDay % _workouts.length];

    return ColoredBox(
      color: VF.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20 * s, top, 20 * s, 16 * s),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24 * s,
                        height: 24 * s,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8 * s),
                          color: VF.accentSoft,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.done_rounded,
                          size: 14 * s,
                          color: VF.accent,
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Text(
                        'Chương trình đã tạo',
                        style: VF.textStyle(
                          context,
                          size: 11,
                          weight: FontWeight.w600,
                          color: VF.accent,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_levelLabel · ${days.length}x/tuần',
                        style: VF.textStyle(
                          context,
                          size: 11,
                          weight: FontWeight.w500,
                          color: VF.textMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14 * s),
                  Text(
                    'Tuần 1',
                    style: VF.textStyle(
                      context,
                      size: 32,
                      weight: FontWeight.w900,
                      color: VF.text,
                      letterSpacing: -1.8,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 6 * s),
                  Text(
                    'Học form cơ bản',
                    style: VF.textStyle(
                      context,
                      size: 14,
                      weight: FontWeight.w600,
                      color: VF.accent,
                    ),
                  ),
                  SizedBox(height: 14 * s),
                  Row(
                    children: List.generate(_dayLabels.length, (index) {
                      final hasWorkout = days.contains(index);
                      final active = hasWorkout &&
                          days.indexOf(index) == _selectedWorkoutDay;
                      return Expanded(
                        child: GestureDetector(
                          onTap: hasWorkout
                              ? () => setState(
                                    () => _selectedWorkoutDay =
                                        days.indexOf(index),
                                  )
                              : null,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(0, 8 * s, 0, 6 * s),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14 * s),
                              color: active ? VF.accent : Colors.transparent,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _dayLabels[index],
                                  style: VF.textStyle(
                                    context,
                                    size: 10,
                                    weight: FontWeight.w600,
                                    color: active
                                        ? Colors.white.withValues(alpha: 0.60)
                                        : VF.textMuted,
                                  ),
                                ),
                                SizedBox(height: 2 * s),
                                Text(
                                  '${_dayDates[index]}',
                                  style: VF.textStyle(
                                    context,
                                    size: 16,
                                    weight: active
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: active
                                        ? Colors.white
                                        : hasWorkout
                                            ? VF.text
                                            : VF.textMuted
                                                .withValues(alpha: 0.40),
                                  ),
                                ),
                                SizedBox(height: 4 * s),
                                Container(
                                  width: 5 * s,
                                  height: 5 * s,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active
                                        ? Colors.white.withValues(alpha: 0.60)
                                        : hasWorkout
                                            ? VF.accent.withValues(alpha: 0.50)
                                            : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 14 * s),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28 * s),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          VF.surfaceDark,
                          VF.jadeDark,
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28 * s),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: VFGrainOverlay(opacity: 0.035),
                          ),
                          Positioned(
                            bottom: -20 * s,
                            right: -10 * s,
                            child: Container(
                              width: 120 * s,
                              height: 120 * s,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: VF.jadeGlow.withValues(alpha: 0.04),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -12 * s,
                            right: -12 * s,
                            child:
                                const VFDecorativeRing(size: 70, opacity: 0.04),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                20 * s, 20 * s, 20 * s, 16 * s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (_selectedWorkoutDay == 0)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10 * s,
                                          vertical: 4 * s,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8 * s),
                                          color: VF.jadeGlow
                                              .withValues(alpha: 0.12),
                                          border: Border.all(
                                            color: VF.jadeGlow
                                                .withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(
                                          'HÔM NAY',
                                          style: VF.textStyle(
                                            context,
                                            size: 9,
                                            weight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: VF.jadeGlow
                                                .withValues(alpha: 0.60),
                                          ),
                                        ),
                                      ),
                                    if (_selectedWorkoutDay == 0)
                                      SizedBox(width: 8 * s),
                                    Text(
                                      days.isEmpty
                                          ? 'Tuần 1'
                                          : '${_dayLabels[days[_selectedWorkoutDay]]} · Tuần 1',
                                      style: VF.textStyle(
                                        context,
                                        size: 11,
                                        weight: FontWeight.w600,
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      selectedWorkout.duration,
                                      style: VF.textStyle(
                                        context,
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12 * s),
                                Text(
                                  selectedWorkout.title,
                                  style: VF.textStyle(
                                    context,
                                    size: 26,
                                    weight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                                SizedBox(height: 14 * s),
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 8 * s,
                                  mainAxisSpacing: 8 * s,
                                  childAspectRatio: 1.9,
                                  children: selectedWorkout.exercises
                                      .map((exercise) =>
                                          _buildExerciseTile(context, exercise))
                                      .toList(),
                                ),
                                SizedBox(height: 12 * s),
                                Wrap(
                                  spacing: 6 * s,
                                  runSpacing: 6 * s,
                                  children:
                                      selectedWorkout.muscles.map((muscle) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10 * s,
                                        vertical: 4 * s,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8 * s),
                                        color: Colors.white
                                            .withValues(alpha: 0.05),
                                      ),
                                      child: Text(
                                        muscle,
                                        style: VF.textStyle(
                                          context,
                                          size: 10,
                                          weight: FontWeight.w600,
                                          color: Colors.white
                                              .withValues(alpha: 0.20),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 18 * s),
                  Padding(
                    padding: EdgeInsets.only(left: 4 * s),
                    child: Text(
                      'Lộ trình 4 tuần',
                      style: VF.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: VF.text,
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Row(
                    children: _weekTiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tile = entry.value;
                      final active = index == 0;
                      final sessions = days.length + tile.sessions;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == _weekTiles.length - 1 ? 0 : 6 * s,
                          ),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: VF.surface,
                              borderRadius: BorderRadius.circular(18 * s),
                              border: Border.all(
                                color: active
                                    ? VF.accent.withValues(alpha: 0.20)
                                    : Colors.transparent,
                                width: 2 * s,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      6 * s, 12 * s, 6 * s, 13 * s),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 28 * s,
                                        height: 28 * s,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(9 * s),
                                          color: active
                                              ? VF.accent
                                              : VF.textMuted
                                                  .withValues(alpha: 0.08),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          tile.number,
                                          style: VF.textStyle(
                                            context,
                                            size: 12,
                                            weight: FontWeight.w800,
                                            color: active
                                                ? Colors.white
                                                : VF.textMuted,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 6 * s),
                                      Text(
                                        tile.title,
                                        textAlign: TextAlign.center,
                                        style: VF.textStyle(
                                          context,
                                          size: 10,
                                          weight: FontWeight.w700,
                                          color:
                                              active ? VF.accent : VF.textSec,
                                        ),
                                      ),
                                      SizedBox(height: 2 * s),
                                      Text(
                                        '$sessions buổi',
                                        textAlign: TextAlign.center,
                                        style: VF.textStyle(
                                          context,
                                          size: 8,
                                          weight: FontWeight.w500,
                                          color: VF.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 3 * s,
                                    color: active
                                        ? VF.accent
                                        : VF.textMuted.withValues(alpha: 0.06),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16 * s),
                  Container(
                    padding: EdgeInsets.all(16 * s),
                    decoration: BoxDecoration(
                      color: VF.surface,
                      borderRadius: BorderRadius.circular(16 * s),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CoachIcon(),
                        SizedBox(width: 12 * s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI theo dõi mỗi buổi tập',
                                style: VF.textStyle(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: VF.text,
                                ),
                              ),
                              SizedBox(height: 2 * s),
                              Text(
                                'Chương trình tự điều chỉnh dựa trên tiến bộ thực tế của bạn',
                                style: VF.textStyle(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: VF.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * s),
                ],
              ),
            ),
          ),
          VFOnboardingButton(
            label: 'Bắt đầu tập luyện',
            onTap: widget.onComplete,
          ),
        ],
      ),
    );
  }
}

class _CoachIcon extends StatelessWidget {
  const _CoachIcon();

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      width: 28 * s,
      height: 28 * s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9 * s),
        color: VF.accentSoft,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.schedule_rounded,
        size: 14 * s,
        color: VF.accent,
      ),
    );
  }
}

class _WorkoutSummary {
  const _WorkoutSummary({
    required this.title,
    required this.duration,
    required this.muscles,
  });

  final String title;
  final String duration;
  final List<String> muscles;
}

class _WorkoutData {
  const _WorkoutData({
    required this.title,
    required this.duration,
    required this.muscles,
    required this.exercises,
  });

  final String title;
  final String duration;
  final List<String> muscles;
  final List<_ExerciseData> exercises;
}

class _ExerciseData {
  const _ExerciseData({
    required this.name,
    required this.sets,
    required this.pose,
    this.isCorrective = false,
    this.bodyRegion = '',
  });

  final String name;
  final String sets;
  final String pose;
  final bool isCorrective;
  final String bodyRegion;
}
