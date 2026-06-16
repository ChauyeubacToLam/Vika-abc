import 'dart:math' as math;

import 'package:vika/services/recommendation/fitness_test_scoring.dart';
import 'package:vika/utils/exercise_logger.dart';

import '../onboarding_assessment_thresholds.dart';
import '../onboarding_data.dart';

class V5WhyOption {
  const V5WhyOption({
    required this.id,
    required this.label,
    required this.sub,
    required this.stat,
    required this.statLabel,
  });

  final String id;
  final String label;
  final String sub;
  final String stat;
  final String statLabel;
}

const whyOptions = [
  V5WhyOption(
    id: 'body',
    label: 'Cải thiện vóc dáng',
    sub: 'Cơ thể bạn mong muốn',
    stat: '-2kg',
    statLabel: 'Trung bình sau 4 tuần',
  ),
  V5WhyOption(
    id: 'pain',
    label: 'Giảm đau, tư thế tốt',
    sub: 'Lưng, cổ, vai, gối',
    stat: '47%',
    statLabel: 'Giảm đau lưng sau 4 tuần',
  ),
  V5WhyOption(
    id: 'energy',
    label: 'Năng lượng cho cả ngày',
    sub: 'Hết kiệt sức sau giờ làm',
    stat: '+20%',
    statLabel: 'Năng lượng & tinh thần',
  ),
  V5WhyOption(
    id: 'strength',
    label: 'Khoẻ & tự tin hơn',
    sub: 'Cho công việc và cuộc sống',
    stat: '+66%',
    statLabel: 'Sức bền chống đẩy',
  ),
];

const whyFollowups = {
  'body': [
    'Giảm cân, gọn người hơn',
    'Săn chắc tay, chân, bụng',
    'Tăng cơ, lên dáng',
    'Tự tin mặc đồ mình thích',
  ],
  'pain': [
    'Đau lưng do ngồi văn phòng cả ngày',
    'Vai/cổ căng cứng sau giờ làm',
    'Đầu gối khó chịu khi đứng lên xuống',
    'Tư thế xấu, gù lưng / đầu cúi',
    'Hồi phục sau chấn thương cũ',
  ],
  'energy': [
    'Đi làm về vẫn còn năng lượng cho cuộc sống',
    'Ngủ ngon hơn, dậy tỉnh táo hơn',
    'Phòng bệnh, khoẻ lâu dài',
    'Giảm căng thẳng, tinh thần ổn định',
  ],
  'strength': [
    'Tăng sức bền cho công việc bận',
    'Tăng cơ chắc, khoẻ hơn',
    'Theo đuổi môn thể thao tôi thích (đá bóng, chạy bộ, ...)',
    'Tự tin với cơ thể mình hơn',
  ],
};

class V5GoalOption {
  const V5GoalOption({
    required this.id,
    required this.title,
    required this.sub,
    required this.stat,
    required this.unit,
  });

  final String id;
  final String title;
  final String sub;
  final String stat;
  final String unit;
}

const goalOptions = [
  V5GoalOption(
    id: 'health',
    title: 'Sức khỏe',
    sub: 'Dẻo dai, ít đau mỏi',
    stat: '8h',
    unit: 'Giấc ngủ sâu',
  ),
  V5GoalOption(
    id: 'body',
    title: 'Vóc dáng',
    sub: 'Săn chắc, gọn người',
    stat: '-3.5kg',
    unit: 'Mỡ thừa',
  ),
  V5GoalOption(
    id: 'strength',
    title: 'Sức mạnh',
    sub: 'Cơ bắp, sức bền',
    stat: '+15kg',
    unit: 'Tổng nâng',
  ),
  V5GoalOption(
    id: 'flexible',
    title: 'Linh hoạt',
    sub: 'Mềm dẻo, an toàn',
    stat: '+10cm',
    unit: 'Biên độ khớp',
  ),
];

class V5DurationOption {
  const V5DurationOption({
    required this.id,
    required this.label,
    required this.sub,
  });

  final String id;
  final String label;
  final String sub;
}

const durationOptions = [
  V5DurationOption(id: '<6m', label: '< 6 tháng', sub: 'Mới bắt đầu'),
  V5DurationOption(id: '6m-2y', label: '6 tháng – 2 năm', sub: 'Đang quen'),
  V5DurationOption(id: '2y+', label: '2 năm+', sub: 'Đã lâu'),
];

class ForkChoice {
  const ForkChoice({
    required this.id,
    required this.title,
    required this.sub,
    required this.stat,
    required this.statLabel,
    required this.highlights,
    required this.caveats,
    required this.equipment,
  });

  final String id;
  final String title;
  final String sub;
  final String stat;
  final String statLabel;

  /// "Phù hợp khi bạn muốn" — positive-fit bullets.
  final List<String> highlights;

  /// "Chưa lý tưởng nếu" — honest caveats so the user can self-select.
  final List<String> caveats;

  /// Equipment line shown in the footer chip strip (e.g. "Cần thảm").
  final String equipment;
}

const forkChoices = {
  'home': ForkChoice(
    id: 'home',
    title: 'Home Workout',
    sub: 'Sức mạnh · săn chắc',
    stat: '30+',
    statLabel: 'bài tập',
    highlights: [
      'Tăng sức mạnh và săn chắc',
      'Giữ nhịp tim, đốt năng lượng',
      'Không cần thiết bị phức tạp',
    ],
    caveats: [
      'Mục tiêu là giảm đau lưng / cổ',
      'Muốn tập trung vào sự dẻo dai, linh hoạt',
    ],
    equipment: 'Không cần thiết bị',
  ),
  'yoga': ForkChoice(
    id: 'yoga',
    title: 'Yoga',
    sub: 'Linh hoạt · thả lỏng',
    stat: '30+',
    statLabel: 'bài yoga',
    highlights: [
      'Mở khớp, tăng biên độ chuyển động',
      'Giảm căng lưng, vai và cổ',
      'Thở chậm, thả lỏng sau ngày dài',
    ],
    caveats: [
      'Tăng cơ bắp rõ rệt',
      'Đốt mỡ nhanh, tập cường độ cao',
    ],
    equipment: 'Cần thảm',
  ),
};

class ResultCandidate {
  const ResultCandidate({required this.id, required this.label});
  final String id;
  final String label;
}

/// Real single-hold metrics for the yoga assessment cards (Warrior I / Forward
/// Fold). A static hold has no per-rep series — its only real signal is the
/// clean-hold ratio. These are read from the SAME good_seconds / total_seconds
/// the scorer reads (via [YogaHoldAssessment]), so the gauge %, the headline,
/// and the suggested level always trace to one ratio and can never disagree.
class YogaHoldViz {
  const YogaHoldViz({
    required this.cleanHoldRatio,
    required this.goodSeconds,
    required this.targetSeconds,
  });

  /// good_seconds / total_seconds, clamped to [0, 1].
  final double cleanHoldRatio;
  final double goodSeconds;
  final double targetSeconds;
}

class AssessmentResultData {
  const AssessmentResultData({
    required this.id,
    required this.name,
    required this.score,
    required this.scoreUnit,
    required this.metric,
    required this.metricLabel,
    required this.chartTitle,
    required this.chartData,
    required this.chartTarget,
    required this.chartUnit,
    required this.coachTitle,
    required this.coachBody,
    required this.detectedPattern,
    required this.questionTitle,
    required this.questionSub,
    required this.candidates,
    this.lowerIsBetter = false,
    this.chartFloor,
    this.holdViz,
  });

  final String id;
  final String name;
  final int score;
  final String scoreUnit;
  final String metric;
  final String metricLabel;
  final String chartTitle;
  final List<int> chartData;
  final int chartTarget;
  final String chartUnit;
  final String coachTitle;
  final String coachBody;
  final String detectedPattern;
  final String questionTitle;
  final String questionSub;
  final List<ResultCandidate> candidates;

  /// When true, the chart inverts: lower values = taller bars, target line
  /// is the *maximum acceptable* value. Squat depth measured as knee angle
  /// uses this — 90° is the bare-minimum target, lower is deeper/better.
  final bool lowerIsBetter;

  /// Optional best-case value used as the chart's "tall bar" anchor when
  /// `lowerIsBetter` is true. Defaults to ~10° below the smallest chart
  /// data point if null.
  final int? chartFloor;

  /// Real single-hold gauge data for the yoga cards. Non-null only when a hold
  /// was actually measured — drives the radial clean-hold gauge instead of the
  /// per-rep bar chart; null renders the empty state. Home (rep) cards leave
  /// this null and keep using [chartData].
  final YogaHoldViz? holdViz;
}

const _wallPushUpDepthTarget = 110;
const _wallPushUpChartFloor = 80;
const _wallPushUpCandidates = [
  ResultCandidate(id: 'shoulder_pain', label: 'Đau vai khi đẩy'),
  ResultCandidate(id: 'wrist_discomfort', label: 'Cổ tay khó chịu'),
  ResultCandidate(id: 'shoulder_fatigue', label: 'Vai mỏi nhanh'),
  ResultCandidate(id: 'chest_tight', label: 'Cứng ngực/vai trước'),
  ResultCandidate(id: 'none', label: 'Không, ổn cả'),
];

// NOTE(LOGIC-REFINEMENT-#3): S08 Phase1 — issue candidate generation is hardcoded NASM-mapped candidates per exercise.
// Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
// See Notion: Vika State > Onboarding Logic Refinement block for full context.
// NOTE(LOGIC-REFINEMENT-#4): S08 Phase1 — coach text (`coachBody`) is hardcoded NASM references.
// Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
// See Notion: Vika State > Onboarding Logic Refinement block for full context.
const homeResultsMock = [
  AssessmentResultData(
    id: 'squat',
    name: 'Squat',
    score: 82,
    scoreUnit: '°',
    metric: 'Độ sâu trung bình',
    metricLabel: 'Đủ sâu cho người mới',
    chartTitle: 'Độ sâu qua 5 reps',
    chartData: [95, 88, 82, 78, 72],
    chartTarget: 90,
    chartUnit: '°',
    // Knee angle: lower = deeper squat = better. 90° is the bare-minimum
    // target (parallel). Below that is good. Chart inverts so deeper reps
    // get taller bars.
    lowerIsBetter: true,
    chartFloor: 60,
    coachTitle: 'Vika thấy gì?',
    coachBody:
        'Độ sâu giảm dần qua 5 reps + đầu gối có xu hướng đi vào trong khi xuống. Theo NASM đây là dấu hiệu của một trong các nguyên nhân dưới.',
    detectedPattern: 'Knee valgus + giảm độ sâu',
    questionTitle: 'Cảm giác nào đúng với bạn?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: [
      ResultCandidate(id: 'knee_pain', label: 'Đau gối khi xuống'),
      ResultCandidate(id: 'ankle_tight', label: 'Cứng cổ chân'),
      ResultCandidate(id: 'hip_tight', label: 'Cứng hông'),
      ResultCandidate(id: 'thigh_fatigue', label: 'Đùi mỏi nhanh'),
      ResultCandidate(id: 'none', label: 'Không, ổn cả'),
    ],
  ),
  AssessmentResultData(
    // NOTE: wire to Wall Push-UpInterpreter when implemented
    id: 'pushup',
    name: 'Wall Push-Up',
    score: 92,
    scoreUnit: '%',
    metric: 'Phạm vi chuyển động',
    metricLabel: 'ROM tốt',
    chartTitle: 'Phạm vi qua 5 reps',
    chartData: [100, 100, 95, 88, 80],
    chartTarget: 90,
    chartUnit: '%',
    coachTitle: 'Vika thấy gì?',
    coachBody:
        'ROM giảm 20% ở 2 reps cuối — vai có thể đang mỏi hoặc cứng cơ phía trước. Cần xác định nguyên nhân.',
    detectedPattern: 'ROM giảm dần ở vai',
    questionTitle: 'Bạn cảm thấy gì?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: _wallPushUpCandidates,
  ),
];

const yogaResultsMock = [
  AssessmentResultData(
    // NOTE: wire to Warrior IInterpreter when implemented
    id: 'warrior',
    name: 'Warrior I',
    score: 28,
    scoreUnit: 's',
    metric: 'Thời gian giữ',
    metricLabel: 'Gần đạt mức 30s',
    chartTitle: 'Độ ổn định theo thời gian',
    chartData: [85, 92, 90, 88, 80, 72, 65],
    chartTarget: 80,
    chartUnit: '%',
    coachTitle: 'Vika thấy gì?',
    coachBody:
        'Bạn giữ tư thế tốt 28s — chân vững. Vai hơi cao và lệch nhẹ về trước, độ ổn định giảm ở giây cuối. Cần xác định nguyên nhân.',
    detectedPattern: 'Vai cao + ổn định giảm cuối bài',
    questionTitle: 'Cảm giác nào đúng với bạn?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: [
      ResultCandidate(id: 'hip_pain', label: 'Đau hông trước'),
      ResultCandidate(id: 'shoulder_high', label: 'Vai bị cao/căng'),
      ResultCandidate(id: 'leg_shake', label: 'Đùi run nhiều'),
      ResultCandidate(id: 'breath', label: 'Hụt hơi'),
      ResultCandidate(id: 'none', label: 'Không, ổn cả'),
    ],
  ),
  AssessmentResultData(
    // NOTE: wire to Forward FoldInterpreter when implemented
    id: 'fold',
    name: 'Forward Fold',
    score: 78,
    scoreUnit: '°',
    metric: 'Linh hoạt hông',
    metricLabel: 'Tốt hơn 60% người mới',
    chartTitle: 'Tiến độ giãn cơ',
    chartData: [60, 65, 70, 73, 76, 78],
    chartTarget: 90,
    chartUnit: '°',
    coachTitle: 'Vika thấy gì?',
    coachBody:
        'Bạn cúi tới 78° — lưng giữ thẳng (rất tốt). Tầm cúi bị giới hạn ở gân kheo hoặc hông. Cần xác định.',
    detectedPattern: 'Tầm cúi giới hạn ở chuỗi sau',
    questionTitle: 'Bạn cảm thấy căng ở đâu?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: [
      ResultCandidate(id: 'hamstring_tight', label: 'Căng gân kheo (đùi sau)'),
      ResultCandidate(id: 'low_back_pain', label: 'Đau lưng dưới'),
      ResultCandidate(id: 'hip_tight', label: 'Cứng hông'),
      ResultCandidate(id: 'calf_tight', label: 'Cứng bắp chân'),
      ResultCandidate(id: 'none', label: 'Không, ổn cả'),
    ],
  ),
];

AssessmentResultData squatResultFromData(OnboardingData data) {
  if (!data.hasSquatAssessment) return homeResultsMock.first;

  final logger = data.squatLogger;
  final totalReps = logger.repLogs.length;
  final goodReps = (logger.setLogs['good_rep_count'] as int?) ?? 0;
  final heelFails = (logger.setLogs['heel_fails_count'] as int?) ?? 0;
  final depthFails = (logger.setLogs['depth_fails_count'] as int?) ?? 0;
  final trunkFails = (logger.setLogs['trunk_lean_fails_count'] as int?) ?? 0;
  final tempoFails = (logger.setLogs['tempo_fails_count'] as int?) ?? 0;
  final syncFails =
      (logger.setLogs['hip_shoulder_sync_fails_count'] as int?) ?? 0;
  final repRatio = totalReps == 0 ? 0.0 : goodReps / totalReps;
  final score = OnboardingAssessmentThresholds.computeFormScore(
    repRatio: repRatio,
    heelFails: heelFails,
    depthFails: depthFails,
    trunkFails: trunkFails,
    tempoFails: tempoFails,
    syncFails: syncFails,
  );

  final chart = logger.repLogs
      .map((r) => (r.data['peak_knee_angle'] as num?)?.round())
      .whereType<int>()
      .toList();
  final safeChart = chart.isEmpty ? homeResultsMock.first.chartData : chart;
  final avgDepth =
      safeChart.reduce((a, b) => a + b) / math.max(1, safeChart.length);

  final interpreter = data.squatInterpreterOrNull;
  final primary = interpreter?.getPrimaryIssueId();
  final pattern = switch (primary) {
    'ankle_mobility_restriction' => 'Nhấc gót + đổ người',
    'hip_flexor_overactivity' => 'Thân trên nghiêng nhiều',
    'limited_mobility' => 'Độ sâu chưa ổn định',
    'ankle_mobility' => 'Gót chân chưa ổn định',
    _ => homeResultsMock.first.detectedPattern,
  };

  final coachBody = switch (primary) {
    'ankle_mobility_restriction' =>
      'AI nhận thấy bạn vừa nhấc gót vừa đổ người về trước khi squat. Theo NASM đây là dấu hiệu cần kiểm tra cổ chân, hông hoặc kiểm soát thân trên.',
    'hip_flexor_overactivity' =>
      'AI nhận thấy thân trên phải nghiêng về trước khá nhiều để vào squat. Vika sẽ hỏi thêm để xác định cảm giác chính của bạn.',
    'limited_mobility' =>
      'Độ sâu squat chưa ổn định qua các rep. Vika dùng phản hồi của bạn để phân biệt giới hạn linh hoạt, mỏi cơ hay cảm giác đau.',
    'ankle_mobility' =>
      'Gót chân có xu hướng nâng lên ở một số rep. Đây có thể liên quan cổ chân, thói quen phân bổ lực hoặc độ sâu hiện tại.',
    _ => homeResultsMock.first.coachBody,
  };

  return AssessmentResultData(
    id: 'squat',
    name: 'Squat',
    score: avgDepth.round(),
    scoreUnit: '°',
    metric: 'Độ sâu trung bình',
    metricLabel: OnboardingAssessmentThresholds.scoreCaption(score),
    chartTitle: 'Độ sâu qua $totalReps reps',
    chartData: safeChart,
    chartTarget: 90,
    chartUnit: '°',
    coachTitle: 'Vika thấy gì?',
    coachBody: coachBody,
    detectedPattern: pattern,
    questionTitle: interpreter?.getQuestion()?.isNotEmpty == true
        ? 'Điểm này có đúng với bạn?'
        : 'Cảm giác nào đúng với bạn?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: homeResultsMock.first.candidates,
    lowerIsBetter: true,
    chartFloor: 60,
  );
}

AssessmentResultData wallPushUpResultFromData(OnboardingData data) {
  final logger = data.hasWallPushUpAssessment ? data.wallPushUpLogger : null;
  final totalReps = logger?.repLogs.length ?? 0;
  final completedReps =
      (logger?.setLogs['completed_reps'] as int?) ?? totalReps;
  final goodReps = (logger?.setLogs['good_rep_count'] as int?) ??
      logger?.repLogs.where((r) => r.correctForm).length ??
      0;
  final chart = logger?.repLogs
          .map((r) => (r.data['min_elbow_angle'] as num?)?.round())
          .whereType<int>()
          .toList() ??
      const <int>[];
  final safeChart = chart.isEmpty ? const [_wallPushUpDepthTarget] : chart;
  final avgDepth = chart.isEmpty
      ? _wallPushUpDepthTarget.toDouble()
      : chart.reduce((a, b) => a + b) / math.max(1, chart.length);
  final qualityLabel = completedReps == 0
      ? 'Chưa đủ dữ liệu camera'
      : '$goodReps/$completedReps reps đạt form';

  return AssessmentResultData(
    id: 'wall_push_up',
    name: 'Wall Push-Up',
    score: avgDepth.round(),
    scoreUnit: '°',
    metric: 'Độ gập khuỷu trung bình',
    metricLabel: qualityLabel,
    chartTitle: 'Độ gập khuỷu qua $totalReps reps',
    chartData: safeChart,
    chartTarget: _wallPushUpDepthTarget,
    chartUnit: '°',
    coachTitle: 'Vika ghi nhận',
    coachBody:
        'Bài Wall Push-Up đã có dữ liệu camera. Hiện chưa có bộ diễn giải lỗi cho bài này, nên Vika dùng câu trả lời của bạn ở dưới làm tín hiệu tự báo cáo.',
    detectedPattern: 'Dữ liệu Wall Push-Up',
    questionTitle: 'Bạn cảm thấy gì?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: _wallPushUpCandidates,
    lowerIsBetter: true,
    chartFloor: _wallPushUpChartFloor,
  );
}

// Warrior I / Forward Fold are single static holds: the only real per-pose
// signal is the clean-hold ratio good_seconds / total_seconds. We read it via
// the SAME [YogaHoldAssessment] the scorer uses, so the gauge, the headline, and
// the suggested level all trace to one ratio. `yogaResultsMock` is consulted
// ONLY for the real NASM self-report chips (candidates) — never for any
// chart/score/numeric value. A missing logger yields holdViz == null → the card
// renders a real empty state, never mock bars.
AssessmentResultData _yogaHoldResultFromData({
  required String id,
  required String name,
  required String questionTitle,
  required String questionSub,
  required List<ResultCandidate> candidates,
  required bool hasAssessment,
  required ExerciseLogger? logger,
}) {
  final assessment = (hasAssessment && logger != null)
      ? YogaHoldAssessment.fromLogger(logger)
      : null;
  final ratio = assessment?.cleanRatio; // null when no hold time was recorded
  final viz = (assessment != null && ratio != null)
      ? YogaHoldViz(
          cleanHoldRatio: ratio,
          goodSeconds: assessment.goodSeconds,
          targetSeconds: assessment.totalSeconds,
        )
      : null;

  return AssessmentResultData(
    id: id,
    name: name,
    score: viz == null ? 0 : viz.goodSeconds.round(),
    scoreUnit: 's',
    metric: 'Thời gian giữ sạch',
    metricLabel: viz == null
        ? 'Chưa đo được'
        : 'Giữ đúng form ${viz.goodSeconds.round()}/${viz.targetSeconds.round()}s',
    chartTitle: 'Tỉ lệ giữ sạch',
    chartData: const <int>[],
    chartTarget: 0,
    chartUnit: '%',
    coachTitle: 'Vika thấy gì?',
    coachBody: viz == null
        ? 'Chưa có dữ liệu camera cho bài này. Bạn vẫn có thể trả lời câu hỏi bên dưới để Vika cá nhân hoá lộ trình.'
        : 'Vika đo bạn giữ đúng form ${(viz.cleanHoldRatio * 100).round()}% thời gian (${viz.goodSeconds.round()}/${viz.targetSeconds.round()}s). Trả lời câu hỏi bên dưới để Vika xác định nguyên nhân.',
    detectedPattern: viz == null
        ? 'Chưa đo được'
        : viz.cleanHoldRatio >= 0.80
            ? 'Giữ tư thế ổn định'
            : viz.cleanHoldRatio >= 0.50
                ? 'Form dao động khi giữ'
                : 'Cần giữ form đều hơn',
    questionTitle: questionTitle,
    questionSub: questionSub,
    candidates: candidates,
    holdViz: viz,
  );
}

AssessmentResultData warriorOneResultFromData(OnboardingData data) {
  return _yogaHoldResultFromData(
    id: 'warrior',
    name: 'Warrior I',
    questionTitle: 'Cảm giác nào đúng với bạn?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: yogaResultsMock[0].candidates,
    hasAssessment: data.hasWarriorAssessment,
    logger: data.hasWarriorAssessment ? data.warriorLogger : null,
  );
}

AssessmentResultData seatedForwardFoldResultFromData(OnboardingData data) {
  return _yogaHoldResultFromData(
    id: 'fold',
    name: 'Forward Fold',
    questionTitle: 'Bạn cảm thấy căng ở đâu?',
    questionSub: 'Vika dùng để xác định nguyên nhân chính',
    candidates: yogaResultsMock[1].candidates,
    hasAssessment: data.hasForwardFoldAssessment,
    logger: data.hasForwardFoldAssessment ? data.forwardFoldLogger : null,
  );
}

class PlanPersonalization {
  const PlanPersonalization({
    required this.level,
    required this.levelLabel,
    required this.goal,
    required this.goalLabel,
    required this.sessions,
    required this.freq,
    required this.painAreas,
    required this.hasBackPain,
    required this.isYoga,
  });

  final String level;
  final String levelLabel;
  final String goal;
  final String goalLabel;
  final List<String> sessions;
  final int freq;
  final List<String> painAreas;
  final bool hasBackPain;
  final bool isYoga;
}

// NOTE(LOGIC-REFINEMENT-#8): S13 Outcomes — personalization logic is hand-coded if-else chains in `derivePlanPersonalization`.
// Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
// See Notion: Vika State > Onboarding Logic Refinement block for full context.
PlanPersonalization derivePlanPersonalization(OnboardingData data) {
  final level = data.level ?? 'beginner';
  final levelLabel = switch (level) {
    'advanced' => 'Nâng cao',
    'intermediate' => 'Trung cấp',
    _ => 'Người mới',
  };
  final goal = data.goal ?? 'general';
  final goalLabel = switch (goal) {
    'weight_loss' || 'body' => 'Giảm cân',
    'muscle' || 'strength' => 'Tăng cơ',
    'flexibility' || 'flexible' => 'Linh hoạt',
    'posture' => 'Tư thế',
    _ => 'Khoẻ tổng thể',
  };
  final sessions = data.scheduleSessions;
  final freq = sessions.isNotEmpty
      ? sessions.length
      : level == 'advanced'
          ? 5
          : level == 'intermediate'
              ? 4
              : 3;
  final painAreas = data.painAreas;
  final hasBackPain = painAreas.any(
    (p) => p.toLowerCase().contains('lưng') || p == 'lower_back' || p == 'back',
  );
  final isYoga = data.fork == 'yoga';
  return PlanPersonalization(
    level: level,
    levelLabel: levelLabel,
    goal: goal,
    goalLabel: goalLabel,
    sessions: sessions,
    freq: freq,
    painAreas: painAreas,
    hasBackPain: hasBackPain,
    isYoga: isYoga,
  );
}
