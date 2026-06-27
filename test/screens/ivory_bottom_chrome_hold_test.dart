import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/exercise/widgets/ivory_chrome.dart';

void main() {
  testWidgets('time-based bottom chrome shows elapsed seconds, not reps',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: IvoryBottomChrome(
            phaseVerb: 'GIỮ',
            phaseHint: '7/15 giây đúng tư thế',
            repCount: 0,
            totalReps: 15,
            isTimeBased: true,
            elapsedSeconds: 7,
          ),
        ),
      ),
    );

    expect(find.text('GIÂY'), findsOneWidget);
    expect(find.text('07'), findsOneWidget);
    expect(find.text('/15'), findsOneWidget);
    expect(find.text('LẦN'), findsNothing);
  });
}
