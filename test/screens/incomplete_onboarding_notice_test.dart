import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vika/screens/onboarding/v5/incomplete_onboarding_notice.dart';
import 'package:vika/screens/onboarding/v5/v5_onboarding_navigator.dart';

void main() {
  testWidgets('normal onboarding entry still starts at welcome without notice',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: V5OnboardingNavigator(onRequestLogin: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Bắt đầu hành trình'), findsOneWidget);
    expect(find.text(incompleteOnboardingNoticeTitleVi), findsNothing);

    final navigatorPageView = tester.widget<PageView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is PageView &&
            widget.physics is NeverScrollableScrollPhysics,
      ),
    );
    expect(navigatorPageView.controller?.initialPage, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'incomplete account sees bilingual notice and continues at mirror step',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: V5OnboardingNavigator(
            onRequestLogin: () {},
            resumeIncompleteOnboardingAfterLogin: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(incompleteOnboardingNoticeTitleVi), findsOneWidget);
      expect(find.text(incompleteOnboardingNoticeTitleEn), findsOneWidget);
      expect(find.text(incompleteOnboardingNoticeBodyVi), findsOneWidget);
      expect(find.text(incompleteOnboardingNoticeBodyEn), findsOneWidget);
      expect(
        find.byKey(IncompleteOnboardingNoticeDialog.continueButtonKey),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(IncompleteOnboardingNoticeDialog.continueButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.text(incompleteOnboardingNoticeTitleVi), findsNothing);
      expect(find.text('Bạn thấy mình ở đâu?'), findsOneWidget);

      final navigatorPageView = tester.widget<PageView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is PageView &&
              widget.physics is NeverScrollableScrollPhysics,
        ),
      );
      expect(navigatorPageView.controller?.initialPage, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test('notice copy does not use dash characters', () {
    const copy = <String>[
      incompleteOnboardingNoticeTitleVi,
      incompleteOnboardingNoticeTitleEn,
      incompleteOnboardingNoticeBodyVi,
      incompleteOnboardingNoticeBodyEn,
      incompleteOnboardingNoticeContinueVi,
      incompleteOnboardingNoticeContinueEn,
    ];

    for (final text in copy) {
      expect(text, isNot(matches(RegExp(r'[-–—]'))));
    }
  });
}
