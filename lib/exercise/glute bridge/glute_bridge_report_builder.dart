import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class GluteBridgeReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': [
          'hip_extension_fails_count',
          'speed_control_fails_count',
        ],
        'hip': [
          'hip_extension_fails_count',
          'knee_angle_fails_count',
        ],
        'knee': ['knee_angle_fails_count'],
        'shoulder_neck': ['neck_head_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'hip_extension_fails_count': (
          watch: 'Trong Glute Bridge: hông có lúc chưa lên đúng tầm.',
          next:
              'Ấn gót xuống sàn, kéo xương sườn về hông và nâng đến khi thân thành một đường dài.',
        ),
        'knee_angle_fails_count': (
          watch: 'Trong Glute Bridge: vị trí bàn chân làm gối mất góc tốt.',
          next:
              'Kéo gót về dưới gối như đang đặt hai bánh xe thẳng hàng rồi mới nâng hông.',
        ),
        'speed_control_fails_count': (
          watch: 'Trong Glute Bridge: hông có lúc rơi xuống hơi nhanh.',
          next:
              'Hạ hông như chạm vào mặt nước, chậm và êm trước khi bắt đầu rep mới.',
        ),
        'neck_head_fails_count': (
          watch: 'Trong Glute Bridge: đầu hoặc cổ có lúc nhấc khỏi sàn.',
          next:
              'Đặt gáy nặng xuống thảm, nhìn lên trần và để hông làm phần chuyển động.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'hip_extension_fails_count': 'Nâng hông',
        'knee_angle_fails_count': 'Góc gối',
        'speed_control_fails_count': 'Nhịp hạ',
        'neck_head_fails_count': 'Cổ thư giãn',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Nâng hông': (c, t) => 'Hông lên gọn $c/$t rep - mông bắt nhịp tốt.',
        'Góc gối': (c, t) => 'Góc gối ổn $c/$t rep - chân đặt rất chắc.',
        'Nhịp hạ': (c, t) =>
            'Hạ hông kiểm soát $c/$t rep - lưng dưới được bảo vệ.',
        'Cổ thư giãn': (c, t) =>
            'Đầu cổ thư giãn $c/$t rep - thân trên rất yên.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
