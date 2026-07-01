import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/bird_dog_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all bird dog voice catalog entries point to bundled MP3 assets',
      () async {
    expect(BirdDogVoiceAssets.files, isNotEmpty);

    for (final entry in BirdDogVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${BirdDogVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty Bird Dog voice asset for "${entry.key}"',
      );
    }
  });
}
