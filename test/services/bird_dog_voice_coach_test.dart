import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/1.Bird Dog/bird_dog.dart';
import 'package:vika/exercise/exercise_base.dart';

class _FakeBirdDogVoicePlayer implements BirdDogVoicePlayer {
  final List<String> spoken = [];
  int clearQueueCount = 0;
  int clearPendingCount = 0;
  bool disposed = false;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  void clearQueue() {
    clearQueueCount++;
    spoken.clear();
  }

  @override
  void clearPendingButKeepCurrent() {
    clearPendingCount++;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speaks setup instructions only once before activation', () {
    final player = _FakeBirdDogVoicePlayer();
    final coach = BirdDogVoiceCoach(voicePlayer: player);
    final exercise = BirdDog(maxRep: 24)..exerciseState = ExerciseState.notActivated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: false,
      feedback: const {},
    );
    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.spoken,
      [
        'Đặt điện thoại hơi chéo để thấy toàn thân trên thảm.',
        'Chống hai tay và hai gối. Tay dưới vai, gối dưới hông, lưng phẳng.',
        'Giơ tay và chân đối diện. Vươn dài. Giữ 2 giây rồi đổi bên.',
      ],
    );
  });

  test('does not speak live frame faults before a rep attempt finishes', () {
    final player = _FakeBirdDogVoicePlayer();
    final coach = BirdDogVoiceCoach(voicePlayer: player);
    final exercise = BirdDog(maxRep: 24)..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Error': 'Không cùng tay cùng chân'},
    );
    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Error': 'Không cùng tay cùng chân'},
    );

    expect(player.spoken, ['Sẵn sàng.']);
  });

  test('speaks no-count and correction when a bird dog attempt is rejected',
      () {
    final player = _FakeBirdDogVoicePlayer();
    final coach = BirdDogVoiceCoach(voicePlayer: player);
    final exercise = BirdDog(maxRep: 24)
      ..exerciseState = ExerciseState.activated
      ..invalidAttemptCount = 1
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Giơ tay và chân đối diện';

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken, contains('Lần này chưa tính.'));
    expect(player.spoken, contains('Giơ tay và chân đối diện.'));
  });

  test('speaks final rep outcome before set completion', () {
    final player = _FakeBirdDogVoicePlayer();
    final coach = BirdDogVoiceCoach(voicePlayer: player);
    final exercise = BirdDog(maxRep: 24)
      ..exerciseState = ExerciseState.completed
      ..repCount = 8
      ..lastRepWasClean = true;

    coach.processFrame(
      exercise: exercise,
      repCount: 8,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.spoken,
      ['8', 'Tốt, hông giữ cân bằng.', 'Hoàn thành bài tập.'],
    );
  });
}
