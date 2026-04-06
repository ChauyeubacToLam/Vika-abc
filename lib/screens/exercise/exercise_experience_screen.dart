import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../exercise/exercise_base.dart';
import '../../exercise/glute bridge/glute_bridge.dart';
import '../../exercise/jumping jack/jumping_jack.dart';
import '../../exercise/lunge/lunge.dart';
import '../../exercise/plank/plank.dart';
import '../../exercise/push up/push_up.dart';
import '../../exercise/squat/metrics/heel_rise_metric.dart';
import '../../exercise/squat/metrics/tempo_metric.dart';
import '../../exercise/squat/metrics/trunk_lean_metric.dart';
import '../../exercise/squat/squat.dart';
import '../../models/exercise_definition.dart';
import '../../utils/exercise_logger.dart';
import 'active_exercise_page.dart';
import 'exercise_intro_page.dart';
import 'executive_summary_page.dart';
import 'set_summary_page.dart';
import 'widgets/skeleton_annotation.dart';

class ExerciseExperienceScreen extends StatefulWidget {
  const ExerciseExperienceScreen({
    super.key,
    required this.definition,
  });

  final ExerciseDefinition definition;

  @override
  State<ExerciseExperienceScreen> createState() =>
      _ExerciseExperienceScreenState();
}

class _ExerciseExperienceScreenState extends State<ExerciseExperienceScreen> {
  late final _ExerciseExperienceSpec _spec;
  _WorkoutFlowPhase _phase = _WorkoutFlowPhase.intro;
  final List<ExerciseLogger> _setLoggers = [];
  ExerciseBase? _activeExercise;
  int _currentSet = 1;
  DateTime? _startedAt;
  String _coachNote =
      'Buổi này AI sẽ ưu tiên nhịp chậm, form chắc và sự ổn định trong từng rep.';

  bool get _isAssessment => widget.definition.id.endsWith('_assessment');

  @override
  void initState() {
    super.initState();
    _spec = _ExerciseExperienceSpec.fromDefinition(widget.definition);
    _loadCoachNote();
  }

  Future<void> _loadCoachNote() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getString('user_level') ?? 'beginner';
    final issues = prefs.getStringList('detected_issues') ?? const [];

    String note;
    if (issues.contains('ankle_mobility_restriction')) {
      note =
          'Buổi này AI sẽ ưu tiên giữ gót chân ổn định và giảm xu hướng đổ người về trước khi bạn xuống squat.';
    } else if (issues.contains('hip_flexor_overactivity')) {
      note =
          'Buổi này AI sẽ tập trung vào kiểm soát thân trên và giữ nhịp xuống chắc hơn để bạn không phải gập người quá nhiều.';
    } else if (issues.contains('ankle_mobility')) {
      note =
          'Buổi này AI sẽ chú ý thêm phần gót chân và độ sâu vì lần đánh giá trước cho thấy mắt cá còn hơi cứng.';
    } else if (issues.contains('limited_mobility')) {
      note =
          'AI sẽ ưu tiên độ sâu và nhịp xuống ổn định để bạn vào squat sâu hơn nhưng vẫn an toàn.';
    } else if (level == 'beginner') {
      note =
          'Buổi này AI tập trung vào nhịp xuống chậm, giữ đáy vững và cảm giác kiểm soát toàn bộ thân người.';
    } else {
      note =
          'AI sẽ theo dõi độ sâu, nhịp và độ ổn định để bạn giữ form sắc nét hơn trong toàn bộ buổi tập.';
    }

    if (mounted) {
      setState(() {
        _coachNote = note;
      });
    }
  }

  void _beginWorkout() {
    _setLoggers.clear();
    _currentSet = 1;
    _startedAt = DateTime.now();
    _startSet();
  }

  void _startSet() {
    setState(() {
      _activeExercise = _spec.createExercise();
      _phase = _WorkoutFlowPhase.active;
    });
  }

  void _handleSetComplete(ExerciseLogger logger) {
    if (_isAssessment) {
      Navigator.of(context).pop({'logger': logger});
      return;
    }

    setState(() {
      _setLoggers.add(logger);
      _phase = _WorkoutFlowPhase.summary;
    });
  }

  void _handleSummaryNext() {
    if (_currentSet >= _spec.sets) {
      setState(() {
        _phase = _WorkoutFlowPhase.executive;
      });
      return;
    }

    _currentSet += 1;
    _startSet();
  }

  Future<void> _persistIssueAnswers(Map<String, String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final payload =
        answers.entries.map((entry) => '${entry.key}:${entry.value}').toList();
    await prefs.setStringList(
      'exercise_feedback_${widget.definition.id}',
      payload,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _WorkoutFlowPhase.active
          ? const Color(0xFF080C1A)
          : const Color(0xFFF0EDE6),
      body: switch (_phase) {
        _WorkoutFlowPhase.intro => ExerciseIntroPage(
            title: widget.definition.name,
            difficulty: widget.definition.difficulty,
            totalSets: _spec.sets,
            repsPerSet: _spec.repsPerSet,
            videoDuration: _spec.videoDuration,
            muscles: _spec.muscles,
            tips: _spec.tips,
            badges: _spec.badges,
            callouts: _spec.callouts,
            coachNote: _coachNote,
            onStart: _beginWorkout,
            onBack: () => Navigator.of(context).pop(),
          ),
        _WorkoutFlowPhase.active => ActiveExercisePage(
            definition: widget.definition,
            exercise: _activeExercise!,
            currentSet: _currentSet,
            totalSets: _spec.sets,
            totalReps: _spec.repsPerSet,
            onSetComplete: _handleSetComplete,
            onBack: () => Navigator.of(context).pop(),
          ),
        _WorkoutFlowPhase.summary => SetSummaryPage(
            logger: _setLoggers.last,
            setIndex: _currentSet - 1,
            isLastSet: _currentSet == _spec.sets,
            restDuration: _spec.restDuration,
            onNext: _handleSummaryNext,
          ),
        _WorkoutFlowPhase.executive => ExecutiveSummaryPage(
            exerciseName: widget.definition.name,
            setLoggers: _setLoggers,
            totalDuration:
                DateTime.now().difference(_startedAt ?? DateTime.now()),
            onDone: () => Navigator.of(context).pop(),
            onIssueAnswersChanged: (answers) {
              _persistIssueAnswers(answers);
            },
          ),
      },
    );
  }
}

enum _WorkoutFlowPhase { intro, active, summary, executive }

class _ExerciseExperienceSpec {
  const _ExerciseExperienceSpec({
    required this.sets,
    required this.repsPerSet,
    required this.restDuration,
    required this.videoDuration,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.createExercise,
  });

  final int sets;
  final int repsPerSet;
  final int restDuration;
  final String videoDuration;
  final List<String> muscles;
  final List<String> tips;
  final List<ExerciseIntroBadge> badges;
  final List<SkeletonCallout> callouts;
  final ExerciseBase Function() createExercise;

  factory _ExerciseExperienceSpec.fromDefinition(
      ExerciseDefinition definition) {
    switch (definition.id) {
      case 'squat_assessment':
        return _ExerciseExperienceSpec(
          sets: 1,
          repsPerSet: 5,
          restDuration: 0,
          videoDuration: '1:18',
          muscles: definition.targetMuscles,
          tips: definition.setupTips,
          badges: [
            ExerciseIntroBadge(
              title: 'Nhịp xuống',
              value: '≥ ${TempoConfig.DESCENT_MIN_GOOD}s',
              color: const Color(0xFF2B5EA6),
            ),
            ExerciseIntroBadge(
              title: 'Giữ đáy',
              value: '≥ ${TempoConfig.BOTTOM_HOLD_MIN}s',
              color: const Color(0xFF7040B8),
            ),
          ],
          callouts: [
            SkeletonCallout(
              title: 'Lưng nghiêng',
              value:
                  '${TrunkLeanConfig.GOOD_LEAN_RANGE[0]}° — ${TrunkLeanConfig.GOOD_LEAN_RANGE[1]}°',
              color: const Color(0xFFB87320),
              alignment: const Alignment(0.90, -0.40),
              anchor: const Offset(0.24, 0.56),
            ),
            SkeletonCallout(
              title: 'Độ sâu gối',
              value:
                  '${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0]}° — ${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]}°',
              color: const Color(0xFF1B6B52),
              alignment: const Alignment(0.90, -0.02),
              anchor: const Offset(0.16, 0.72),
            ),
            SkeletonCallout(
              title: 'Gót chân',
              value:
                  'Nhấc < ${(HeelRiseConfig.LIFT_THRESHOLD * 100).round()}% chiều dài lưng',
              color: const Color(0xFFB84435),
              alignment: const Alignment(0.90, 0.34),
              anchor: const Offset(0.20, 0.88),
            ),
          ],
          createExercise: () => Squat(maxRep: 5),
        );
      case 'wall_pushup_assessment':
        return _generic(
          definition: definition,
          sets: 1,
          repsPerSet: 5,
          restDuration: 0,
          videoDuration: '1:12',
          createExercise: () => PushUp(maxRep: 5),
        );
      case 'squat':
        return _ExerciseExperienceSpec(
          sets: 3,
          repsPerSet: 8,
          restDuration: 45,
          videoDuration: '2:15',
          muscles: definition.targetMuscles,
          tips: definition.setupTips,
          badges: [
            ExerciseIntroBadge(
              title: 'Nhịp xuống',
              value: '≥ ${TempoConfig.DESCENT_MIN_GOOD}s',
              color: const Color(0xFF2B5EA6),
            ),
            ExerciseIntroBadge(
              title: 'Giữ đáy',
              value: '≥ ${TempoConfig.BOTTOM_HOLD_MIN}s',
              color: const Color(0xFF7040B8),
            ),
          ],
          callouts: [
            SkeletonCallout(
              title: 'Lưng nghiêng',
              value:
                  '${TrunkLeanConfig.GOOD_LEAN_RANGE[0]}° — ${TrunkLeanConfig.GOOD_LEAN_RANGE[1]}°',
              color: const Color(0xFFB87320),
              alignment: const Alignment(0.90, -0.40),
              anchor: const Offset(0.24, 0.56),
            ),
            SkeletonCallout(
              title: 'Độ sâu gối',
              value:
                  '${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0]}° — ${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]}°',
              color: const Color(0xFF1B6B52),
              alignment: const Alignment(0.90, -0.02),
              anchor: const Offset(0.16, 0.72),
            ),
            SkeletonCallout(
              title: 'Gót chân',
              value:
                  'Nhấc < ${(HeelRiseConfig.LIFT_THRESHOLD * 100).round()}% chiều dài lưng',
              color: const Color(0xFFB84435),
              alignment: const Alignment(0.90, 0.34),
              anchor: const Offset(0.20, 0.88),
            ),
          ],
          createExercise: () => Squat(maxRep: 8),
        );
      case 'lunge':
        return _generic(
          definition: definition,
          repsPerSet: 8,
          restDuration: 40,
          videoDuration: '1:58',
          createExercise: () => Lunge(maxRep: 8),
        );
      case 'push_up':
        return _generic(
          definition: definition,
          repsPerSet: 6,
          restDuration: 45,
          videoDuration: '1:42',
          createExercise: () => PushUp(maxRep: 6),
        );
      case 'plank':
        return _generic(
          definition: definition,
          repsPerSet: 3,
          restDuration: 30,
          videoDuration: '1:28',
          createExercise: () => Plank(maxRep: 3),
        );
      case 'jumping_jack':
        return _generic(
          definition: definition,
          repsPerSet: 15,
          restDuration: 25,
          videoDuration: '1:10',
          createExercise: () => JumpingJack(maxRep: 15),
        );
      case 'glute_bridge':
        return _generic(
          definition: definition,
          repsPerSet: 15,
          restDuration: 35,
          videoDuration: '1:36',
          createExercise: () => GluteBridge(),
        );
      default:
        return _generic(
          definition: definition,
          repsPerSet: 8,
          restDuration: 40,
          videoDuration: '1:30',
          createExercise: definition.createExercise,
        );
    }
  }

  static _ExerciseExperienceSpec _generic({
    required ExerciseDefinition definition,
    int sets = 3,
    required int repsPerSet,
    required int restDuration,
    required String videoDuration,
    required ExerciseBase Function() createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      restDuration: restDuration,
      videoDuration: videoDuration,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: [
        ExerciseIntroBadge(
          title: 'Nhịp tập',
          value: 'Ổn định',
          color: const Color(0xFF2B5EA6),
        ),
        ExerciseIntroBadge(
          title: 'Kiểm soát',
          value: 'Có AI theo dõi',
          color: const Color(0xFF7040B8),
        ),
      ],
      callouts: [
        SkeletonCallout(
          title: 'Tư thế thân trên',
          value: 'Giữ ổn định',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.40),
          anchor: const Offset(0.24, 0.56),
        ),
        SkeletonCallout(
          title: 'Biên độ chính',
          value: 'Theo dõi liên tục',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.02),
          anchor: const Offset(0.16, 0.72),
        ),
        SkeletonCallout(
          title: 'Nhịp chuyển động',
          value: 'Mượt và đều',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.20, 0.88),
        ),
      ],
      createExercise: createExercise,
    );
  }
}
