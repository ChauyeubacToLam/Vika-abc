import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/exercise/widgets/hold_hero_ring.dart';
import 'package:vika/screens/exercise/widgets/hybrid_hold_cue.dart';
import 'package:vika/screens/exercise/widgets/rep_hero.dart';
import 'package:vika/screens/exercise/widgets/rest_countdown_ring.dart';

void main() {
  testWidgets('hold hero ring shows accrued whole seconds and the target',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: HoldHeroRing(seconds: 7.6, targetSeconds: 15),
          ),
        ),
      ),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.text('/ 15 GIÂY'), findsOneWidget);
  });

  testWidgets('rep hero shows the counted rep and the set target',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: IvoryRepHero(repCount: 5, totalReps: 12),
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('/12'), findsOneWidget);
  });

  testWidgets('rep hero clamps the display at the set target', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: IvoryRepHero(repCount: 14, totalReps: 12),
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('/12'), findsOneWidget);
  });

  Widget hostCue({required bool readyToPush}) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: HybridHoldCue(
            // Sub-second hold (squat: 0.35s target) — no countdown numeral.
            remainingSeconds: readyToPush ? 0 : 0.35,
            readyToPush: readyToPush,
            showCountdown: false,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'hybrid cue guarantees the hold beat before LÊN! even on a 0.35s hold',
      (tester) async {
    await tester.pumpWidget(hostCue(readyToPush: false));
    // Numeral-only center: the seconds, no hold label.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('GIỮ'), findsNothing);
    expect(find.text('LÊN!'), findsNothing);

    // The exercise reports readyToPush after only 350ms of physical hold.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(hostCue(readyToPush: true));

    // The hold beat hasn't lived its 600ms minimum — the ring must still
    // be draining, no release yet.
    expect(find.text('LÊN!'), findsNothing);

    // Once the beat floor passes, the release pop takes over.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LÊN!'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('hybrid cue countdown mode shows the draining seconds',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: HybridHoldCue(
              // Walking-lunge-style 2s hold, 0.6s in.
              remainingSeconds: 1.4,
              readyToPush: false,
              progress: 0.3,
              showCountdown: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.text('GIỮ'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('rest countdown ring shows the draining break seconds',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: RestCountdownRing(
              // McGill plank break: 5s rest, 3.2s left.
              remainingSeconds: 3.2,
              totalSeconds: 5,
            ),
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('drained rest ring can show the re-arm instruction',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RestCountdownRing(
            remainingSeconds: 0,
            totalSeconds: 5,
            centerLabel: 'Vào tư thế',
          ),
        ),
      ),
    );

    expect(find.text('Vào tư thế'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hybrid time ring and rep hero fit a small portrait stage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(320, 568)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 568,
              child: Stack(
                children: [
                  Center(
                    child: HoldHeroRing(seconds: 12, targetSeconds: 20),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: IvoryRepHero(repCount: 1, totalReps: 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
