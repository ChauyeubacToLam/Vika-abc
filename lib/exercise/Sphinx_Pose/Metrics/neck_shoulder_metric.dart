import 'sphinx_metric_base.dart';
import '../../../utils/debouncer.dart';

// [Fix Gap 1]: Tách thành 2 nhánh detect riêng biệt theo tài liệu
//   - Nhánh 1: Rụt / nhô vai (shrug) dùng earShoulderDist
//   - Nhánh 2: Ngửa cổ (hyperextension) dùng neckAngle (Tai-Vai-Hông)
class NeckShoulderMetric extends SphinxMetricBase {
  @override
  String get name => 'NeckShoulder';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Debouncer riêng cho từng loại lỗi để tránh conflict
  final Debouncer _shrugDebouncer = Debouncer(requiredFrames: 4);
  final Debouncer _hyperDebouncer = Debouncer(requiredFrames: 4);

  bool _shrugInstructionSet = false;
  bool _hyperInstructionSet = false;
  
  // Biến lưu trạng thái ngửa cổ để dùng chung giữa các hàm
  bool _isHyper = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SphinxContext ctx) {
    if (ctx.state != SphinxState.isometricHold && ctx.state != SphinxState.ascending) return;

    // Đảo thứ tự: Gọi _checkHyperextension trước để cập nhật _isHyper cho frame hiện tại
    _checkHyperextension(ctx);
    _checkShrug(ctx);
  }

  // --- Nhánh 1: Rụt vai / nhô vai (shrug) ---
  void _checkShrug(SphinxContext ctx) {
    final double normalizedDist = ctx.earShoulderDist / (ctx.scaleFactor <= 0 ? 1 : ctx.scaleFactor);
    _debugData['neckDistNorm'] = normalizedDist.toStringAsFixed(3);

    if (_shrugDebouncer.update(normalizedDist < SphinxConfig.Ag_Neck_Shrug_Tol)) {
      ctx.resultIssues.feedback['Neck'] = 'Thẳng vai!';
      if (!_shrugInstructionSet) {
        ctx.resultIssues.addInstruction(
          'isometricHold',
          'Neck',
          'Bạn đang rụt vai gần tai. Hãy hạ vai xuống để tránh mỏi vai gáy.',
        );
        _shrugInstructionSet = true;
      }
      _logFault(ctx.state.name, 'NeckShrug', 'Lỗi rụt vai', 'Thẳng vai ra', SphinxFaultVoicePriority.shrugNeck);
    } else {
      // Chỉ set feedback "tốt" nếu nhánh hyperextension cũng không lỗi
      // để tránh ghi đè lên nhau. Nhánh hyper sẽ ghi đè lên nếu có lỗi.
      if (!_isHyper) {
        ctx.resultIssues.feedback['Neck'] = 'Vai thẳng tốt';
      }
    }
  }

  // --- Nhánh 2: Ngửa cổ ra sau quá mức (hyperextension) ---
  // neckAngle = góc Tai - Vai - Hông (side view).
  // Góc trung tính ~160-170 độ. Ngửa cổ nhiều góc sẽ thu nhỏ < Ai_Neck_Hyper_Tol.
  void _checkHyperextension(SphinxContext ctx) {
    _debugData['neckAngle'] = ctx.neckAngle.toStringAsFixed(1);
    
    // Lưu kết quả của debouncer vào _isHyper
    _isHyper = _hyperDebouncer.update(ctx.neckAngle < SphinxConfig.Ai_Neck_Hyper_Tol);

    if (_isHyper) {
      ctx.resultIssues.feedback['Neck'] = 'Hạ cằm xuống!';
      if (!_hyperInstructionSet) {
        ctx.resultIssues.addInstruction(
          'isometricHold',
          'NeckHyper',
          'Cổ đang ngửa quá mức. Thu nhẹ cằm lại, nhìn chéo xuống sàn phía trước.',
        );
        _hyperInstructionSet = true;
      }
      _logFault(
        ctx.state.name,
        'NeckHyper',
        'Lỗi ngửa cổ',
        'Hạ cằm xuống nhìn xuống thảm',
        SphinxFaultVoicePriority.neckHyper,
      );
    }
  }

  void _logFault(String phase, String type, String message, String voiceMessage, int priority) {
    // Chỉ log 1 lỗi mỗi loại trong 1 rep
    if (!_faults.any((f) => f.phase == phase && f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: true,
        priority: priority,
      ));
    }
  }

  @override
  void reset() {
    super.reset();
    _shrugInstructionSet = false;
    _hyperInstructionSet = false;
    _isHyper = false; // Reset lại trạng thái
    _shrugDebouncer.reset();
    _hyperDebouncer.reset();
  }
}