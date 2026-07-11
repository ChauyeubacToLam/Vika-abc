import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vika/screens/auth/auth_v5_widgets.dart';
import 'package:vika/screens/auth/reviewer_demo_gate.dart';

void main() {
  testWidgets('provider buttons are balanced and use approved action titles',
      (tester) async {
    var appleTaps = 0;
    var googleTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 342,
              child: AuthProviderRail(
                busy: false,
                onApple: () => appleTaps++,
                onGoogle: () => googleTaps++,
                onFacebook: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(V5SignInWithAppleButton.title), findsOneWidget);
    expect(find.text(AuthProviderRail.googleTitle), findsOneWidget);
    expect(
      find.byKey(V5SignInWithAppleButton.officialLogoKey),
      findsOneWidget,
    );

    final appleSize = tester.getSize(find.byType(V5SignInWithAppleButton));
    final googleSize = tester.getSize(
      find.byKey(AuthProviderRail.googleButtonKey),
    );
    expect(appleSize.width, greaterThanOrEqualTo(140));
    expect(appleSize.height, greaterThanOrEqualTo(44));
    expect(googleSize, appleSize);

    final officialArtwork = await rootBundle.loadString(
      V5SignInWithAppleButton.officialLogoAsset,
    );
    expect(officialArtwork, contains('Left Black Logo Medium'));
    expect(officialArtwork, contains('width="31px" height="44px"'));

    await tester.tap(find.text(V5SignInWithAppleButton.title));
    await tester.pump();
    expect(appleTaps, 1);

    await tester.tap(find.text(AuthProviderRail.googleTitle));
    await tester.pump();
    expect(googleTaps, 1);
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
