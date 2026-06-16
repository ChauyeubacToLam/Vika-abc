import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/jumping_jack_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all jumping jack voice catalog entries point to bundled MP3 assets',
      () async {
    expect(JumpingJackVoiceAssets.files, isNotEmpty);

    for (final entry in JumpingJackVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${JumpingJackVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty Jumping Jack voice asset for "${entry.key}"',
      );
    }
  });
}
