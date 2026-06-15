import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class WallPushUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': [
          'shoulder_shrug_fails_count',
          'forward_head_fails_count',
          'cervical_extension_fails_count',
          'elbow_flare_fails_count',
        ],
        'wrist': ['wall_contact_fails_count'],
        'lower_back': ['body_line_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'body_line_fails_count': (
          watch:
              'Trong Wall Push Up: vai, hông và chân có lúc chưa giữ thành một đường.',
          next:
              'Đẩy tường ra xa và kéo nhẹ khóa quần về rốn để thân người thành một đường chéo.',
        ),
        'shoulder_shrug_fails_count': (
          watch:
              'Trong Wall Push Up: vai có lúc nhô sát tai khi đẩy vào tường.',
          next:
              'Đẩy tường xa khỏi người và để hai vai trượt xuống, cổ dài nhẹ.',
        ),
        'forward_head_fails_count': (
          watch:
              'Trong Wall Push Up: đầu có lúc rướn về phía tường trước thân người.',
          next:
              'Giữ gáy dài, tưởng tượng đỉnh đầu đi cùng đường với hông và gót chân.',
        ),
        'elbow_flare_fails_count': (
          watch:
              'Trong Wall Push Up: khuỷu tay có lúc mở quá rộng sang hai bên.',
          next:
              'Đưa khuỷu tay chếch xuống như ôm nhẹ hai bên sườn khi hạ người vào tường.',
        ),
        'cervical_extension_fails_count': (
          watch: 'Trong Wall Push Up: cổ có lúc ngửa lên khi bạn đẩy ra.',
          next:
              'Nhìn vào một điểm cố định trên tường, giữ cằm mềm và cổ đi cùng thân người.',
        ),
        'foot_stationary_fails_count': (
          watch: 'Trong Wall Push Up: chân có lúc dịch chuyển trong rep.',
          next:
              'Ghim bàn chân xuống sàn như hai điểm neo, rồi chỉ để khuỷu tay gập duỗi.',
        ),
        'wall_contact_fails_count': (
          watch:
              'Trong Wall Push Up: tay có lúc trượt hoặc rời vị trí trên tường.',
          next:
              'Ấn lòng bàn tay phẳng vào tường và giữ điểm chạm ổn định suốt rep.',
        ),
        'tempo_fails_count': (
          watch: 'Trong Wall Push Up: nhịp hạ hoặc đẩy có lúc hơi vội.',
          next:
              'Hạ người chậm như đang đóng cửa nhẹ, rồi đẩy tường ra xa một cách đều.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'body_line_fails_count': 'Thân người',
        'shoulder_shrug_fails_count': 'Vai thả',
        'forward_head_fails_count': 'Đầu cổ',
        'elbow_flare_fails_count': 'Khuỷu tay',
        'cervical_extension_fails_count': 'Cổ trung tính',
        'foot_stationary_fails_count': 'Chân đứng yên',
        'wall_contact_fails_count': 'Tay neo tường',
        'tempo_fails_count': 'Nhịp đẩy',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Thân người': (c, t) =>
            'Thân người giữ một đường $c/$t rep - lực đẩy sạch hơn.',
        'Vai thả': (c, t) =>
            'Vai xa tai $c/$t rep - cổ và vai được chăm rất tốt.',
        'Đầu cổ': (c, t) =>
            'Đầu đi cùng thân người $c/$t rep - tư thế rất gọn.',
        'Khuỷu tay': (c, t) =>
            'Khuỷu tay đi đúng hướng $c/$t rep - vai ổn định hơn.',
        'Cổ trung tính': (c, t) =>
            'Cổ giữ trung tính $c/$t rep - nhịp đẩy nhẹ và an toàn.',
        'Chân đứng yên': (c, t) =>
            'Bàn chân neo chắc $c/$t rep - nền tảng rất ổn.',
        'Tay neo tường': (c, t) =>
            'Tay giữ điểm chạm tốt $c/$t rep - đường đẩy đều hơn.',
        'Nhịp đẩy': (c, t) =>
            'Nhịp đẩy kiểm soát $c/$t rep - chuyển động mượt hơn.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
