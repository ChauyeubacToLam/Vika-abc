// Smoke tests for the completion-anchored Plan redesign widgets.
//
// They render the service-free widgets at a phone-width surface and assert
// they build without layout overflow / paint exceptions, and that the core
// completion-model affordances are present: the dark hero anchors on the
// current block + single CTA; the rich session ledger shows done form scores +
// difficulty + an unmistakable NEXT and expands per-exercise; and the retest
// is folded into the ledger as a completion-locked final session.
// (The hero pulls WordmarkHeader, which loads a profile service when the
// initial is 'N', so the hero test passes a non-'N' initial.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/data/program_mock.dart';
import 'package:vika/widgets/plan/program/program_session_ledger.dart';
import 'package:vika/widgets/plan/program/program_stage_hero.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Future<void> _phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  final program = loadMockProgramPlan();
  final currentBlock = program.currentBlock;

  testWidgets(
      'session ledger: form + difficulty on done, unmistakable NEXT, expand',
      (tester) async {
    await _phoneSurface(tester);
    var expanded = -1;
    var startCount = 0;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => ProgramSessionLedger(
            block: currentBlock,
            expandedIndex: expanded == -1 ? null : expanded,
            onToggleExpand: (i) =>
                setState(() => expanded = expanded == i ? -1 : i),
            onStartNext: () => startCount++,
          ),
        ),
      ),
    );

    // NEXT session is labelled, done session shows its logged difficulty.
    expect(find.textContaining('TIẾP THEO'), findsWidgets);
    expect(find.text('Vừa sức'), findsWidgets);
    // Done session exposes its form score (ring numeral). Block 3 · Buổi 01 = 81.
    expect(find.text('81'), findsOneWidget);

    // Tapping the NEXT card fires the single launch callback.
    await tester.tap(find.text('Bắt đầu Buổi 02'));
    await tester.pumpAndSettle();
    expect(startCount, 1);

    // Expanding the done session reveals its per-exercise form bars.
    await tester.tap(find.text('BUỔI 01'));
    await tester.pumpAndSettle();
    expect(find.text('Squat'), findsWidgets);
  });

  testWidgets('retest is folded into the last block as a locked final session',
      (tester) async {
    await _phoneSurface(tester);
    await tester.pumpWidget(
      _host(
        ProgramSessionLedger(
          block: program.blocks.last,
          expandedIndex: null,
          onToggleExpand: (_) {},
          onStartNext: () {},
          retest: program.retest,
          retestUnlocked: program.allBlocksDone,
          onStartRetest: null,
        ),
      ),
    );

    expect(program.allBlocksDone, isFalse);
    expect(find.text('CHẶNG CUỐI'), findsOneWidget);
    expect(find.text('Mở khi hoàn tất Phục hồi'), findsOneWidget);
  });

  testWidgets('stage hero anchors on the current block and the one halo CTA',
      (tester) async {
    await _phoneSurface(tester);
    var started = 0;
    var selected = program.currentBlockIndex;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => ProgramStageHero(
            program: program,
            selectedIndex: selected,
            onSelectBlock: (i) => setState(() => selected = i),
            onStartNext: () => started++,
            // Non-'N' initial skips WordmarkHeader's profile-service load.
            userInitial: 'A',
          ),
        ),
      ),
    );
    // The bezel pulse repeats forever, so pump frames rather than settle.
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('NỀN TẢNG'), findsWidgets);
    expect(find.text('Bắt đầu Buổi 02'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu Buổi 02'));
    await tester.pump();
    expect(started, 1);
  });
}
