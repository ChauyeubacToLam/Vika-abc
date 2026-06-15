import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class CurlUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': [
          'trunk_elev_fails_count',
          'knee_ext_fails_count',
        ],
        'hip': ['knee_ext_fails_count'],
        'knee': ['knee_ext_fails_count'],
        'shoulder_neck': ['neck_pull_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_elev_fails_count': (
          watch:
              'Trong McGill Curl-up: thân có lúc cuộn quá cao hoặc quá thấp.',
          next:
              'Trượt xương sườn về phía xương chậu, chỉ nhấc vai khỏi thảm một đoạn ngắn.',
        ),
        'neck_pull_fails_count': (
          watch: 'Trong McGill Curl-up: cổ có xu hướng bị kéo lên.',
          next:
              'Nhìn lên trần, giữ cổ áo rộng ra và để bụng kéo vai lên thay vì kéo đầu.',
        ),
        'knee_ext_fails_count': (
          watch: 'Trong McGill Curl-up: gối có lúc duỗi khỏi vị trí ban đầu.',
          next:
              'Neo gót chân xuống sàn như đặt dưới một thanh ngang, giữ gối cong khi cuộn lên.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_elev_fails_count': 'Biên độ cuộn',
        'neck_pull_fails_count': 'Cổ trung tính',
        'knee_ext_fails_count': 'Gối giữ vị trí',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Biên độ cuộn': (c, t) =>
            'Biên độ cuộn gọn $c/$t rep - đúng chất McGill.',
        'Cổ trung tính': (c, t) => 'Cổ giữ trung tính $c/$t rep - rất sạch.',
        'Gối giữ vị trí': (c, t) =>
            'Gối giữ ổn $c/$t rep - thân dưới yên như cần.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
