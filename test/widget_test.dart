// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vika/main.dart';

void main() {
  testWidgets('Vika home screen renders exercise cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VikaApp());
    await tester.pumpAndSettle();

    expect(find.text('VIKA'), findsOneWidget);
    expect(find.text('Chọn bài tập'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Nhảy Dạng'), findsOneWidget);
    expect(find.text('Push Up'), findsOneWidget);
  });
}
