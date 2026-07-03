import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not replay metric faults while preparing the next set', () {
    final exercise = CurlUp(maxRep: 6);

    expect(exercise.shouldReplayPreviousSetVoiceFaults, isFalse);
  });
}
