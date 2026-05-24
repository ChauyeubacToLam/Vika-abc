import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class Cmt8ReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_fails_count', 'ashtanga_hip_fails_count'],
        'shoulder': ['downdog_fails_count'],
        'neck': ['cobra_neck_fails_count'],
        'knee': ['lunge_shear_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'lumbar_fails_count':
            'Äáº©y hÃ´ng vá» trÆ°á»›c khi ngáº£ lÆ°ng ra sau Ä‘á»ƒ báº£o vá»‡ tháº¯t lÆ°ng.',
        'ashtanga_hip_fails_count':
            'á»ž tÆ° tháº¿ 8 Ä‘iá»ƒm, nhá»› nhÃ´ mÃ´ng lÃªn, khÃ´ng náº±m báº¹p.',
        'downdog_fails_count':
            'Ã‰p vai xuá»‘ng vÃ  Ä‘áº©y máº¡nh tay khi á»Ÿ ChÃ³ cÃºi máº·t.',
        'cobra_neck_fails_count':
            'Háº¡ vai xuá»‘ng xa tai, vÆ°Æ¡n dÃ i cá»• khi á»Ÿ Ráº¯n há»• mang.',
        'lunge_shear_fails_count':
            'Giá»¯ Ä‘áº§u gá»‘i tháº³ng gÃ³c vá»›i máº¯t cÃ¡ á»Ÿ tÆ° tháº¿ Ká»µ sÄ©.',
        'knee_bend_fails_count':
            'Cá»‘ gáº¯ng giá»¯ tháº³ng chÃ¢n khi gáº­p ngÆ°á»i Ä‘á»ƒ kÃ©o giÃ£n khoeo.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Flow': (c, t) => 'HoÃ n thÃ nh mÆ°á»£t mÃ  $c/$t vÃ²ng!',
        'Spine': (c, t) => 'Cá»™t sá»‘ng á»•n Ä‘á»‹nh $c/$t vÃ²ng!',
        'Symmetry': (c, t) => 'Äá»‘i xá»©ng tá»‘t $c/$t vÃ²ng!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'lumbar_fails_count': 'Spine',
        'symmetry_fails_count': 'Symmetry',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;

    if (totalReps == 0) return [];

    final accuracy = (totalGood / totalReps * 100).roundToDouble();

    // Flow Score: Dá»±a trÃªn tá»· lá»‡ rep khÃ´ng bá»‹ fault nghiÃªm trá»ng
    final flowScore = accuracy;

    // Symmetry Score: Dá»±a trÃªn tá»· lá»‡ rep khÃ´ng bá»‹ fault symmetry
    final totalSymmetryFails = setLoggers.fold(
        0,
        (sum, log) =>
            sum + (log.setLogs['symmetry_fails_count'] as int? ?? 0));
    final symmetryScore =
        ((totalReps - totalSymmetryFails) / totalReps * 100)
            .clamp(0, 100)
            .roundToDouble();

    // Spine Score: Lumbar + Downdog + Cobra
    final totalSpineFails = setLoggers.fold(
        0,
        (sum, log) =>
            sum +
            (log.setLogs['lumbar_fails_count'] as int? ?? 0) +
            (log.setLogs['downdog_fails_count'] as int? ?? 0) +
            (log.setLogs['cobra_neck_fails_count'] as int? ?? 0));
    final spineScore =
        ((totalReps - totalSpineFails) / totalReps * 100)
            .clamp(0, 100)
            .roundToDouble();

    return [
      DetailCard(
        label: 'Flow Score',
        value: '${flowScore.round()}%',
        subLabel: '$totalGood/$totalReps vÃ²ng chuáº©n',
        useRadial: true,
        radialValue: flowScore,
        color: 'amber',
      ),
      DetailCard(
        label: 'Cá»™t sá»‘ng',
        value: '${spineScore.round()}%',
        subLabel: 'KhÃ´ng gÃ£y tháº¯t lÆ°ng',
        useRadial: true,
        radialValue: spineScore,
        color: 'jade',
      ),
      DetailCard(
        label: 'Äá»‘i xá»©ng',
        value: '${symmetryScore.round()}%',
        subLabel: 'P4 vs P9 Ä‘á»u',
        useRadial: true,
        radialValue: symmetryScore,
        color: 'blue',
      ),
    ];
  }

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}

