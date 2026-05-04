import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class SeatedForwardReportBuilder extends ExerciseReportBuilder {
  
  @override
  Map<String, List<String>> painToFaultMap() => {
    'Đau thắt lưng': ['SpineRound'],
    'Căng cơ quá mức vùng gân kheo': ['KneeBent'],
  };

  @override
  Map<String, String> faultToTipMap() => {
    'KneeBent': 'Bạn có xu hướng co gối để gập được sâu hơn. Hãy ưu tiên giữ thẳng gối, dù không gập được sâu, cơ gân kheo mới được kéo giãn thực sự.',
    'SpineRound': 'Tránh cong lưng thắt lưng. Hãy tưởng tượng bạn đang gập người từ khớp hông (hip hinge) và đẩy ngực về phía trước mũi chân.',
    'AnklePlantar': 'Để tăng biên độ kéo căng, hãy luôn bẻ gập lưng bàn chân (hướng mũi chân về phía đầu).',
    'TempoShort': 'Kéo giãn tĩnh cần thời gian để cơ bắp làm quen và nhả lực. Lần tới hãy cố gắng giữ tư thế ít nhất 15 giây nhé.',
  };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
    'KneeBent': (count, total) => 'Tuyệt vời! Bạn đã giữ đầu gối thẳng tắp trong suốt quá trình tập.',
    'SpineRound': (count, total) => 'Rất tốt! Cột sống của bạn được căn chỉnh thẳng, bảo vệ an toàn cho đĩa đệm.',
  };

  @override
  Map<String, String> praiseMetricNames() => {
    'KneeBent': 'Kiểm soát gối thẳng',
    'SpineRound': 'Định tuyến cột sống',
  };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];
    
    final latestSet = setLoggers.last;
    final kneeFails = latestSet.setLogs['knee_bent_fails_count'] as int? ?? 0;
    final spineFails = latestSet.setLogs['spine_round_fails_count'] as int? ?? 0;
    final formScore = (100.0 - (kneeFails * 25) - (spineFails * 10)).clamp(0.0, 100.0);

    double bestDepthAngle = 999.0;
    double totalHoldTime = 0.0;

    for (var rep in latestSet.repLogs) {
      final repDepth = rep.data['max_depth_angle'] as double? ?? 999.0;
      if (repDepth < bestDepthAngle) bestDepthAngle = repDepth;
      
      final holdTime = rep.data['hold_time'] as double? ?? 0.0;
      totalHoldTime += holdTime;
    }

    if (bestDepthAngle == 999.0) bestDepthAngle = 0.0;

    return [
      DetailCard(
        label: 'Gập Sâu',
        value: '${bestDepthAngle.toStringAsFixed(1)}°',
        subLabel: 'Góc hông',
        color: 'blue',
      ),
      DetailCard(
        label: 'Thời Gian',
        value: '${totalHoldTime.toStringAsFixed(1)}s',
        subLabel: 'Kéo giãn',
        color: 'jade', 
      ),
      DetailCard(
        label: 'Form',
        value: '${formScore.toStringAsFixed(0)}%',
        subLabel: 'Thẳng gối',
        color: 'amber',
        useRadial: true,
        radialValue: formScore,
      ),
    ];
  }
}