// lib/screens/onboarding/v5/fork_recommendation.dart
import '../onboarding_data.dart';

class ForkRecommendation {
  const ForkRecommendation({
    required this.fork,
    required this.confidence,
    required this.rawScore,
    required this.reason,
    required this.dominantSignal,
    required this.signalContributions,
  });

  final String fork;
  final double confidence;
  final double rawScore;
  final String reason;
  final String dominantSignal;
  final Map<String, double> signalContributions;
}

// ── Weights ─────────────────────────────────────────────────────
const double _wGoal = 0.40;
const double _wPain = 0.35;
const double _wWhy = 0.20;
const double _wDuration = 0.05;

// ── Decision thresholds ─────────────────────────────────────────
const double _threshold = 0.15;
const double _confidenceDivisor = 0.50;

// Sign convention: positive = yoga, negative = home
// Default on tie/below-threshold: home (broader-fit modality)

ForkRecommendation recommendFork(OnboardingData data) {
  final goalScore = _scoreGoal(data.goal);
  final painScore = _scorePain(data.painAreas);
  final whyScore = _scoreWhy(data.whyStep1);
  final durationScore = _scoreDuration(data.trainingDuration);

  final contributions = <String, double>{
    'goal': goalScore * _wGoal,
    'pain': painScore * _wPain,
    'why': whyScore * _wWhy,
    'duration': durationScore * _wDuration,
  };

  final rawScore = contributions.values.fold<double>(0, (a, b) => a + b);
  final fork = _pickFork(rawScore);
  final confidence = _confidence(rawScore);
  final dominantSignal = _dominantSignal(contributions);
  final reason = _generateReason(dominantSignal, fork, data);

  return ForkRecommendation(
    fork: fork,
    confidence: confidence,
    rawScore: rawScore,
    reason: reason,
    dominantSignal: dominantSignal,
    signalContributions: contributions,
  );
}

// ── Per-signal scoring ──────────────────────────────────────────

double _scoreGoal(String? goal) {
  switch (goal) {
    case 'flexible':
      return 1.0;
    case 'health':
      return 0.0;
    case 'body':
      return -0.7;
    case 'strength':
      return -1.0;
    default:
      return 0.0;
  }
}

/// Take MAX SIGNED across pain areas (not sum) so multiple pain areas
/// don't double-count. "Max signed" means the value furthest from zero
/// in its own direction wins.
double _scorePain(List<String> painAreas) {
  if (painAreas.isEmpty) return 0.0;

  const painScores = {
    'back': 0.8,
    'neck': 0.7,
    'hip': 0.5,
    'knee': 0.3,
    'other': 0.1,
    'wrist': -0.5,
  };

  double maxPositive = 0.0;
  double minNegative = 0.0;
  for (final area in painAreas) {
    final score = painScores[area] ?? 0.0;
    if (score > maxPositive) maxPositive = score;
    if (score < minNegative) minNegative = score;
  }

  // If both directions have a hit, return the one with larger magnitude.
  // E.g. back (+0.8) + wrist (-0.5) → +0.8 (back wins).
  return maxPositive.abs() >= minNegative.abs() ? maxPositive : minNegative;
}

double _scoreWhy(String? why) {
  switch (why) {
    case 'pain':
      return 0.5;
    case 'health':
      return -0.1;
    case 'energy':
      return 0.0;
    case 'confidence':
      return -0.4;
    default:
      return 0.0;
  }
}

double _scoreDuration(String? duration) {
  switch (duration) {
    case '<3m':
      return 0.15;
    case '3-11m':
      return 0.0;
    case '1y+':
      return 0.0;
    default:
      return 0.0;
  }
}

// ── Decision helpers ────────────────────────────────────────────

String _pickFork(double rawScore) {
  if (rawScore > _threshold) return 'yoga';
  if (rawScore < -_threshold) return 'home';
  return 'home'; // default on weak signal
}

double _confidence(double rawScore) {
  return (rawScore.abs() / _confidenceDivisor).clamp(0.0, 1.0);
}

String _dominantSignal(Map<String, double> contributions) {
  String dominant = 'none';
  double maxMagnitude = 0.0;
  contributions.forEach((key, value) {
    if (value.abs() > maxMagnitude) {
      maxMagnitude = value.abs();
      dominant = key;
    }
  });
  return maxMagnitude > 0.0 ? dominant : 'none';
}

// ── Reason generator ────────────────────────────────────────────

String _generateReason(
    String dominantSignal, String fork, OnboardingData data) {
  switch (dominantSignal) {
    case 'goal':
      return _reasonFromGoal(data.goal);
    case 'pain':
      return _reasonFromPain(data.painAreas, fork);
    case 'why':
      return _reasonFromWhy(data.whyStep1);
    case 'duration':
      return 'Vì bạn mới bắt đầu, yoga là điểm khởi đầu an toàn';
    default:
      return 'Dựa trên tổng hợp lựa chọn của bạn';
  }
}

String _reasonFromGoal(String? goal) {
  switch (goal) {
    case 'flexible':
      return 'Vì bạn muốn cải thiện linh hoạt';
    case 'body':
      return 'Vì bạn muốn cải thiện vóc dáng';
    case 'strength':
      return 'Vì bạn muốn tăng sức mạnh và cơ bắp';
    case 'health':
      return 'Vì bạn ưu tiên sức khoẻ tổng thể';
    default:
      return 'Dựa trên lựa chọn của bạn';
  }
}

/// Picks the highest-magnitude pain area to anchor the reason on,
/// then maps to a sentence appropriate for the resulting fork.
String _reasonFromPain(List<String> painAreas, String fork) {
  if (painAreas.isEmpty) return 'Dựa trên lựa chọn của bạn';

  const dominantOrder = ['back', 'neck', 'hip', 'wrist', 'knee', 'other'];
  String? dominant;
  for (final candidate in dominantOrder) {
    if (painAreas.contains(candidate)) {
      dominant = candidate;
      break;
    }
  }

  switch (dominant) {
    case 'back':
      return 'Yoga có bằng chứng mạnh nhất cho giảm đau lưng';
    case 'neck':
      return 'Yoga giúp giảm đau cổ vai do ngồi nhiều';
    case 'hip':
      return 'Yoga cải thiện linh hoạt khớp hông';
    case 'knee':
      return 'Yoga có lực tác động nhẹ, an toàn cho đầu gối';
    case 'wrist':
      return 'Tại nhà ít chịu lực cổ tay hơn yoga';
    case 'other':
      return 'Yoga có cường độ nhẹ khi cơ thể đang nhạy cảm';
    default:
      return 'Dựa trên lựa chọn của bạn';
  }
}

String _reasonFromWhy(String? why) {
  switch (why) {
    case 'pain':
      return 'Vì giảm đau là ưu tiên của bạn';
    case 'confidence':
      return 'Vì bạn muốn thấy thay đổi rõ rệt về vóc dáng';
    case 'health':
      return 'Vì bạn muốn khoẻ mạnh lâu dài';
    case 'energy':
      return 'Vì bạn muốn nhiều năng lượng hơn cho cả ngày';
    default:
      return 'Dựa trên lựa chọn của bạn';
  }
}
