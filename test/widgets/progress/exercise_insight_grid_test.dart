import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/data/progress_mock.dart';
import 'package:vika/widgets/progress/exercise_insight_grid.dart';

// The redesigned BÀI TẬP NỔI BẬT cards are a tight 2-up grid with an animated
// bar chart. These guard the layout at real phone widths (overflow throws a
// FlutterError during a widget test, failing it) and the expand/collapse flow.
void main() {
  Widget host(Widget child, {double width = 390}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: child,
              ),
            ),
          ),
        ),
      );

  testWidgets('renders a 2-up grid, collapsed to the first 4 cards', (t) async {
    await t.pumpWidget(host(ExerciseInsightGrid(insights: progressMockInsights)));
    await t.pumpAndSettle();

    // 6 mock entries, collapsed to 4 -> 5th/6th hidden until expanded.
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Wall Push-up'), findsOneWidget);
    expect(find.text('Curl-Up'), findsNothing);
    expect(find.text('Xem tất cả 6 bài'), findsOneWidget);
  });

  testWidgets('expand reveals the rest, collapse hides them again', (t) async {
    await t.pumpWidget(host(ExerciseInsightGrid(insights: progressMockInsights)));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('Xem tất cả 6 bài'));
    await t.tap(find.text('Xem tất cả 6 bài'));
    await t.pumpAndSettle();
    expect(find.text('Curl-Up'), findsOneWidget);
    expect(find.text('Lunge'), findsOneWidget);

    await t.ensureVisible(find.text('Thu gọn'));
    await t.tap(find.text('Thu gọn'));
    await t.pumpAndSettle();
    expect(find.text('Lunge'), findsNothing);
  });

  testWidgets('survives a narrow viewport without overflow', (t) async {
    // A render overflow throws a FlutterError during pump → this fails on its
    // own if the tight 320px-wide layout breaks.
    await t.pumpWidget(
      host(ExerciseInsightGrid(insights: progressMockInsights), width: 320),
    );
    await t.pumpAndSettle();
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('empty list renders nothing', (t) async {
    await t.pumpWidget(host(const ExerciseInsightGrid(insights: [])));
    await t.pumpAndSettle();
    expect(find.byType(ExerciseInsightGrid), findsOneWidget);
    expect(find.textContaining('bài'), findsNothing);
  });
}
