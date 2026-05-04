import '../../exercise_base.dart';

enum ButterflyState { setup, stretching, isometric_hold, release }

class StretchContext {
  final double kneeSeparation;       // Khoảng cách X giữa 2 đầu gối
  final double leftKneeY;
  final double rightKneeY;
  final double ankleSeparation;      // Khoảng cách X giữa 2 mắt cá chân
  final double shoulderToHipRatio;   // Tỷ lệ Y vai-hông để tính độ gập người
  final double shoulderTilt;         // Độ nghiêng của vai
  final ButterflyState currentState;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  /// Thời gian hold hiện tại (giây) — được ButterflyStretch tính sẵn và truyền vào.
  /// Bằng 0 khi không ở trạng thái isometric_hold.
  /// Metric KHÔNG tự tính lại, chỉ đọc field này để tránh duplicate logic.
  final double currentHoldSeconds;

  StretchContext({
    required this.kneeSeparation,
    required this.leftKneeY,
    required this.rightKneeY,
    required this.ankleSeparation,
    required this.shoulderToHipRatio,
    required this.shoulderTilt,
    required this.currentState,
    required this.frameTimestamp,
    required this.resultIssues,
    this.currentHoldSeconds = 0.0,   // Default 0 — safe khi không ở hold phase
  });
}

class FaultRecord {
  final String phase;
  final String type;
  final String message;
  final bool affectsForm;
  FaultRecord({required this.phase, required this.type, required this.message, this.affectsForm = true});
}

abstract class ButterflyMetricBase {
  String get name;
  int faultsCount = 0;
  void update(StretchContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  void onStateTransition(ButterflyState from, ButterflyState to, int timestampMs) {}
}