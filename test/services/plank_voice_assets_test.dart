import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/plank_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all plank voice catalog entries point to bundled MP3 assets', () async {
    expect(PlankVoiceAssets.files, isNotEmpty);

    for (final entry in PlankVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${PlankVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty Plank voice asset for "${entry.key}"',
      );
    }
  });
}
