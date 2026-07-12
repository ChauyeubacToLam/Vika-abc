/* =========================================================================
   Report Builder: Phân tích chỉ số Cardio & An toàn Cột sống
   ========================================================================= */

import '../metrics/step_back_burpee_metric_base.dart';

// DEAD LEGACY: bespoke score builder kept only for historical reference.
// Live reports use StepBackBurpeeReportBuilderV2 via report_builder_registry.dart.

class BurpeeSetReport {
  final int totalReps;
  final double spineSafetyScore;
  final double plankExtensionScore;
  final double repsPerMinute; // Pace
  final List<String> prescriptions;

  BurpeeSetReport({
    required this.totalReps,
    required this.spineSafetyScore,
    required this.plankExtensionScore,
    required this.repsPerMinute,
    required this.prescriptions,
  });
}

class StepBackBurpeeReportBuilder {
  final List<List<FaultRecord>> _repHistory = [];

  void recordRep(List<FaultRecord> repFaults, int timestampMs) {
    _repHistory.add(List.unmodifiable(repFaults));
  }

  BurpeeSetReport buildReport(int startTimeMs, int endTimeMs) {
    int totalReps = _repHistory.length;

    if (totalReps == 0) {
      return BurpeeSetReport(
          totalReps: 0,
          spineSafetyScore: 0,
          plankExtensionScore: 0,
          repsPerMinute: 0,
          prescriptions: []);
    }

    int spineFaultReps =
        0; // Đếm số Rep vi phạm 1 trong 2 lỗi cột sống (Cúi cong lưng hoặc Võng Plank)
    int shortStepFaultReps = 0;

    for (var faults in _repHistory) {
      bool hasSpineFault = faults.any(
        (f) => f.type == 'squat_hinge' || f.type == 'plank_sag',
      );
      bool hasAmplitudeFault = faults.any((f) => f.type == 'plank_extension');

      if (hasSpineFault) spineFaultReps++;
      if (hasAmplitudeFault) shortStepFaultReps++;
    }

    // Tính toán tỷ lệ %
    double spineSafetyScore = ((totalReps - spineFaultReps) / totalReps) * 100;
    double plankExtensionScore =
        ((totalReps - shortStepFaultReps) / totalReps) * 100;

    // Tính toán Pace (Reps/min)
    double durationMinutes = (endTimeMs - startTimeMs) / 60000.0;
    double rpm = durationMinutes > 0 ? (totalReps / durationMinutes) : 0;

    // KÊ ĐƠN Y KHOA VÀ THỂ LỰC
    List<String> prescriptions = [];

    if (spineFaultReps > 0) {
      prescriptions.add(
          "🔴 AN TOÀN CỘT SỐNG: Bạn có $spineFaultReps nhịp làm cột sống chịu áp lực xấu. Điều chỉnh: Khi hạ người, hãy chùng gối như đang ngồi xổm (Squat). Khi Plank, gồng cứng cơ bụng để Hông không rớt.");
    }

    if (plankExtensionScore < 70) {
      prescriptions.add(
          "🟡 BIÊN ĐỘ: Động tác của bạn hơi 'tù'. Hãy dứt khoát bước dài chân ra sau để kéo giãn toàn bộ cơ thể thay vì co cụm.");
    }

    if (rpm < 10) {
      // Dưới 10 reps/phút là rất chậm với cardio
      prescriptions.add(
          "🔵 NHỊP ĐỘ: Tốc độ hiện tại của bạn là ${rpm.toStringAsFixed(1)} reps/phút. Tập trung giữ form, khi thể lực tốt hơn, hãy cố gắng tăng tốc để đốt mỡ hiệu quả hơn.");
    } else {
      prescriptions.add(
          "🔥 NHỊP ĐỘ: Tuyệt vời! Bạn đang duy trì tốc độ Cardio rất tốt.");
    }

    if (spineSafetyScore == 100 && plankExtensionScore == 100) {
      prescriptions.insert(0,
          "✅ XUẤT SẮC: Form tập của bạn chuẩn mực! Vừa an toàn cho xương khớp vừa đạt hiệu suất tối đa.");
    }

    return BurpeeSetReport(
      totalReps: totalReps,
      spineSafetyScore: spineSafetyScore,
      plankExtensionScore: plankExtensionScore,
      repsPerMinute: rpm,
      prescriptions: prescriptions,
    );
  }
}
