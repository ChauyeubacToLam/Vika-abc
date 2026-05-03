import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/frame_snapshot.dart';
import '../exercise_base.dart';
import 'metrics/butterfly_metric_base.dart';

class ButterflyConfig {
  static const int TARGET_HOLD_SECONDS = 30;
  static const double MAX_ANKLE_SEPARATION_NORM = 0.2; 
  
  // TĂNG MẠNH NGƯỠNG ỔN ĐỊNH: Chấp nhận dao động dưới 4.0 pixel vẫn tính là đang Hold
  static const double HOLD_STABILITY_THRESHOLD = 4.0; 
  
  // Gối ép xuống > 3.0 pixel thì tính là đang Stretching
  static const double STRETCH_THRESHOLD = 3.0;
  
  // Gối nhấc lên < -4.0 pixel (âm) thì mới tính là Release (Thả lỏng)
  static const double RELEASE_THRESHOLD = -4.0; 
}

class ButterflyStretch extends ExerciseBase {
  ButterflyState stretchState = ButterflyState.setup;
  ButterflyState previousState = ButterflyState.setup;
  
  // Biến đếm tổng thời gian hold hợp lệ
  double totalValidHoldTime = 0.0; 

  // Khi nào hoàn thiện các file metrics, hãy bỏ comment các dòng dưới
  // final KneeSeparationMetric kneeMetric = KneeSeparationMetric();
  // final PostureMetric postureMetric = PostureMetric();
  // final HoldDurationMetric holdMetric = HoldDurationMetric();
  
  late final List<ButterflyMetricBase> _metrics = [
    // kneeMetric, postureMetric, holdMetric
  ];

  final Debouncer _holdDebouncer = Debouncer(requiredFrames: 10); // ~0.3s ổn định thì coi là hold
  final Debouncer _releaseDebouncer = Debouncer(requiredFrames: 5);

  @override
  String get exerciseName => 'Butterfly Stretch';

  @override
  String get currentPhaseKey => stretchState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (stretchState) {
      case ButterflyState.setup: return 'Chuẩn bị';
      case ButterflyState.stretching: return 'Đang ép';
      case ButterflyState.isometric_hold: return 'Giữ nguyên!';
      case ButterflyState.release: return 'Thả lỏng';
    }
  }

  // --- Điều kiện bắt đầu ---
 // --- Điều kiện bắt đầu (Đã tinh chỉnh cho ML Kit) ---
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;

    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];

    // Chấp nhận rủi ro: Mắt cá chân có thể bị che khuất, nên chỉ cần lấy được tọa độ, không cần likelihood quá cao
    if (lKnee == null || rKnee == null || lAnkle == null || rAnkle == null || lShoulder == null || rShoulder == null) return false;

    // 1. Khoảng cách VAI (Dùng làm mốc chuẩn thay vì hông vì hông lúc ngồi trực diện rất khó đo)
    double shoulderDist = (lShoulder.x - rShoulder.x).abs();
    if (shoulderDist < 10) return false; // Tránh lỗi chia cho 0

    // 2. Hai mắt cá chân gần nhau
    // Nới lỏng: Chấp nhận khoảng cách mắt cá lên tới 60% chiều rộng vai (vì ML Kit đo mắt cá ngoài)
    double ankleDist = (lAnkle.x - rAnkle.x).abs();
    if ((ankleDist / shoulderDist) > 0.6) return false;

    // 3. Hai gối mở rộng (Dấu hiệu đặc trưng của Butterfly Stretch)
    // Đầu gối phải mở rộng hơn ít nhất 80% chiều rộng của vai
    double kneeDist = (lKnee.x - rKnee.x).abs();
    if (kneeDist < shoulderDist * 0.8) return false;

    return true; // Pass hết thì cho tập!
  }

  @override
  bool requestStop() => totalValidHoldTime >= ButterflyConfig.TARGET_HOLD_SECONDS;

  @override
  void onSetComplete() {
    // Log dữ liệu cho Report Builder (Mở comment khi đã gắn Metrics)
    // logger.pushKey("total_hold_time", totalValidHoldTime);
    // logger.pushMax("max_knee_separation", "max_separation");
    // logger.pushKey("posture_fails_count", postureMetric.faultsCount);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return "Vui lòng đặt điện thoại chính diện.";
    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final lKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final rKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final lAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lHip = smoothedLandmarks[PoseLandmarkType.leftHip];

    if (lKnee == null || rKnee == null || lAnkle == null || rAnkle == null || lShoulder == null || rShoulder == null || lHip == null) return;

    double kneeSep = (lKnee.x - rKnee.x).abs();
    double ankleSep = (lAnkle.x - rAnkle.x).abs();
    double avgKneeY = (lKnee.y + rKnee.y) / 2;
    double avgShoulderY = (lShoulder.y + rShoulder.y) / 2;
    double torsoHeight = (avgShoulderY - lHip.y).abs();
    
    final now = frameTimestampMs;

    final ctx = StretchContext(
      kneeSeparation: kneeSep,
      leftKneeY: lKnee.y,
      rightKneeY: rKnee.y,
      ankleSeparation: ankleSep,
      shoulderToHipRatio: torsoHeight, 
      shoulderTilt: (lShoulder.y - rShoulder.y).abs(),
      currentState: stretchState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    frameBuffer.addFrame(FrameSnapshot(log: {"avgKneeY": avgKneeY, "kneeSep": kneeSep}, timeStamp: now));
    _updateStateBuffer(avgKneeY, kneeSep, now);

    if (stretchState != ButterflyState.setup) {
      for (final metric in _metrics) {
        metric.update(ctx);
        debugData.addAll(metric.debugData);
      }
    }
    
    _updatePhaseInstructions();
  }

 void _updateStateBuffer(double avgKneeY, double kneeSep, int timestampMs) {
    // 1. Tính biến thiên Y của gối trong tối đa 10 frame gần nhất
    double yChange = 0.0;
    final buffer = frameBuffer.frameBuffer;
    if (buffer.length >= 2) {
      int lookback = buffer.length > 10 ? 10 : buffer.length - 1;
      double currentY = buffer.last.log["avgKneeY"] ?? 0.0;
      double pastY = buffer[buffer.length - 1 - lookback].log["avgKneeY"] ?? 0.0;
      yChange = currentY - pastY;
    }

    // 2. Logic chuyển pha (State Machine)
    
    // Đang Setup -> Ép xuống (yChange dương và đủ lớn)
    if (stretchState == ButterflyState.setup && yChange > ButterflyConfig.STRETCH_THRESHOLD) { 
      _transitionState(ButterflyState.stretching, timestampMs);
    } 
    // Đang Ép/Thả lỏng -> Chuyển sang Hold khi gối dừng lại (dao động nhỏ hơn 4.0 pixel)
    else if ((stretchState == ButterflyState.stretching || stretchState == ButterflyState.release) && 
             _holdDebouncer.update(yChange.abs() < ButterflyConfig.HOLD_STABILITY_THRESHOLD)) {
      _transitionState(ButterflyState.isometric_hold, timestampMs);
    }
    // Đang Hold -> Chuyển sang Thả lỏng nếu gối thực sự bị nhấc lên mạnh (yChange âm và vượt ngưỡng)
    else if (stretchState == ButterflyState.isometric_hold && 
             _releaseDebouncer.update(yChange < ButterflyConfig.RELEASE_THRESHOLD)) { 
      _transitionState(ButterflyState.release, timestampMs);
    }
  }

  void _transitionState(ButterflyState newState, int timestampMs) {
    if (newState == stretchState) return;
    previousState = stretchState;
    stretchState = newState;

    for (final metric in _metrics) {
      metric.onStateTransition(previousState, newState, timestampMs);
    }
  }

  void _updatePhaseInstructions() {
    switch (stretchState) {
      case ButterflyState.setup:
        resultIssues.addInstruction('setup', 'Trạng thái', 'Chụm hai lòng bàn chân');
        break;
      case ButterflyState.stretching:
        resultIssues.addInstruction('stretching', 'Trạng thái', 'Ép gối xuống từ từ');
        break;
      case ButterflyState.isometric_hold:
        resultIssues.addInstruction('hold', 'Trạng thái', 'Giữ nguyên ở đây!');
        break;
      case ButterflyState.release:
        resultIssues.addInstruction('release', 'Trạng thái', 'Thả lỏng');
        break;
    }
  }
}