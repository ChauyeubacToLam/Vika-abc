import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/1.Bird Dog/bird_dog.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
import 'package:vika/exercise/14.Bear Plank/bear_plank.dart';
import 'package:vika/exercise/3.High Plank/high_plank.dart';
import 'package:vika/exercise/4.Mountain Climber/metrics/mountain_climber_metric_base.dart';
import 'package:vika/exercise/4.Mountain Climber/mountain_climber.dart';
import 'package:vika/exercise/5.Superman/metrics/superman_metric_base.dart';
import 'package:vika/exercise/5.Superman/superman.dart';
import 'package:vika/exercise/7.Plank Shoulder Tap/metrics/plank_shoulder_tap_metric_base.dart';
import 'package:vika/exercise/7.Plank Shoulder Tap/plank_shoulder_tap.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/leg_raise.dart';
import 'package:vika/exercise/9.Reverse Crunch/metrics/reverse_crunch_metric_base.dart';
import 'package:vika/exercise/9.Reverse Crunch/reverse_crunch.dart';
import 'package:vika/exercise/Jump_Squat/jump_squat.dart';
import 'package:vika/exercise/Sphinx_Pose/sphinx_stretch.dart';
import 'package:vika/exercise/Sphinx_Pose/Metrics/sphinx_metric_base.dart';
import 'package:vika/exercise/bow_pose/bow_pose.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/exercise/jumping jack/jumping_jack.dart';
import 'package:vika/exercise/lunge/lunge.dart';
import 'package:vika/exercise/russian_twist/russian_twist.dart';
import 'package:vika/utils/exercise_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('exercise logging alignment', () {
    test('known score-zero exercises publish max_rep and good_rep_count', () {
      final legRaise = LegRaise(maxRep: 7)
        ..logger.addRepLog(RepLog(
          correctForm: true,
          repNumber: 1,
          data: const {},
        ))
        ..logger.addRepLog(RepLog(
          correctForm: false,
          repNumber: 2,
          data: const {},
        ));

      legRaise.onSetComplete();

      expect(legRaise.logger.setLogs['max_rep'], 7);
      expect(legRaise.logger.setLogs['good_rep_count'], 1);

      final shoulderTap = PlankShoulderTap(maxRep: PlankTapConfig.MAX_REP)
        ..logger.addRepLog(RepLog(
          correctForm: true,
          repNumber: 1,
          data: const {},
        ))
        ..logger.addRepLog(RepLog(
          correctForm: false,
          repNumber: 2,
          data: const {},
        ));

      shoulderTap.onSetComplete();

      expect(shoulderTap.logger.setLogs['max_rep'], PlankTapConfig.MAX_REP);
      expect(shoulderTap.logger.setLogs['good_rep_count'], 1);
    });

    test('previously empty hooks publish squat-style score keys', () {
      final exercises = [
        (exercise: GluteBridge(maxRep: 4), maxRep: 4),
        (exercise: Lunge(maxRep: 5), maxRep: 5),
        (exercise: JumpingJack(maxRep: 6), maxRep: 6),
        (exercise: BowPose(maxRep: 2), maxRep: 2),
      ];

      for (final entry in exercises) {
        entry.exercise.onSetComplete();
        expect(entry.exercise.logger.setLogs['max_rep'], entry.maxRep);
        expect(entry.exercise.logger.setLogs['good_rep_count'], 0);
      }
    });

    test('rep-based report exercises use target max_rep denominator', () {
      final birdDog = BirdDog(maxRep: 8)..onSetComplete();
      final deadBug = DeadBug(maxRep: 7)..onSetComplete();
      final russianTwist = RussianTwist(maxRep: 6)..onSetComplete();
      final jumpSquat = JumpSquat(maxRep: 5)..onSetComplete();
      final mountainClimber = MountainClimber(maxRep: ClimberConfig.MAX_REP)
        ..onSetComplete();
      final superman = Superman(maxRep: SupermanConfig.MAX_REP)
        ..onSetComplete();
      final reverseCrunch = ReverseCrunch(maxRep: ReverseCrunchConfig.MAX_REP)
        ..onSetComplete();

      expect(birdDog.logger.setLogs['max_rep'], 8);
      expect(deadBug.logger.setLogs['max_rep'], 7);
      expect(russianTwist.logger.setLogs['max_rep'], 6);
      expect(jumpSquat.logger.setLogs['max_rep'], 5);
      expect(mountainClimber.logger.setLogs['max_rep'], ClimberConfig.MAX_REP);
      expect(superman.logger.setLogs['max_rep'], SupermanConfig.MAX_REP);
      expect(
        reverseCrunch.logger.setLogs['max_rep'],
        ReverseCrunchConfig.MAX_REP,
      );

      final sphinx = SphinxStretch(maxSeconds: 3)..onSetComplete();
      expect(sphinx.repCount, 0);
      expect(sphinx.logger.setLogs.containsKey('target_rep'), isFalse);
      expect(sphinx.logger.setLogs['max_rep'], SphinxConfig.Af_Max_Reps);
    });

    test('hold exercises publish fault seconds without duplicate count keys',
        () {
      final highPlank = HighPlank(maxHolds: 1, holdSeconds: 30);
      highPlank.onSetComplete();
      highPlank.onSetComplete();

      expect(highPlank.logger.setLogs['total_seconds'], 30.0);
      expect(highPlank.logger.setLogs['good_seconds'], 0.0);
      expect(highPlank.logger.setLogs['sagging_seconds'], 0.0);
      expect(highPlank.logger.setLogs['piked_seconds'], 0.0);
      expect(highPlank.logger.setLogs['elbow_seconds'], 0.0);
      expect(highPlank.logger.repLogs, isEmpty);

      final bearPlank = BearPlank(maxSeconds: 30);
      bearPlank.onSetComplete();
      bearPlank.onSetComplete();

      expect(bearPlank.logger.setLogs['total_seconds'], 30.0);
      expect(bearPlank.logger.setLogs['good_seconds'], 0.0);
      expect(bearPlank.logger.setLogs.containsKey('knee_fails'), isFalse);
      expect(bearPlank.logger.setLogs.containsKey('knee_fails_count'), isFalse);
      expect(bearPlank.logger.setLogs['knee_seconds'], 0.0);
      expect(bearPlank.logger.setLogs['back_seconds'], 0.0);
      expect(bearPlank.logger.setLogs['weight_seconds'], 0.0);
      expect(bearPlank.logger.repLogs, hasLength(1));
    });
  });
}
