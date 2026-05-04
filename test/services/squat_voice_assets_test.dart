import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/squat_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all squat voice catalog entries point to bundled WAV assets', () async {
    expect(SquatVoiceAssets.files, isNotEmpty);

    for (final entry in SquatVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${SquatVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty voice asset for "${entry.key}"',
      );
    }
  });
}
