// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Warrior I Metric: Back Straightness (Spine Alignment)
   
   Mục đích: Kiểm tra xem người tập có bị gù lưng hoặc rụt cổ hay không.
   Landmarks: TAI (Ear) - VAI (Shoulder) - HÔNG (Hip)
   Calc: calculateAngle(ear, shoulder, hip). 
         Góc càng gần 180° thì lưng và cổ càng thẳng.
   ========================================================================= */

import 'warrior_one_metric_base.dart';
import '../warrior_one.dart';
import '../../../utils/debouncer.dart';

class BackStraightConfig {
  /// Lưng thẳng đẹp
  static const double GOOD_THRESHOLD = 160.0; 
  
  /// Dưới mức này bị đánh giá là gù lưng / rụt cổ chồm về trước
  static const double HUNCHED_ERROR = 145.0; 
}

class BackStraightMetric extends WarriorOneMetricBase {
  @override
  String get name => 'BackStraight';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Dùng debouncer 10 frames (~333ms) để tránh báo lỗi khi người tập vừa chỉnh tư thế
  final Debouncer _hunchedDebouncer = Debouncer(requiredFrames: 10);
  
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HoldContext ctx) {
    if (ctx.holdState != WarriorOneState.hold) return;

    // Giả sử trong HoldContext bạn đã tính sẵn biến này:
    // ctx.spineAngle = calculateAngle(ear, shoulder, hip);
    final double angle = ctx.spineAngle; 
    final phase = ctx.holdState.name.toUpperCase();
    
    _debugData['spineAngle'] = angle.toStringAsFixed(1);

    // --- Kiểm tra lỗi gù lưng ---
    final bool isHunched = _hunchedDebouncer.update(angle < BackStraightConfig.HUNCHED_ERROR);

    if (isHunched) {
      ctx.resultIssues.feedback['back_straight'] = 'Lưng đang bị gù! Mở rộng ngực và vươn thẳng lưng lên nhé.';
      
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('hold', 'back_straight', 'Lưng đang bị gù! Mở rộng ngực, thu cằm lại và vươn thẳng lưng lên nhé.');
        _instructionSet = true;
      }
      
      _logFault(phase, 'Spine', 'Hunched back — open chest and straighten spine', 
          voiceMessage: 'Thẳng lưng lên, mở rộng ngực');
    } 
    else if (angle >= BackStraightConfig.GOOD_THRESHOLD) {
      ctx.resultIssues.feedback['back_straight'] = 'Lưng giữ rất thẳng, tốt!';
    }
  }

  void _logFault(String phase, String type, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: true, // Bạn có thể để true (lỗi nặng) hoặc false (chỉ nhắc nhở) tùy độ khắt khe
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _hunchedDebouncer.reset();
    _instructionSet = false;
  }
}