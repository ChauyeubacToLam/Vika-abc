import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/wall_push_up_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all wall push up voice catalog entries point to bundled MP3 assets',
      () async {
    expect(WallPushUpVoiceAssets.files, isNotEmpty);

    for (final entry in WallPushUpVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${WallPushUpVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty Wall Push Up voice asset for "${entry.key}"',
      );
    }
  });
}
