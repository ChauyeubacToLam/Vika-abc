// ignore_for_file: constant_identifier_names

import '../side_plank_dip.dart';
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum SidePlankState {
  basePlank,   // Chuẩn bị, hông cao
  descending,  // Đang hạ hông
  bottom,      // Đáy
  ascending,   // Đang nâng hông
  top          // Đỉnh điểm (Hoàn thành 1 Rep)
}

/* =========================================================================
   RepContext — Shared per-frame state cho Side Plank Dip
   ========================================================================= */
class RepContext {
  /// Góc Vai-Hông-Mắt cá của bên nằm dưới (đo biên độ nâng hạ)
  final double bodyAngle;

  /// Khoảng cách ngang (trục X) giữa Vai và Khuỷu tay trụ (Tính độ lệch)
  final double shoulderElbowOffsetX;

  /// Độ rộng vai (khoảng cách X giữa 2 vai) - Dùng để đo vặn mình
  final double shoulderWidthX;

  /// Độ rộng hông (khoảng cách X giữa 2 hông) - Dùng để đo vặn mình
  final double hipWidthX;

  /// Tọa độ Y của Hông trụ (Hông dưới sàn) - Dùng cho State Machine
  final double lowerHipY;

  final SidePlankState plankState;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RepContext({
    required this.bodyAngle,
    required this.shoulderElbowOffsetX,
    required this.shoulderWidthX,
    required this.hipWidthX,
    required this.lowerHipY,
    required this.plankState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class SidePlankDipMetricBase {
  String get name;
  void update(RepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void onStateTransition(SidePlankState from, SidePlankState to, int timestampMs) {}
}