import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/leg_raise_voice_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all leg raise voice catalog entries point to bundled MP3 assets',
      () async {
    expect(LegRaiseVoiceAssets.files, isNotEmpty);

    for (final entry in LegRaiseVoiceAssets.files.entries) {
      final data = await rootBundle.load(
        '${LegRaiseVoiceAssets.assetBundlePrefix}/${entry.value}',
      );

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Missing or empty Leg Raises voice asset for "${entry.key}"',
      );
    }
  });
}
