import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class LyingLegRaiseReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_fails'], // Võng lưng khi hạ chân dồn ép trực tiếp vào psoas và kéo cột sống (shear force)
      };

  @override
  Map<String, String> faultToTipMap() => {
        'lumbar_fails': 'Nếu bạn thấy thắt lưng hổng lên khỏi mặt sàn, ĐỪNG hạ gót chân quá thấp. Chỉ hạ chân đến mức mà bạn vẫn có thể ấn chặt thắt lưng xuống mặt đất.',
        'rom_fails': 'Nâng gót chân cao vuông góc với sàn để giải phóng lực căng ở lưng dưới trước khi tiếp tục hạ.',
        'tempo_fails': 'Thời điểm cơ bụng làm việc hiệu quả nhất là khi bạn HẠ CHÂN kháng lại trọng lực. Đừng thả rơi tự do!',
        'knee_fails': 'Giữ thẳng gối để đạt hiệu quả cao nhất. Nếu thấy quá nặng, bạn có thể chủ động chuyển sang bài Co gối (Knee Tuck).',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Spine': (c, t) => 'Bảo vệ cột sống xuất sắc $c/$t rep!',
        'ROM': (c, t) => 'Biên độ thẳng tắp $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'lumbar_fails': 'Spine',
        'rom_fails': 'ROM',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    
    if (totalReps == 0) return [];

    // Chỉ số bảo vệ cột sống (Spinal Safety Index)
    int totalLumbarFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['lumbar_fails'] as int? ?? 0));
    double spineScore = ((totalReps - totalLumbarFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    // Độ hoàn thiện biên độ (ROM Quality)
    int totalRomFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['rom_fails'] as int? ?? 0));
    double romScore = ((totalReps - totalRomFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    // Kiểm soát hạ chân (Eccentric Control)
    int totalTempoFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['tempo_fails'] as int? ?? 0));
    double tempoScore = ((totalReps - totalTempoFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    return [
      DetailCard(
        label: 'An Toàn Cột Sống',
        value: '${spineScore.round()}%',
        subLabel: 'Không võng lưng',
        useRadial: true,
        radialValue: spineScore,
        color: 'jade', // Xanh an toàn
      ),
      DetailCard(
        label: 'Biên Độ Vươn',
        value: '${romScore.round()}%',
        subLabel: 'Góc 90 độ',
        useRadial: true,
        radialValue: romScore,
        color: 'blue',
      ),
      DetailCard(
        label: 'Kiểm Soát Hạ',
        value: '${tempoScore.round()}%',
        subLabel: 'Kháng lực ly tâm',
        useRadial: true,
        radialValue: tempoScore,
        color: 'amber',
      ),
    ];
  }
  
  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}