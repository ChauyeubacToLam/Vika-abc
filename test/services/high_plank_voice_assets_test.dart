import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/high_plank_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all high plank voice catalog entries point to bundled MP3 assets',
      () async {
    expect(HighPlankVoiceAssets.files, isNotEmpty);

    for (final entry in HighPlankVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${HighPlankVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty High Plank voice asset for "${entry.key}"',
      );
    }
  });
}
