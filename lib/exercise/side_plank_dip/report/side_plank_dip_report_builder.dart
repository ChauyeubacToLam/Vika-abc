/* =========================================================================
   Report Builder: Phân tích chỉ số an toàn Đai vai và Lõi (Core)
   ========================================================================= */

import '../metrics/side_plank_dip_metric_base.dart';

class SidePlankSetReport {
  final int totalReps;
  final double shoulderSafetyScore;
  final double antiRotationScore;
  final double dipDepthScore;
  final List<String> prescriptions;

  SidePlankSetReport({
    required this.totalReps,
    required this.shoulderSafetyScore,
    required this.antiRotationScore,
    required this.dipDepthScore,
    required this.prescriptions,
  });
}

class SidePlankDipReportBuilder {
  final List<List<FaultRecord>> _repHistory = [];
  
  void recordRep(List<FaultRecord> repFaults) {
    _repHistory.add(List.unmodifiable(repFaults));
  }

  SidePlankSetReport buildReport(int startTimeMs, int endTimeMs) {
    int totalReps = _repHistory.length;
    if (totalReps == 0) {
      return SidePlankSetReport(totalReps: 0, shoulderSafetyScore: 0, antiRotationScore: 0, dipDepthScore: 0, prescriptions: []);
    }

    int shoulderFaults = 0;
    int rotationFaults = 0;
    int shallowFaults = 0;

    for (var faults in _repHistory) {
      if (faults.any((f) => f.type == 'Shoulder')) shoulderFaults++;
      if (faults.any((f) => f.type == 'Core')) rotationFaults++;
      if (faults.any((f) => f.type == 'Amplitude')) shallowFaults++;
    }

    double shoulderScore = ((totalReps - shoulderFaults) / totalReps) * 100;
    double rotationScore = ((totalReps - rotationFaults) / totalReps) * 100;
    double depthScore = ((totalReps - shallowFaults) / totalReps) * 100;

    List<String> prescriptions = [];

    if (shoulderFaults > 0) {
      prescriptions.add("🔴 KHỚP VAI (CRITICAL): Khuỷu tay của bạn bị lệch trục trong $shoulderFaults nhịp. Điều này tạo lực cắt cực mạnh lên chóp xoay. LUÔN LUÔN căn chỉnh khuỷu tay vuông góc chính xác dưới vai trước khi bắt đầu.");
    }

    if (rotationFaults > 0) {
      prescriptions.add("🔴 CỘT SỐNG (CRITICAL): Bạn bị mất kiểm soát, đổ người về trước/sau. Khi tập, hãy tưởng tượng lưng bạn đang tựa phẳng vào một bức tường.");
    }

    if (depthScore < 60) {
      prescriptions.add("🟡 BIÊN ĐỘ: Nhịp Dip (hạ hông) của bạn chỉ mang tính nhấp nháy. Để cơ liên sườn phát triển, hãy hạ hông xuống sát mặt sàn rồi dùng lực mông đẩy mạnh lên.");
    }

    if (prescriptions.isEmpty) {
      prescriptions.add("✅ HOÀN HẢO: Bạn kiểm soát tư thế Side Plank xuất sắc! Khớp vai và cột sống được bảo vệ tuyệt đối.");
    }

    return SidePlankSetReport(
      totalReps: totalReps,
      shoulderSafetyScore: shoulderScore,
      antiRotationScore: rotationScore,
      dipDepthScore: depthScore,
      prescriptions: prescriptions,
    );
  }
}