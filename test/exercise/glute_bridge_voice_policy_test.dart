import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not replay old faults before the current set', () {
    final exercise = GluteBridge(maxRep: 1);

    expect(exercise.shouldReplayPreviousSetVoiceFaults, isFalse);
  });
}
