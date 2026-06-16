import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/bow_pose_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all bow pose voice catalog entries point to bundled MP3 assets',
      () async {
    expect(BowPoseVoiceAssets.files, isNotEmpty);

    for (final entry in BowPoseVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${BowPoseVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty Bow Pose voice asset for "${entry.key}"',
      );
    }
  });
}
