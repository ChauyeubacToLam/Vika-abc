// Render smoke-tests for the redesigned WorkoutSummaryScreen ("Form Reel").
//
// These pump the real screen with representative session data and assert it
// lays out without throwing (overflow / unbounded-constraint errors throw in
// debug and are captured by takeException). Setting the LAST report's
// userDifficulty skips the on-entry rating popup so the reveal cascade — and
// thus the full passive layout — renders directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/models/workout_session_report.dart';
import 'package:vika/screens/exercise/workout_summary_screen.dart';
import 'package:vika/services/session_coach_builder.dart';
import 'package:vika/services/session_summary_builder.dart';
import 'package:vika/services/session_trophy_picker.dart';

void main() {
  testWidgets('multi-exercise session renders without overflow', (tester) async {
    final reports = [
      _report(name: 'Squat', setScores: [82, 88, 91]),
      _report(name: 'Chùng chân', setScores: [70, 66, 74]),
      _report(name: 'Hít đất', setScores: [55, 48, 61]),
    ];
    await _pumpSummary(tester, reports, streakDays: 0);
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('TỔNG KẾT BUỔI TẬP'), findsOneWidget);
    expect(find.text('Hoàn thành buổi tập'), findsOneWidget);
    expect(find.text('HẾT'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('single exercise / single set uses the crest fallback cleanly',
      (tester) async {
    final reports = [
      _report(name: 'Squat', setScores: [76]),
    ];
    await _pumpSummary(tester, reports);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('time-based (hold) session renders the GIÂY vital + spark',
      (tester) async {
    final reports = [
      _report(name: 'Plank', setScores: [80, 84, 79], timeBased: true),
    ];
    await _pumpSummary(tester, reports);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('GIÂY'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('mixed rep + hold session does not crash the vital strip',
      (tester) async {
    final reports = [
      _report(name: 'Squat', setScores: [70, 72]),
      _report(name: 'Plank', setScores: [85, 88], timeBased: true),
    ];
    await _pumpSummary(tester, reports);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    // Mixed → reps shown (never summed across holds).
    expect(find.text('ĐÚNG FORM'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('streak-bonus session reveals the bonus caption', (tester) async {
    final reports = [
      _report(name: 'Squat', setScores: [88, 90, 92]),
    ];
    await _pumpSummary(tester, reports, streakDays: 7);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('chuỗi'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('renders on a 320pt iPhone SE width without horizontal overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reports = [
      _report(name: 'Squat', setScores: [100, 105.clamp(0, 100), 95]),
      _report(name: 'Chùng chân trước', setScores: [70, 66, 74]),
      _report(name: 'Hít đất kiểu quân đội', setScores: [55, 48, 61]),
      _report(name: 'Gập bụng', setScores: [80, 82, 78]),
      _report(name: 'Cầu mông', setScores: [90, 88, 91]),
    ];
    await _pumpSummary(tester, reports, streakDays: 14);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester) async {
  // Let the post-frame callback fire (popup is skipped because the last
  // report has a difficulty) and the 1700ms entry cascade play. We can't
  // pumpAndSettle — the shimmer/pulse controllers repeat forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _dispose(WidgetTester tester) async {
  // Unmount so the repeating AnimationControllers are disposed (no ticker leak).
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<void> _pumpSummary(
  WidgetTester tester,
  List<ExerciseSessionReport> reports, {
  int streakDays = 0,
}) async {
  // Skip the on-entry rating popup so the reveal cascade renders directly.
  reports.last.userDifficulty = 'medium';

  final summary = SessionSummaryBuilder.build(reports, streakDays);
  final trophy = SessionTrophyPicker.pick(
    reports: reports,
    sessionRawFormScore: summary.rawFormScore,
    streakWeeks: streakDays,
    priorSessionForms: const [],
    priorExerciseForms: const {},
  );
  final lowest =
      reports.map((r) => r.formScore).fold<int>(100, (a, b) => a < b ? a : b);
  final coach = SessionCoachBuilder.build(
    candidates: const [],
    trophy: trophy,
    lowestFormScore: lowest,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: WorkoutSummaryScreen(
        reports: reports,
        sessionSummary: summary,
        totalDuration: const Duration(minutes: 8, seconds: 12),
        totalCalories: 128,
        trophy: trophy,
        coach: coach,
        onDone: () {},
      ),
    ),
  );
}

ExerciseSessionReport _report({
  required String name,
  required List<num> setScores,
  bool timeBased = false,
  int repsPerSet = 10,
  int goodRepsPerSet = 8,
  double secondsPerSet = 30,
  double goodSecondsPerSet = 24,
}) {
  final scores = setScores.map((s) => s.round()).toList();
  final fs = (scores.reduce((a, b) => a + b) / scores.length).round();
  final sets = [
    for (var i = 0; i < scores.length; i++)
      SetReportData(
        setIndex: i,
        score: scores[i],
        totalReps: timeBased ? null : repsPerSet,
        goodReps: timeBased ? null : goodRepsPerSet,
        totalSeconds: timeBased ? secondsPerSet : null,
        goodSeconds: timeBased ? goodSecondsPerSet : null,
        repResults: List<bool>.filled(timeBased ? 1 : repsPerSet, true),
      ),
  ];
  return ExerciseSessionReport(
    definition: _definition(id: name.toLowerCase(), name: name),
    exerciseKey: name.toLowerCase(),
    report: PostExerciseData(
      exerciseName: name,
      metValue: 1,
      sets: sets,
      formScore: fs,
      coachText: '',
      isSecondBased: timeBased,
    ),
    duration: const Duration(minutes: 2),
    calories: 32,
  );
}

ExerciseDefinition _definition({required String id, required String name}) {
  return ExerciseDefinition(
    id: id,
    name: name,
    subtitle: '',
    description: '',
    icon: Icons.fitness_center,
    primaryColor: Colors.black,
    secondaryColor: Colors.white,
    difficulty: '',
    targetMuscles: const [],
    duration: '',
    cameraHint: '',
    framingHint: '',
    setupTips: const [],
    createExercise: () => throw UnimplementedError(),
    phaseColors: const {},
  );
}
