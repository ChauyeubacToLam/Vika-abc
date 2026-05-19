// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// ═══════════════════════════════════════════════════════════════
// SURYA STATE — 12 poses in one Rep
// ═══════════════════════════════════════════════════════════════

enum SuryaState {
  p1_pranamasana,             // Cầu nguyện (đứng thẳng)
  p2_hasta_uttanasana,        // Vươn tay ngả sau
  p3_hastapaadasana,          // Gập người về trước
  p4_ashwa_sanchalanasana,    // Kỵ sĩ (chân bước sau)
  p5_parvatasana,             // Chó cúi mặt / Chữ V ngược
  p6_ashtanga_namaskara,      // Cá sấu 8 điểm
  p7_bhujangasana,            // Rắn hổ mang
  p8_parvatasana_return,      // Chó cúi mặt (lặp)
  p9_ashwa_return,            // Kỵ sĩ (bước chân lên)
  p10_hastapaadasana_return,  // Gập người (lặp)
  p11_hasta_uttanasana_return,// Vươn tay ngả sau (lặp)
  p12_pranamasana_return,     // Cầu nguyện (trở về)
}

// ═══════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════

class SuryaConfig {
  // --- General ---
  static const int MAX_REP = 5;
  static const int MAX_DURATION_MS = 300000; // 5 phút

  // --- P1/P12: Đứng thẳng ---
  static const List<double> STANDING_STRAIGHT_RANGE = [170.0, 180.0]; // Ankle-Hip-Shoulder

  // --- P2/P11: Vươn tay ngả sau ---
  static const double SPINE_EXTENSION_MAX = 44.0;           // Góc mở max cột sống
  static const double HIP_FORWARD_PUSH_THRESHOLD = 5.0;     // Hip X phải tăng ít nhất 5px

  // --- P3/P10: Gập người ---
  static const double FORWARD_FOLD_HIP_ANGLE = 80.0;        // Shoulder-Hip-Knee ≤ 80°
  static const double KNEE_STRAIGHT_MIN = 140.0;             // Gối thẳng tối thiểu

  // --- P4/P9: Kỵ sĩ ---
  static const List<double> LUNGE_KNEE_ANGLE_RANGE = [90.0, 109.0]; // Hip-Knee-Ankle chân trước
  static const double KNEE_OVER_FOOT_TOLERANCE = 0.15;              // Normalized

  // --- P5/P8: Chó cúi mặt ---
  static const List<double> V_SHAPE_ARM_ANGLE_RANGE = [165.0, 180.0]; // Wrist-Shoulder-Hip

  // --- P6: 8 điểm ---
  // Hip Y PHẢI cao hơn Shoulder Y & Knee Y (xử lý theo coordinate)

  // --- P7: Rắn hổ mang ---
  static const double COBRA_EAR_SHOULDER_MIN_RATIO = 0.25;  // earShoulderDist / scaleFactor

  // --- Transition thresholds ---
  static const double WRIST_ABOVE_NOSE_MARGIN = 10.0;       // pixels
  static const double FOLD_HIP_ANGLE_THRESHOLD = 100.0;     // Để bắt đầu nhận P3
  static const double V_SHAPE_HIP_HIGH_RATIO = 0.3;         // hipY phải cao hơn shoulder/ankle Y
}

// ═══════════════════════════════════════════════════════════════
// VOICE PRIORITY
// ═══════════════════════════════════════════════════════════════

class SuryaVoicePriority {
  static const int lumbarBreak = 0;     // Bẻ gãy thắt lưng: nghiêm trọng nhất
  static const int ashtangaHip = 0;     // Sập hông 8 điểm: nghiêm trọng
  static const int downdogSpine = 1;    // Gù lưng chó cúi mặt
  static const int cobraNeck = 1;       // Rụt cổ rắn hổ mang
  static const int lungeKneeShear = 2;  // Gối vượt chân
  static const int kneeBend = 3;        // Gối cong khi gập người (nhắc nhẹ)
  static const int symmetry = 4;        // Đối xứng (thông tin)
}

// ═══════════════════════════════════════════════════════════════
// FRAME CONTEXT — Dữ liệu mỗi frame truyền xuống metrics
// ═══════════════════════════════════════════════════════════════

class SuryaContext {
  final SuryaState state;
  final int frameTimestamp;
  final double scaleFactor;

  // --- Angles ---
  final double bodyAngle;         // Ankle-Hip-Shoulder (đứng thẳng)
  final double hipFlexionAngle;   // Shoulder-Hip-Knee (gập hông)
  final double kneeAngle;         // Hip-Knee-Ankle
  final double elbowAngle;        // Shoulder-Elbow-Wrist
  final double armShoulderAngle;  // Wrist-Shoulder-Hip (V shape)
  final double neckAngle;         // Ear-Shoulder-Hip

  // --- Y Coordinates (trục dọc) ---
  final double wristY;
  final double shoulderY;
  final double hipY;
  final double kneeY;
  final double ankleY;
  final double earY;
  final double noseY;

  // --- X Coordinates (trục ngang) ---
  final double wristX;
  final double shoulderX;
  final double hipX;
  final double kneeX;
  final double ankleX;
  final double footIndexX;

  // --- Distances ---
  final double earShoulderDist;

  final ResultIssues resultIssues;

  SuryaContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.bodyAngle,
    required this.hipFlexionAngle,
    required this.kneeAngle,
    required this.elbowAngle,
    required this.armShoulderAngle,
    required this.neckAngle,
    required this.wristY,
    required this.shoulderY,
    required this.hipY,
    required this.kneeY,
    required this.ankleY,
    required this.earY,
    required this.noseY,
    required this.wristX,
    required this.shoulderX,
    required this.hipX,
    required this.kneeX,
    required this.ankleX,
    required this.footIndexX,
    required this.earShoulderDist,
    required this.resultIssues,
  });
}

// ═══════════════════════════════════════════════════════════════
// ABSTRACT METRIC BASE
// ═══════════════════════════════════════════════════════════════

abstract class SuryaMetricBase {
  String get name;
  int faultsCount = 0;

  void update(SuryaContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(SuryaState from, SuryaState to, int timestampMs) {}
}
