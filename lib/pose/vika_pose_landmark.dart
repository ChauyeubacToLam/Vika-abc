import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class VikaLandmarkConfidence {
  const VikaLandmarkConfidence({
    required this.presence,
    required this.visibility,
  });

  /// Probability that the landmark exists in the predicted skeleton.
  final double presence;

  /// Probability that the landmark is unoccluded, given that it exists.
  final double visibility;
}

final Expando<VikaLandmarkConfidence> _confidenceByLandmark =
    Expando<VikaLandmarkConfidence>('VikaLandmarkConfidence');

extension VikaPoseLandmarkConfidence on PoseLandmark {
  double get presence => _confidenceByLandmark[this]?.presence ?? likelihood;

  double get visibility =>
      _confidenceByLandmark[this]?.visibility ?? likelihood;

  void attachVikaConfidence({
    required double presence,
    required double visibility,
  }) {
    _confidenceByLandmark[this] = VikaLandmarkConfidence(
      presence: presence,
      visibility: visibility,
    );
  }
}

PoseLandmark poseLandmarkWithVikaConfidence({
  required PoseLandmarkType type,
  required double x,
  required double y,
  required double z,
  required double presence,
  required double visibility,
}) {
  final landmark = PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: z,
    likelihood: visibility,
  );
  landmark.attachVikaConfidence(
    presence: presence,
    visibility: visibility,
  );
  return landmark;
}
