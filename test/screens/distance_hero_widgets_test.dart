import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/exercise/widgets/hold_hero_ring.dart';
import 'package:vika/screens/exercise/widgets/rep_hero.dart';

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
}
