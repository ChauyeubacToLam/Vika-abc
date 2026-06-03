import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/squat/squat_report_builder.dart';

void main() {
  test('squat fault tips expose watch and next copy', () {
    final builder = SquatReportBuilder();
    final tips = builder.faultToTipMap();

    expect(tips['depth_fails_count']?.watch, isNotEmpty);
    expect(tips['depth_fails_count']?.next, 'Ngồi xuống sâu hơn nữa');
  });
}
