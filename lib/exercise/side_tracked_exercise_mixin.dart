import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_base.dart';

/// Which side of the user's body is currently being tracked.
enum TrackedSide { left, right }

/// A pair of landmark types — one per side of the body.
typedef SideLandmarkPair = ({PoseLandmarkType right, PoseLandmarkType left});

/// Adds robust camera-side selection to a side-view exercise.
///
/// Selection priority:
///   1. `cameraFacing` hint (if oriented `left` or `right`)
///   2. visibility score across required landmarks per side
///
/// Anti-flap protection:
///   - sticky tracking: keep current side unless a clearly-better candidate appears
///   - switch margin: candidate must beat current by [sideSwitchMargin] to flip
///   - tie threshold: differences smaller than [sideScoreTieThreshold] are ignored
///
/// Usage:
///   class MyExercise extends ExerciseBase with SideTrackedExerciseMixin { ... }
///
///   - Override [requiredSideLandmarks] with the landmarks the exercise needs.
///   - Override [optionalSideLandmarks] for landmarks included when visible
///     but not failing the bundle if absent (e.g. ankle on curl-up).
///   - Call [getSideTrackedLandmarks] from `checkingPose` / `checkSafety`.
mixin SideTrackedExerciseMixin on ExerciseBase {
  // ── Tunable thresholds (override per exercise if needed) ──

  double get sideScoreTieThreshold => 0.2;
  double get sideSwitchMargin => 0.75;

  // ── Per-exercise abstract members ──

  /// Slot name → (right type, left type). All entries are REQUIRED.
  Map<String, SideLandmarkPair> get requiredSideLandmarks;

  /// Optional landmarks: included when visible on the chosen side, absent OK.
  Map<String, SideLandmarkPair> get optionalSideLandmarks => const {};

  // ── Internal tracking state ──

  TrackedSide? _trackedSide;
  double _lastLeftSideScore = 0.0;
  double _lastRightSideScore = 0.0;
  String _lastTrackedSideSource = 'visibility';

  // ── Debug accessors ──

  TrackedSide? get trackedSide => _trackedSide;
  double get lastLeftSideScore => _lastLeftSideScore;
  double get lastRightSideScore => _lastRightSideScore;
  String get lastTrackedSideSource => _lastTrackedSideSource;

  // ── Public API ──

  /// Resolves the camera-facing side and returns the landmark bundle.
  /// Returns null if neither side has all required landmarks.
  Map<String, PoseLandmark>? getSideTrackedLandmarks(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final preferredSide = _resolveTrackedSide(landmarks);
    final preferred = _buildBundleForSide(landmarks, preferredSide);
    if (preferred != null) {
      _trackedSide = preferredSide;
      return preferred;
    }

    final fallbackSide = preferredSide == TrackedSide.right
        ? TrackedSide.left
        : TrackedSide.right;
    final fallback = _buildBundleForSide(landmarks, fallbackSide);
    if (fallback != null) {
      _trackedSide = fallbackSide;
      return fallback;
    }

    return null;
  }

  // ── Internal helpers ──

  TrackedSide _resolveTrackedSide(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftScore = _scoreSideVisibility(landmarks, side: TrackedSide.left);
    final rightScore = _scoreSideVisibility(landmarks, side: TrackedSide.right);

    _lastLeftSideScore = leftScore;
    _lastRightSideScore = rightScore;

    final orientationSide = switch (cameraFacing) {
      CameraFacing.left => TrackedSide.left,
      CameraFacing.right => TrackedSide.right,
      _ => null,
    };
    if (orientationSide != null) {
      _lastTrackedSideSource = 'cameraFacing';
      _trackedSide = orientationSide;
      return orientationSide;
    }

    final candidate = _pickSideCandidate(
      leftScore: leftScore,
      rightScore: rightScore,
      fallback: _trackedSide,
    );
    _lastTrackedSideSource = 'visibility';

    if (_trackedSide == null) {
      _trackedSide = candidate;
      return candidate;
    }

    if (_trackedSide == candidate) return candidate;

    final currentScore =
        _trackedSide == TrackedSide.right ? rightScore : leftScore;
    final candidateScore =
        candidate == TrackedSide.right ? rightScore : leftScore;

    if (candidateScore >= currentScore + sideSwitchMargin) {
      _trackedSide = candidate;
    }

    return _trackedSide!;
  }

  TrackedSide _pickSideCandidate({
    required double leftScore,
    required double rightScore,
    TrackedSide? fallback,
  }) {
    if ((rightScore - leftScore).abs() <= sideScoreTieThreshold &&
        fallback != null) {
      return fallback;
    }
    if (rightScore == 0 && leftScore == 0) {
      return fallback ?? TrackedSide.left;
    }
    return rightScore >= leftScore ? TrackedSide.right : TrackedSide.left;
  }

  double _scoreSideVisibility(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    required TrackedSide side,
  }) {
    final isRight = side == TrackedSide.right;
    var score = 0.0;
    for (final pair in requiredSideLandmarks.values) {
      final type = isRight ? pair.right : pair.left;
      final lm = landmarks[type];
      if (lm == null) continue;
      if (!ExerciseBase.isLandmarkConfident(lm)) continue;
      score += 0.25 + (lm.likelihood.clamp(0.0, 1.0) as num).toDouble();
    }
    return score;
  }

  Map<String, PoseLandmark>? _buildBundleForSide(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    TrackedSide side,
  ) {
    final isRight = side == TrackedSide.right;
    final result = <String, PoseLandmark>{};

    for (final entry in requiredSideLandmarks.entries) {
      final type = isRight ? entry.value.right : entry.value.left;
      final lm = landmarks[type];
      if (lm == null) return null;
      if (!ExerciseBase.isLandmarkConfident(lm)) return null;
      result[entry.key] = lm;
    }

    for (final entry in optionalSideLandmarks.entries) {
      final type = isRight ? entry.value.right : entry.value.left;
      final lm = landmarks[type];
      if (lm != null && ExerciseBase.isLandmarkConfident(lm)) {
        result[entry.key] = lm;
      }
    }

    return result;
  }
}
