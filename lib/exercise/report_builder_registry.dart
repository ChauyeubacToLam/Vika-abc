import '../models/post_exercise_data.dart';
import '../models/exercise_lookup.dart';
import '../utils/exercise_logger.dart';
import '../interpreter/interpreter_base.dart';
import '1.Bird Dog/bird_dog_report_builder.dart';
import '2.Sit-Up/sit_up_report_builder.dart';
import '3.High Plank/high_plank_report_builder.dart';
import '4.Mountain Climber/mountain_climber_report_builder.dart';
import '5.Superman/superman_report_builder.dart';
import '7.Plank Shoulder Tap/plank_shoulder_tap_report_builder.dart';
import 'squat/squat_report_builder.dart';
import '8.Leg Raises (Supine)/leg_raise_report_builder.dart';
import '9.Reverse Crunch/reverse_crunch_report_builder.dart';
import '10.Vup/v_up_report_builder.dart';
import '12.Dead Bug/dead_bug_report_builder.dart';
import '13.Plank Up-Down/plank_up_down_report_builder.dart';
import '14.Bear Plank/bear_plank_report_builder.dart';
import 'butterfly_stretch/butterfly_stretch_report_builder.dart';
import 'seated_forward_fold/seated_forward_report_builder.dart';
import 'cossack_squat/cossack_squat_report_builder.dart';
import 'plank/plank_report_builder.dart';
import 'warrior_1/warrior_one_report_builder.dart';
import 'walking_lunge/walking_lunge_report_builder.dart';
import 'tricep_dip/tricep_dip_report_builder.dart';
import 'russian_twist/russian_twist_report_builder.dart';
import 'Sphinx_Pose/sphinx_report_builder.dart';
import 'standing_knee_to_elbow/standing_knee_to_elbow_report_builder.dart';
import 'Cobra/cobra_report_builder.dart';
import 'curl_up/curl_up_report_builder.dart';
import 'glute bridge/glute_bridge_report_builder.dart';
import 'push up/push_up_report_builder.dart';
import 'downward_dog/downward_dog_report_builder.dart';
import 'wall_push_up/wall_push_up_report_builder.dart';
import 'ashtanga_namaskara/ashtanga_namaskara_report_builder.dart';
import 'low_lunge/low_lunge_report_builder.dart';
import 'prayer_pose/prayer_pose_report_builder.dart';
import 'raised_arms/raised_arms_report_builder.dart';
import 'bow_pose/bow_pose_report_builder.dart';
import 'jumping jack/jumping_jack_report_builder.dart';
import 'lunge/lunge_report_builder.dart';
import 'Jump_Squat/jump_squat_report_builder_v2.dart';
import 'side_plank_dip/side_plank_dip_report_builder_v2.dart';
import 'step_back_burpee/step_back_burpee_report_builder_v2.dart';

// ═══════════════════════════════════════════════════════════════
// REGISTRY
// ═══════════════════════════════════════════════════════════════

/// When adding a new exercise:
/// 1. Create FooReportBuilder extending ExerciseReportBuilder
/// 2. Implement detectIssue() and any B4 tip/praise maps
/// 3. Add entry here
/// 4. Done — buildReport(), generateCoachText() inherited from base
typedef ReportBuilderEntry = ({ExerciseReportBuilder builder, double met});

final Map<String, ReportBuilderEntry> reportBuilders = {
  'squat': (builder: SquatReportBuilder(), met: 5.0),
  'squat_assessment': (builder: SquatReportBuilder(), met: 5.0),
  'lunge': (builder: LungeReportBuilder(), met: 5.0),
  'jumping_jack': (builder: JumpingJackReportBuilder(), met: 8.0),
  'bird_dog': (builder: BirdDogReportBuilder(), met: 3.5),
  'sit_up': (builder: SitUpReportBuilder(), met: 3.8),
  'high_plank': (builder: HighPlankReportBuilder(), met: 3.5),
  'cobra': (builder: CobraReportBuilder(), met: 2.5),
  'glute_bridge': (builder: GluteBridgeReportBuilder(), met: 3.5),
  'curl_up': (builder: CurlUpReportBuilder(), met: 3.0),
  'bow_pose': (builder: BowPoseReportBuilder(), met: 2.5),
  'mountain_climber': (builder: MountainClimberReportBuilder(), met: 7.0),
  'plank_shoulder_tap': (builder: PlankShoulderTapReportBuilder(), met: 4.0),
  'push_up': (builder: PushUpReportBuilder(), met: 3.8),
  'superman': (builder: SupermanReportBuilder(), met: 3.5),
  'leg_raise': (builder: LegRaiseReportBuilder(), met: 3.5),
  'reverse_crunch': (builder: ReverseCrunchReportBuilder(), met: 3.5),
  'v_up': (builder: VUpReportBuilder(), met: 4.0),
  'dead_bug': (builder: DeadBugReportBuilder(), met: 3.0),
  'plank_up_down': (builder: PlankUpDownReportBuilder(), met: 4.5),
  'bear_plank': (builder: BearPlankReportBuilder(), met: 3.5),
  'plank': (builder: PlankReportBuilder(), met: 3.5),
  'warrior_one': (builder: WarriorOneReportBuilder(), met: 3.0),
  'butterfly_stretch': (builder: ButterflyReportBuilder(), met: 2.5),
  'seated_forward_fold': (builder: SeatedForwardReportBuilder(), met: 2.5),
  'cossack_squat': (builder: CossackSquatReportBuilder(), met: 5.0),
  'walking_lunge': (builder: WalkingLungeReportBuilder(), met: 6.0),
  'tricep_dip': (builder: TricepDipReportBuilder(), met: 3.5),
  'russian_twist': (builder: RussianTwistReportBuilder(), met: 5.0),
  'sphinx': (builder: SphinxReportBuilder(), met: 2.5),
  'standing_knee_to_elbow': (
    builder: StandingKneeToElbowReportBuilder(),
    met: 7.0
  ),
  'surya_namaskar': (builder: GenericReportBuilder(), met: 3.5),
  'wall_push_up': (builder: WallPushUpReportBuilder(), met: 3.0),
  'downward_dog': (builder: DownwardDogReportBuilder(), met: 3.0),
  'ashtanga_namaskara': (builder: AshtangaNamaskaraReportBuilder(), met: 2.5),
  'low_lunge': (builder: LowLungeReportBuilder(), met: 2.5),
  'prayer_pose': (builder: PrayerPoseReportBuilder(), met: 1.5),
  'raised_arms': (builder: RaisedArmsReportBuilder(), met: 2.0),
  'jump_squat': (builder: JumpSquatReportBuilderV2(), met: 8.0),
  'side_plank_dip': (builder: SidePlankDipReportBuilderV2(), met: 3.5),
  'step_back_burpee': (builder: StepBackBurpeeReportBuilderV2(), met: 8.0),
};

const Map<String, String> _reportBuilderAliases = {
  'butterfly': 'butterfly_stretch',
  'butterflystretch': 'butterfly_stretch',
  'legraises': 'leg_raise',
  'mcgillcurlup': 'curl_up',
  'mcgillcurlups': 'curl_up',
  'mcgillcurlupbw': 'curl_up',
  'bow': 'bow_pose',
  'sideplankwithhipdip': 'side_plank_dip',
  'tricepdipfloor': 'tricep_dip',
  'sphinx_': 'sphinx',
};

ReportBuilderEntry resolveReportBuilder(String exerciseId) {
  final direct = reportBuilders[exerciseId];
  if (direct != null) return direct;

  final alias =
      reportBuilders[_reportBuilderAliases[normalizeExerciseKey(exerciseId)]];
  if (alias != null) return alias;

  final definition = lookupExerciseDefinition(exerciseId);
  if (definition != null) {
    final byDefinitionId = reportBuilders[definition.id];
    if (byDefinitionId != null) return byDefinitionId;

    final byDefinitionAlias = reportBuilders[
        _reportBuilderAliases[normalizeExerciseKey(definition.id)]];
    if (byDefinitionAlias != null) return byDefinitionAlias;

    final normalizedDefinitionId = normalizeExerciseKey(definition.id);
    for (final entry in reportBuilders.entries) {
      if (normalizeExerciseKey(entry.key) == normalizedDefinitionId) {
        return entry.value;
      }
    }
  }

  final normalizedId = normalizeExerciseKey(exerciseId);
  for (final entry in reportBuilders.entries) {
    if (normalizeExerciseKey(entry.key) == normalizedId) {
      return entry.value;
    }
  }
  return (builder: GenericReportBuilder(), met: 3.5);
}

// ═══════════════════════════════════════════════════════════════
// INTEGRATION GUIDE
// ═══════════════════════════════════════════════════════════════

/*
  In exercise_experience_screen.dart:

  import '../../models/post_exercise_data.dart';
  import '../../exercise/report_builder_registry.dart';

  // Fields:
  PostExerciseData? _fullReport;
  SetReportData? _currentSetReport;

  // ── Set complete (active → rest): ──

  void _handleSetComplete(ExerciseLogger logger) {
    _setLoggers.add(logger);

    if (_isAssessment) {
      Navigator.of(context).pop({'logger': logger});
      return;
    }

    final entry = resolveReportBuilder(widget.definition.id);
    final report = entry.builder.buildReport(
      setLoggers: _setLoggers,
      exerciseName: widget.definition.name,
      metValue: entry.met,
    );
    _currentSetReport = report.sets.last;

    setState(() => _phase = _WorkoutFlowPhase.summary);
  }

  // ── All sets complete (rest → executive): ──

  void _handleSummaryNext() {
    if (_currentSet >= _spec.sets) {
      final entry = resolveReportBuilder(widget.definition.id);
      _fullReport = entry.builder.buildReport(
        setLoggers: _setLoggers,
        exerciseName: widget.definition.name,
        metValue: entry.met,
      );
      setState(() => _phase = _WorkoutFlowPhase.executive);
      return;
    }
    _currentSet += 1;
    _startSet();
  }

  // ── Fatigue (set-level score drop → ask more rest): ──

  bool _shouldAskFatigueQuestion() {
    if (_setLoggers.length < 2) return false;
    final entry = resolveReportBuilder(widget.definition.id);
    final report = entry.builder.buildReport(
      setLoggers: _setLoggers,
      exerciseName: widget.definition.name,
      metValue: entry.met,
    );
    final scores = report.setScores;
    return scores.length >= 2 &&
        scores.last < scores[scores.length - 2] - 15;
  }
  // If true → rest screen shows:
  //   "Form giảm so với set trước. Nghỉ thêm 15s không?"
  //   Có → timer 60s. Không → timer 45s.

  // ── UI screens: ──

  _WorkoutFlowPhase.summary => RestScreen(
    setReport: _currentSetReport!,
    setIndex: _currentSet - 1,
    totalSets: _spec.sets,
    showFatigueQuestion: _shouldAskFatigueQuestion(),
    onNext: _handleSummaryNext,
  ),

  _WorkoutFlowPhase.executive => ExecutiveSummaryPage(
    report: _fullReport!,
    userWeightKg: _userWeight,
    totalDuration: DateTime.now().difference(_startedAt!),
    onDone: () => Navigator.of(context).pop(),
  ),
*/

// ═══════════════════════════════════════════════════════════════
// GENERIC FALLBACK
// ═══════════════════════════════════════════════════════════════

/// Minimal builder for exercises without a custom implementation.
/// Inherits buildReport() and generateCoachText() from base.
/// Only implements the 2 required methods with simple defaults.
class GenericReportBuilder extends ExerciseReportBuilder {
  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    if (allReps.isEmpty) return [];
    final totalGood = allReps.where((r) => r.correctForm).length;
    final accuracy = (totalGood / allReps.length * 100).roundToDouble();
    return [
      DetailCard(
        label: 'Độ chính xác',
        value: '${accuracy.round()}%',
        subLabel: '$totalGood/${allReps.length} rep',
        useRadial: true,
        radialValue: accuracy,
        color: 'jade',
      ),
    ];
  }
}

class GenericSecondBasedReportBuilder extends GenericReportBuilder {
  @override
  bool get isSecondBased => true;
}
