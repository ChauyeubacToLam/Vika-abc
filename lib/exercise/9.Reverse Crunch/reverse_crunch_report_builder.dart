import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class ReverseCrunchReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': [
          'momentum_fails_count',
          'curl_fails_count'
        ], // Vung chân (shear stress), không cuộn chậu
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'momentum_fails_count': (
          watch:
              'Trong Reverse Crunch: chân có lúc vung theo quán tính khi kéo về ngực.',
          next:
              'Tập trung dùng cơ bụng dưới kéo đùi về phía ngực thay vì vung chân. Giữ nguyên góc chân 90 độ.',
        ),
        'curl_fails_count': (
          watch:
              'Trong Reverse Crunch: mông có lúc chưa nhấc khỏi thảm ở pha cuộn.',
          next:
              'Nâng mông nhấc lên khỏi thảm mới kích hoạt được bụng dưới. Hãy cuộn xương chậu lên.',
        ),
        'tempo_fails_count': (
          watch: 'Trong Reverse Crunch: pha thả chân có lúc diễn ra quá nhanh.',
          next:
              'Lúc thả chân xuống, cơ bụng phải gồng lại. Hạ chân từ từ trong 2 giây!',
        ),
        'arm_position_fails_count': (
          watch: 'Tay không neo ổn định làm thân người dễ lắc khi cuộn hông.',
          next:
              'Ấn hai tay phẳng xuống thảm như điểm tựa, rồi cuộn xương chậu lên nhẹ.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Isolation': (c, t) => 'Cô lập tốt, không bị vung chân $c/$t rep!',
        'Pelvic': (c, t) => 'Biên độ sâu $c/$t rep!',
        'Tay neo sàn': (c, t) =>
            'Hai tay giữ điểm neo tốt $c/$t rep - nhịp cuộn ổn định hơn.',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'momentum_fails_count': 'Isolation',
        'curl_fails_count': 'Pelvic',
        'arm_position_fails_count': 'Tay neo sàn',
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
    int totalMomFails = setLoggers.fold(
        0, (sum, log) => sum + (log.setLogs['momentum_fails_count'] as int? ?? 0));
    double isoScore = ((totalReps - totalMomFails) / totalReps * 100)
        .clamp(0, 100)
        .roundToDouble();

    // Điểm Cuộn Khung Chậu
    int totalCurlFails = setLoggers.fold(
        0, (sum, log) => sum + (log.setLogs['curl_fails_count'] as int? ?? 0));
    double curlScore = ((totalReps - totalCurlFails) / totalReps * 100)
        .clamp(0, 100)
        .roundToDouble();

    // Điểm Nhịp Độ Ly Tâm (Eccentric Tempo)
    int totalTempoFails = setLoggers.fold(
        0, (sum, log) => sum + (log.setLogs['tempo_fails_count'] as int? ?? 0));
    double tempoScore = ((totalReps - totalTempoFails) / totalReps * 100)
        .clamp(0, 100)
        .roundToDouble();
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
