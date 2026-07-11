import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vika/screens/auth/auth_v5_widgets.dart';
import 'package:vika/screens/auth/reviewer_demo_gate.dart';

void main() {
  testWidgets(
    'Apple and Google are logo-only tiles, equal in size, and tappable',
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

      // Logo-only: neither provider shows a visible text label anymore.
      expect(find.text(V5SignInWithAppleButton.title), findsNothing);
      expect(find.text(AuthProviderRail.googleTitle), findsNothing);
      expect(
        find.byKey(V5SignInWithAppleButton.officialLogoKey),
        findsOneWidget,
      );
      expect(find.byKey(AuthProviderRail.googleIconSlotKey), findsOneWidget);

      // Apple keeps an accessibility label, so VoiceOver announces it and the
      // control stays identifiable as Sign in with Apple despite having no text.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == V5SignInWithAppleButton.title,
        ),
        findsOneWidget,
      );

      // Apple's one hard rule: the Sign in with Apple button must be no smaller
      // than the other providers. Equal Expanded tiles => identical size.
      final appleSize = tester.getSize(find.byType(V5SignInWithAppleButton));
      final googleSize = tester.getSize(
        find.byKey(AuthProviderRail.googleButtonKey),
      );
      expect(appleSize.height, greaterThanOrEqualTo(44));
      expect(googleSize, appleSize);

      // The artwork is Apple's own logo path, unmodified, framed 1:1. Pinning
      // the exact official path guards against a future swap to fake artwork —
      // the reason the App Store rejected the previous build (Guideline 4).
      final artwork = await rootBundle.loadString(
        V5SignInWithAppleButton.officialLogoAsset,
      );
      expect(artwork, contains('M15.7099491,14.8846154')); // official leaf path
      expect(artwork, contains('M12.6902416,29.5')); // official body path
      expect(artwork, contains('#000000')); // Apple black, not recoloured

      await tester.tap(find.byType(V5SignInWithAppleButton));
      await tester.pump();
      expect(appleTaps, 1);

      await tester.tap(find.byKey(AuthProviderRail.googleButtonKey));
      await tester.pump();
      expect(googleTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
