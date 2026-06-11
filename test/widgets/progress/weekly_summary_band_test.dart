import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/widgets/progress/weekly_summary_band.dart';

// The redesigned "vital strip" packs four FittedBox numerals + trend chips into
// one raised card. A render overflow throws during pump, so these fail on their
// own if the layout breaks at tight widths; they also assert the chip shows the
// compact token (not a sentence) only where a delta exists.
void main() {
  Widget host(Widget child, {double width = 390}) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      );

  const stats = [
    WeeklyStat(value: '5', label: 'Buổi tập', deltaNote: '+1'),
    WeeklyStat(value: "9h48'", label: 'Thời gian'),
    WeeklyStat(value: '74', label: 'Form TB', deltaNote: '-3đ', deltaPositive: false),
    WeeklyStat(value: '12', label: 'Ngày liên tiếp'),
  ];

  testWidgets('renders four stats with compact chips, no overflow', (t) async {
    await t.pumpWidget(
      host(const WeeklySummaryBand(stats: stats, kicker: 'TUẦN NÀY MỘT NHÌN')),
    );
    await t.pumpAndSettle();

    expect(find.text('TUẦN NÀY MỘT NHÌN'), findsOneWidget);
    expect(find.text("9h48'"), findsOneWidget);
    // Compact tokens, not "+1 vs tuần trước".
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('-3đ'), findsOneWidget);
  });

  testWidgets('survives a narrow viewport', (t) async {
    await t.pumpWidget(
      host(
        const WeeklySummaryBand(stats: stats, kicker: 'TUẦN NÀY MỘT NHÌN'),
        width: 320,
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(WeeklySummaryBand), findsOneWidget);
  });
}
