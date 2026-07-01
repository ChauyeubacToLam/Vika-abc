/* =========================================================================
   Report Builder: Báo cáo sau tập Jump Squat
   Dựa trên vòng lặp: Quan sát -> Kê đơn -> Theo dõi -> Điều chỉnh
   ========================================================================= */

import 'metrics/jump_squat_metric_base.dart';

// DEAD LEGACY: bespoke score builder kept only for historical reference.
// Live reports use JumpSquatReportBuilderV2 via report_builder_registry.dart.

// Model chứa dữ liệu tổng hợp của 1 Set tập để đẩy lên UI (Detail Cards)
class JumpSquatSetReport {
  final int totalReps;
  final int safeLandingCount;
  final int perfectTakeOffCount;
  final int stableTorsoCount;

  final List<String> prescriptions; // Lời khuyên/Kê đơn sau tập

  JumpSquatSetReport({
    required this.totalReps,
    required this.safeLandingCount,
    required this.perfectTakeOffCount,
    required this.stableTorsoCount,
    required this.prescriptions,
  });

  // Điểm an toàn tiếp đất (%) - Thẻ số 1 (Quan trọng nhất)
  double get landingSafetyScore =>
      totalReps == 0 ? 0 : (safeLandingCount / totalReps) * 100;

  // Sức mạnh bùng nổ (%) - Thẻ số 2
  double get takeOffPowerScore =>
      totalReps == 0 ? 0 : (perfectTakeOffCount / totalReps) * 100;

  // Kiểm soát trọng tâm (%) - Thẻ số 3
  double get torsoStabilityScore =>
      totalReps == 0 ? 0 : (stableTorsoCount / totalReps) * 100;
}

class JumpSquatReportBuilder {
  // Lưu trữ lịch sử lỗi của từng Rep
  final List<List<FaultRecord>> _repHistory = [];

  // Hàm này được gọi mỗi khi xong 1 rep (trước khi metric bị clear)
  void recordRep(List<FaultRecord> repFaults) {
    // Copy thành một list mới để tránh bị clear tham chiếu
    _repHistory.add(List.unmodifiable(repFaults));
  }

  // Hàm build báo cáo gọi ở onSetComplete()
  JumpSquatSetReport buildReport() {
    int totalReps = _repHistory.length;
    if (totalReps == 0) {
      return JumpSquatSetReport(
          totalReps: 0,
          safeLandingCount: 0,
          perfectTakeOffCount: 0,
          stableTorsoCount: 0,
          prescriptions: []);
    }

    int stiffLandingFaults = 0;
    int shallowTakeOffFaults = 0;
    int torsoLeanFaults = 0;

    // QUAN SÁT & ĐO LƯỜNG: Quét lịch sử toàn bộ Set tập
    for (var faults in _repHistory) {
      bool hasLandingFault = faults.any((f) =>
          f.type == 'Knee' && f.affectsForm == true); // Tiếp đất chân cứng
      bool hasTakeOffFault = faults.any((f) => f.type == 'Power'); // Lấy đà cạn
      bool hasTorsoFault = faults.any((f) => f.type == 'Back'); // Úp lưng

      if (hasLandingFault) stiffLandingFaults++;
      if (hasTakeOffFault) shallowTakeOffFaults++;
      if (hasTorsoFault) torsoLeanFaults++;
    }

    // KÊ ĐƠN: Logic điều chỉnh dựa trên độ ưu tiên (Critical -> High -> Medium)
    List<String> prescriptions = [];

    // 🔴 CRITICAL: Tiếp đất thẳng chân (Nguy cơ đứt ACL)
    if (stiffLandingFaults > 0) {
      prescriptions.add(
          "🔴 NGUY HIỂM: Bạn có $stiffLandingFaults lần tiếp đất thẳng chân! Lực đang dội thẳng vào khớp gối. Điều chỉnh: Nghĩ về việc 'ngồi xuống' ngay khoảnh khắc mũi chân chạm sàn để giảm xóc.");
    }

    // 🟠 HIGH: Rạp lưng khi tiếp đất (Nguy cơ đau thắt lưng)
    if (torsoLeanFaults > 0) {
      prescriptions.add(
          "🟠 CHÚ Ý: Bạn bị rạp úp lưng quá mức trong $torsoLeanFaults nhịp. Điều chỉnh: Mở ngực, nhìn thẳng về trước khi tiếp đất để dồn tải vào đùi thay vì cột sống.");
    }

    // 🟡 MEDIUM: Lấy đà quá nông (Giảm hiệu suất bùng nổ)
    if (shallowTakeOffFaults > (totalReps * 0.3)) {
      // Báo lỗi nếu tần suất sai > 30%
      prescriptions.add(
          "🟡 HIỆU SUẤT: Nhịp lấy đà chưa đủ độ nén. Điều chỉnh: Hạ hông sâu hơn (đùi gần song song mặt sàn) trước khi bật nhảy để kích hoạt tối đa sợi cơ mông.");
    }

    // Nếu không có lỗi nào
    if (prescriptions.isEmpty) {
      prescriptions.add(
          "✅ XUẤT SẮC: Kỹ thuật Plyometric của bạn rất hoàn hảo! Khớp gối và cột sống được kiểm soát cực kỳ an toàn.");
    }

    return JumpSquatSetReport(
      totalReps: totalReps,
      safeLandingCount: totalReps - stiffLandingFaults,
      perfectTakeOffCount: totalReps - shallowTakeOffFaults,
      stableTorsoCount: totalReps - torsoLeanFaults,
      prescriptions: prescriptions,
    );
  }
}
