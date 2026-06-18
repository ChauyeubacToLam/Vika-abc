// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vika/screens/onboarding/v5/screens/s01_welcome.dart';

void main() {
  testWidgets('Vika onboarding entry renders core CTA and copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: S01Welcome(onNext: () {})),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('VIKA'), findsOneWidget);
    expect(find.text('Bắt đầu hành trình'), findsOneWidget);
    expect(
      find.text('CAMERA AI  ·  Theo dõi form trong THỜI GIAN THỰC'),
      findsOneWidget,
    );
  });
}
