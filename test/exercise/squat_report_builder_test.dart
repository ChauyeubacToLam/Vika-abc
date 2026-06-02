import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/squat/squat_report_builder.dart';

void main() {
  test('squat fault tips expose watch and next copy', () {
    final builder = SquatReportBuilder();
    final tips = builder.faultToTipMap();

    expect(tips['depth_fails_count']?.watch, isNotEmpty);
    expect(tips['depth_fails_count']?.next, 'Ngồi xuống sâu hơn nữa');
  });

  test('squat metric criticality order is deterministic', () {
    final builder = SquatReportBuilder();

    expect(builder.metricCriticalityOrder(), [
      'depth_fails_count',
      'trunk_lean_fails_count',
      'heel_fails_count',
      'hip_shoulder_sync_fails_count',
      'tempo_fails_count',
    ]);
  });
}
