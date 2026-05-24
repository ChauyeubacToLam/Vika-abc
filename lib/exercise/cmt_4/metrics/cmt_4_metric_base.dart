// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SURYA STATE â€” 12 poses in one Rep
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

enum Cmt4State {
  p1_pranamasana,             // Cáº§u nguyá»‡n (Ä‘á»©ng tháº³ng)
  p2_hasta_uttanasana,        // VÆ°Æ¡n tay ngáº£ sau
  p3_hastapaadasana,          // Gáº­p ngÆ°á»i vá» trÆ°á»›c
  p4_ashwa_sanchalanasana,    // Ká»µ sÄ© (chÃ¢n bÆ°á»›c sau)
  p5_parvatasana,             // ChÃ³ cÃºi máº·t / Chá»¯ V ngÆ°á»£c
  p6_ashtanga_namaskara,      // CÃ¡ sáº¥u 8 Ä‘iá»ƒm
  p7_bhujangasana,            // Ráº¯n há»• mang
  p8_parvatasana_return,      // ChÃ³ cÃºi máº·t (láº·p)
  p9_ashwa_return,            // Ká»µ sÄ© (bÆ°á»›c chÃ¢n lÃªn)
  p10_hastapaadasana_return,  // Gáº­p ngÆ°á»i (láº·p)
  p11_hasta_uttanasana_return,// VÆ°Æ¡n tay ngáº£ sau (láº·p)
  p12_pranamasana_return,     // Cáº§u nguyá»‡n (trá»Ÿ vá»)
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CONFIG
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class Cmt4Config {
  // --- General ---
  static const int MAX_REP = 5;
  static const int MAX_DURATION_MS = 300000; // 5 phÃºt

  // --- P1/P12: Äá»©ng tháº³ng ---
  static const List<double> STANDING_STRAIGHT_RANGE = [170.0, 180.0]; // Ankle-Hip-Shoulder

  // --- P2/P11: VÆ°Æ¡n tay ngáº£ sau ---
  static const double SPINE_EXTENSION_MAX = 44.0;           // GÃ³c má»Ÿ max cá»™t sá»‘ng
  static const double HIP_FORWARD_PUSH_THRESHOLD = 5.0;     // Hip X pháº£i tÄƒng Ã­t nháº¥t 5px

  // --- P3/P10: Gáº­p ngÆ°á»i ---
  static const double FORWARD_FOLD_HIP_ANGLE = 80.0;        // Shoulder-Hip-Knee â‰¤ 80Â°
  static const double KNEE_STRAIGHT_MIN = 140.0;             // Gá»‘i tháº³ng tá»‘i thiá»ƒu

  // --- P4/P9: Ká»µ sÄ© ---
  static const List<double> LUNGE_KNEE_ANGLE_RANGE = [90.0, 109.0]; // Hip-Knee-Ankle chÃ¢n trÆ°á»›c
  static const double KNEE_OVER_FOOT_TOLERANCE = 0.15;              // Normalized

  // --- P5/P8: ChÃ³ cÃºi máº·t ---
  static const List<double> V_SHAPE_ARM_ANGLE_RANGE = [165.0, 180.0]; // Wrist-Shoulder-Hip

  // --- P6: 8 Ä‘iá»ƒm ---
  // Hip Y PHáº¢I cao hÆ¡n Shoulder Y & Knee Y (xá»­ lÃ½ theo coordinate)

  // --- P7: Ráº¯n há»• mang ---
  static const double COBRA_EAR_SHOULDER_MIN_RATIO = 0.25;  // earShoulderDist / scaleFactor

  // --- Transition thresholds ---
  static const double WRIST_ABOVE_NOSE_MARGIN = 10.0;       // pixels
  static const double FOLD_HIP_ANGLE_THRESHOLD = 100.0;     // Äá»ƒ báº¯t Ä‘áº§u nháº­n P3
  static const double V_SHAPE_HIP_HIGH_RATIO = 0.3;         // hipY pháº£i cao hÆ¡n shoulder/ankle Y
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// VOICE PRIORITY
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class SuryaVoicePriority {
  static const int lumbarBreak = 0;     // Báº» gÃ£y tháº¯t lÆ°ng: nghiÃªm trá»ng nháº¥t
  static const int ashtangaHip = 0;     // Sáº­p hÃ´ng 8 Ä‘iá»ƒm: nghiÃªm trá»ng
  static const int downdogSpine = 1;    // GÃ¹ lÆ°ng chÃ³ cÃºi máº·t
  static const int cobraNeck = 1;       // Rá»¥t cá»• ráº¯n há»• mang
  static const int lungeKneeShear = 2;  // Gá»‘i vÆ°á»£t chÃ¢n
  static const int kneeBend = 3;        // Gá»‘i cong khi gáº­p ngÆ°á»i (nháº¯c nháº¹)
  static const int symmetry = 4;        // Äá»‘i xá»©ng (thÃ´ng tin)
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// FRAME CONTEXT â€” Dá»¯ liá»‡u má»—i frame truyá»n xuá»‘ng metrics
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class Cmt4Context {
  final Cmt4State state;
  final int frameTimestamp;
  final double scaleFactor;

  // --- Angles ---
  final double bodyAngle;         // Ankle-Hip-Shoulder (Ä‘á»©ng tháº³ng)
  final double hipFlexionAngle;   // Shoulder-Hip-Knee (gáº­p hÃ´ng)
  final double kneeAngle;         // Hip-Knee-Ankle
  final double elbowAngle;        // Shoulder-Elbow-Wrist
  final double armShoulderAngle;  // Wrist-Shoulder-Hip (V shape)
  final double neckAngle;         // Ear-Shoulder-Hip

  // --- Y Coordinates (trá»¥c dá»c) ---
  final double wristY;
  final double shoulderY;
  final double hipY;
  final double kneeY;
  final double ankleY;
  final double earY;
  final double noseY;

  // --- X Coordinates (trá»¥c ngang) ---
  final double wristX;
  final double shoulderX;
  final double hipX;
  final double kneeX;
  final double ankleX;
  final double footIndexX;

  // --- Distances ---
  final double earShoulderDist;

  final ResultIssues resultIssues;

  Cmt4Context({
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ABSTRACT METRIC BASE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

abstract class Cmt4MetricBase {
  String get name;
  int faultsCount = 0;

  void update(Cmt4Context ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(Cmt4State from, Cmt4State to, int timestampMs) {}
}

