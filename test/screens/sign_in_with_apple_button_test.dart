import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vika/screens/auth/auth_v5_widgets.dart';
import 'package:vika/screens/auth/reviewer_demo_gate.dart';

void main() {
  testWidgets('Apple button uses official artwork and an approved title',
      (tester) async {
    var appleTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 342,
              child: AuthProviderRail(
                busy: false,
                onApple: () => appleTaps++,
                onGoogle: () {},
                onFacebook: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(V5SignInWithAppleButton.title), findsOneWidget);
    expect(
      find.byKey(V5SignInWithAppleButton.officialLogoKey),
      findsOneWidget,
    );

    final size = tester.getSize(find.byType(V5SignInWithAppleButton));
    expect(size.width, greaterThanOrEqualTo(140));
    expect(size.height, greaterThanOrEqualTo(44));

    final officialArtwork = await rootBundle.loadString(
      V5SignInWithAppleButton.officialLogoAsset,
    );
    expect(officialArtwork, contains('Left White Logo Medium'));
    expect(officialArtwork, contains('width="31px" height="44px"'));

    await tester.tap(find.text(V5SignInWithAppleButton.title));
    await tester.pump();
    expect(appleTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reviewer hold remains separate from a normal Apple tap',
      (tester) async {
    var appleTaps = 0;
    var reviewerHolds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 342,
              child: V5SignInWithAppleButton(
                onPressed: () => appleTaps++,
                onHoldComplete: () => reviewerHolds++,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(V5SignInWithAppleButton)),
    );
    await tester.pump(reviewerHoldDuration);
    await gesture.up();
    await tester.pump();

    expect(reviewerHolds, 1);
    expect(appleTaps, 0);
    expect(tester.takeException(), isNull);
  });
}
