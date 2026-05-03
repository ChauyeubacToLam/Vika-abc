import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';

class ButterflyReportBuilder extends ExerciseReportBuilder {
  
  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];
    
    // Lấy data từ set mới nhất
    final latestLog = setLoggers.last.setLogs;
    final totalHold = (latestLog["total_hold_time"] as num?)?.toDouble() ?? 0.0;
    final maxSep = (latestLog["max_knee_separation"] as num?)?.toDouble() ?? 0.0;

    return [
      DetailCard(
        label: 'Độ mở gối tối đa',
        value: maxSep.toStringAsFixed(0), // Đã xoá nháy đơn thừa để fix lỗi nội suy chuỗi (string interpolation)
        subLabel: 'Biên độ tốt nhất',
        miniBarValues: const [], // Nếu có data các set trước thì truyền vào
        miniBarMax: 200,
        lowerIsBetter: false,
        color: 'jade',
      ),
      DetailCard(
        label: 'Thời gian Hold',
        value: '${totalHold.toStringAsFixed(0)}s',
        subLabel: 'Tổng thời gian kéo giãn',
        useRadial: true,
        radialValue: (totalHold / 30 * 100).clamp(0, 100).toDouble(), // Giả sử Target là 30s
        color: 'amber',
      ),
    ];
  }

  @override
  (String, String, String?) pickInsight(ExerciseLogger logger, ExerciseLogger? prevLogger, int setScore, int? prevScore) {
    final postureFails = (logger.setLogs["posture_fails_count"] as num?)?.toInt() ?? 0;
    
    if (postureFails > 0) {
      return (
        'Cảnh báo: Lệch vai/Gù lưng',
        'Cố gắng giữ lưng thẳng khi ép gối, không cố quá sức.',
        null, // Đã thêm phần tử thứ 3 để khớp kiểu trả về
      );
    }
    
    return (
      'Kéo giãn tốt', 
      'Giữ đều nhịp thở ở bài tập này.',
      null, // Đã thêm phần tử thứ 3 để khớp kiểu trả về
    );
  }
  
  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) { 
    return null; 
  }
}