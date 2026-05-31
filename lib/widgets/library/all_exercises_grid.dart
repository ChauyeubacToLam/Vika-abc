// AllExercisesGrid — filter chip row + dense list of every exercise. The
// completionist tab for "I just want to find Squat".
//
// Mirrors `AllExercisesGrid` and `ExerciseRow` in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/library_mock.dart';
import '../../theme/vf_theme.dart';
import '../ivory/atoms.dart';
import '../../theme/app_colors.dart';

class AllExercisesGrid extends StatefulWidget {
  const AllExercisesGrid({
    super.key,
    required this.rows,
    this.onSelectByName,
  });

  final List<AllExerciseRowMock> rows;

  /// Tap callback. Receives the row's `definitionName` (or null for yoga
  /// entries that don't yet map to a real ExerciseDefinition). The
  /// ExerciseBrowser uses this to look up the real definition and push
  /// /exercise.
  final void Function(String? definitionName)? onSelectByName;

  @override
  State<AllExercisesGrid> createState() => _AllExercisesGridState();
}

class _AllExercisesGridState extends State<AllExercisesGrid> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips.
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: libraryMockFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final f = libraryMockFilters[idx];
              return _FilterChip(
                label: f.label,
                count: f.count,
                active: _filter == f.id,
                onTap: () => setState(() => _filter = f.id),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // Rows.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final r in widget.rows) ...[
                _ExerciseRow(
                  row: r,
                  onTap: () => widget.onSelectByName?.call(r.definitionName),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        // Show-more sentinel.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.borderHi),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem thêm 92 bài',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: c.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lọc theo nhu cầu hoặc tìm theo tên',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: c.bg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: active ? null : Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: active ? c.invInk : c.inkSoft,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? c.invInk.withValues(alpha: 0.6)
                      : c.inkSoft.withValues(alpha: 0.6),
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.row, this.onTap});

  final AllExerciseRowMock row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: c.bgRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  row.idx.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: row.yoga ? c.powder : c.bgInverse,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: PoseGlyph(type: row.glyph, size: 22, dark: !row.yoga),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: c.ink,
                            ),
                          ),
                        ),
                        if (row.ai) ...[
                          const SizedBox(width: 6),
                          const AIDot(small: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${row.cat} · ${row.diff}',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: c.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
