// ignore_for_file: curly_braces_in_flow_control_structures
import 'raised_arms_metric_base.dart';
import '../raised_arms.dart';
import '../../../utils/debouncer.dart';

/// MET-3 and MET-4: Arm overhead reach and elbow extension.
/// Coaching-only compound metric adapted from Warrior I.
class ArmPositionMetric extends RaisedArmsMetricBase {
  @override
  String get name => 'ArmPosition';

  static const double _raisedGate = 45.0;
  static const double _tooLow = 65.0;
  static const double _goodMin = 0.0;
  static const double _goodMax = 45.0;
  static const double _elbowTooBent = 125.0;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _tooLowDebouncer = Debouncer(requiredFrames: 10);
  final Debouncer _elbowDebouncer = Debouncer(requiredFrames: 10);

  bool _lowInstructionSet = false;
  bool _elbowInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RaisedArmsContext ctx) {
    if (ctx.state != RaisedArmsState.holding) return;

    final armV = ctx.armVerticalAngle;
    final elbow = ctx.elbowAngle;
    final phase = ctx.state.name;

    _debugData['armVertical'] = armV.toStringAsFixed(1);
    _debugData['elbowAngle'] = elbow.toStringAsFixed(1);
    _debugData['wristVisible'] = ctx.wristVisible;

    if (!ctx.wristVisible) {
      ctx.resultIssues.feedback['Arms'] = 'Tay vươn tốt ✓';
      return;
    }

    final tooLow = _tooLowDebouncer.update(armV > _tooLow);
    if (tooLow) {
      ctx.resultIssues.feedback['Arms'] = 'Vươn tay cao hơn nhé';
      if (!_lowInstructionSet) {
        ctx.resultIssues.addInstruction(
          'holding',
          'armsLow',
          'Vươn tay cao hơn nếu vai cho phép nhé.',
        );
        _lowInstructionSet = true;
      }
      _logFault(phase, 'Arms hanging forward', 'ArmsLow');
      return;
    } else if (armV >= _goodMin && armV <= _goodMax) {
      ctx.resultIssues.feedback['Arms'] = 'Tay vươn tốt ✓';
    }

    final armsRaised = armV <= _raisedGate;
    if (!armsRaised) return;

    final elbowBent = _elbowDebouncer.update(elbow < _elbowTooBent);
    if (elbowBent) {
      ctx.resultIssues.feedback['Arms'] = 'Duỗi thẳng khuỷu tay nhé';
      if (!_elbowInstructionSet) {
        ctx.resultIssues.addInstruction(
          'holding',
          'elbowBent',
          'Duỗi thẳng khuỷu tay, vươn dài lên nhé.',
        );
        _elbowInstructionSet = true;
      }
      _logFault(phase, 'Elbows bent', 'ElbowBent');
    }
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: false,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _tooLowDebouncer.reset();
    _elbowDebouncer.reset();
    _lowInstructionSet = false;
    _elbowInstructionSet = false;
  }
}
