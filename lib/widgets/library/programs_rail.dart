// ProgramsRail — horizontal-scrolling rail of program cards on the Library
// sheet. Three tonal treatments to break monotony:
//   • current — cream raised + yellow accent stripe (active program)
//   • dark    — warm-dark on cream (anchor card)
//   • cream   — cream raised, default
//
// Mirrors `ProgramsRail` and `ProgramCard` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/library_mock.dart';
import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';

class ProgramsRail extends StatelessWidget {
  const ProgramsRail({super.key, required this.programs});

  final List<ProgramMock> programs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const PageScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        itemCount: programs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) => _ProgramCard(program: programs[idx]),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});

  final ProgramMock program;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final isDark = program.tone == ProgramTone.dark;
    final isCurrent = program.tone == ProgramTone.current;

    final surface = isDark ? c.bgInverse : c.bgRaised;
    final ink = isDark ? c.invInk : c.ink;
    final inkSoft = isDark ? c.invInkSoft : c.inkSoft;
    final inkFnt = isDark ? c.invInkFaint : c.inkFaint;
    final brd = isDark ? c.borderDark : c.border;

    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: brd),
        ),
        child: Stack(
          children: [
            if (isCurrent)
              Positioned(
                left: 0,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${program.idx} / 04',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: inkFnt,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ),
                    if (program.tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? c.yellow
                              : (isDark ? c.invInk : c.ink),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          program.tag!.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isCurrent
                                ? c.yellowInk
                                : (isDark ? c.ink : c.bg),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1,
                          height: 1,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        program.tagline,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: brd)),
                  ),
                  child: Row(
                    children: [
                      _ProgramMeta(value: program.dur, dark: isDark),
                      Text(
                        '  ↘  ',
                        style: TextStyle(color: inkFnt, fontSize: 8),
                      ),
                      _ProgramMeta(value: program.sessions, dark: isDark),
                      Text(
                        '  ↘  ',
                        style: TextStyle(color: inkFnt, fontSize: 8),
                      ),
                      Flexible(
                        child: _ProgramMeta(value: program.diff, dark: isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramMeta extends StatelessWidget {
  const _ProgramMeta({required this.value, required this.dark});

  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: dark ? c.invInk.withValues(alpha: 0.78) : c.inkSoft,
        fontFeatures: VikaIvoryMain.tabularFigures,
      ),
    );
  }
}
