import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class ReverseCrunchReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['momentum_fails', 'curl_fails'], // Vung chân (shear stress), không cuộn chậu
      };

  @override
  Map<String, String> faultToTipMap() => {
        'momentum_fails': 'Tập trung dùng cơ bụng dưới kéo đùi về phía ngực thay vì vung chân. Giữ nguyên góc chân 90 độ.',
        'curl_fails': 'Nâng mông nhấc lên khỏi thảm mới kích hoạt được bụng dưới. Hãy cuộn xương chậu lên.',
        'tempo_fails': 'Lúc thả chân xuống, cơ bụng phải gồng lại. Hạ chân từ từ trong 2 giây!',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Isolation': (c, t) => 'Cô lập tốt, không bị vung chân $c/$t rep!',
        'Pelvic': (c, t) => 'Biên độ sâu $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'momentum_fails': 'Isolation',
        'curl_fails': 'Pelvic',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    
    if (totalReps == 0) return [];

    // =========================================================================
    // FIX: THAY ĐỔI 'log.data' THÀNH 'log.setLogs'
    // =========================================================================
    // Điểm Cô Lập (Không vung chân)
    int totalMomFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['momentum_fails'] as int? ?? 0));
    double isoScore = ((totalReps - totalMomFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    // Điểm Cuộn Khung Chậu
    int totalCurlFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['curl_fails'] as int? ?? 0));
    double curlScore = ((totalReps - totalCurlFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    // Điểm Nhịp Độ Ly Tâm (Eccentric Tempo)
    int totalTempoFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['tempo_fails'] as int? ?? 0));
    double tempoScore = ((totalReps - totalTempoFails) / totalReps * 100).clamp(0, 100).roundToDouble();
    // =========================================================================

    return [
      DetailCard(
        label: 'Cô Lập',
        value: '${isoScore.round()}%',
        subLabel: 'Không vung cẳng chân',
        useRadial: true,
        radialValue: isoScore,
        color: 'amber',
      ),
      DetailCard(
        label: 'Biên Độ',
        value: '${curlScore.round()}%',
        subLabel: 'Nhấc mông khỏi sàn',
        useRadial: true,
        radialValue: curlScore,
        color: 'jade',
      ),
      DetailCard(
        label: 'Kiểm Soát',
        value: '${tempoScore.round()}%',
        subLabel: 'Không thả rơi tự do',
        useRadial: true,
        radialValue: tempoScore,
        color: 'blue',
      ),
    ];
  }

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}