import 'bird_dog_metric_base.dart';

class TempoMetric extends BirdDogMetricBase {
  @override
  String get name => 'TempoAndAlternating';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _holdStartMs;
  double? holdDuration;
  bool? _lastLegWasLeft;

  // Mở getter để truy cập tính vòng quay 5s
  int? get holdStartMs => _holdStartMs;
  bool? get lastLegWasLeft => _lastLegWasLeft;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {
    if (to == BirdDogState.hold_extended) {
      _holdStartMs = timestampMs;
    } else if (from == BirdDogState.hold_extended && _holdStartMs != null) {
      holdDuration = (timestampMs - _holdStartMs!) / 1000.0;
    }
  }

  @override
  void update(BirdDogRepContext ctx) {}

  void evaluateRep(BirdDogRepContext ctx) {
    // Đổi logic thành check 5.0 giây
    if (holdDuration != null && holdDuration! < 5.0) {
       _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Tempo',
          message: 'Giữ chưa đủ 5s (${holdDuration!.toStringAsFixed(1)}s)',
          voiceMessage: 'Giữ lại 5 giây ở điểm cao nhất nhé',
          affectsForm: true,
          priority: BirdDogFaultPriority.tempo,
        ));
    }

    // Lỗi cùng tay cùng chân
    if (ctx.isSameSide) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'SameSide',
        message: 'Giơ cùng lúc tay và chân một bên',
        voiceMessage: 'Chú ý giơ tay và chân khác bên nhé',
        affectsForm: true,
        priority: BirdDogFaultPriority.alignment,
      ));
    }

    // Lỗi không luân phiên đổi bên
    if (_lastLegWasLeft != null && _lastLegWasLeft == ctx.isLeftLegActive) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'NotAlternating',
        message: 'Không luân phiên đổi bên',
        voiceMessage: 'Nhớ đổi bên sau mỗi lần nhé',
        affectsForm: true,
        priority: BirdDogFaultPriority.alignment,
      ));
    }
  }

  // Được gọi khi rep hợp lệ hoàn thành để lưu bên
  void markLegUsed(bool isLeft) {
    _lastLegWasLeft = isLeft;
  }

  @override
  void reset() {
    _faults.clear();
    _holdStartMs = null;
    holdDuration = null;
  }
}