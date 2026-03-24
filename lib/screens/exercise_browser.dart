import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../theme/vf_theme.dart';

class ExerciseBrowser extends StatefulWidget {
  const ExerciseBrowser({
    super.key,
    required this.onClose,
    required this.bottomPadding,
    required this.onSelectExercise,
  });

  final VoidCallback onClose;
  final double bottomPadding;
  final ValueChanged<ExerciseDefinition> onSelectExercise;

  @override
  State<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends State<ExerciseBrowser> {
  String _selectedGroupId = muscleGroups.first.id;

  void _handleExerciseTap(ExerciseDefinition? definition) {
    if (definition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài tập này sẽ được mở trong bản cập nhật tới.'),
        ),
      );
      return;
    }

    widget.onSelectExercise(definition);
  }

  @override
  Widget build(BuildContext context) {
    final padding = VFTheme.screenPadding(context);
    final scale = VFTheme.scale(context);
    final activeGroup =
        muscleGroups.firstWhere((group) => group.id == _selectedGroupId);
    final filteredExercises = browserExercises
        .where((exercise) => exercise.groupId == _selectedGroupId)
        .toList();

    return Container(
      color: VFTheme.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                14 * scale,
                padding.right,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bài tập',
                          style: VFTheme.headerLarge(context),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10 * scale),
                          onTap: widget.onClose,
                          child: Container(
                            width: 32 * scale,
                            height: 32 * scale,
                            decoration: BoxDecoration(
                              color: VFTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(10 * scale),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16 * scale,
                              color: VFTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14 * scale),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      10 * scale,
                      14 * scale,
                      10 * scale,
                      10 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: VFTheme.surface,
                      borderRadius:
                          BorderRadius.circular(VFTheme.cardRadius(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn nhóm cơ',
                          style: TextStyle(
                            fontSize: VFTheme.font(context, 11),
                            fontWeight: FontWeight.w700,
                            color: VFTheme.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        SizedBox(
                          height: 84 * scale,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemBuilder: (context, index) {
                              final group = muscleGroups[index];
                              final active = group.id == _selectedGroupId;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(14 * scale),
                                  onTap: () =>
                                      setState(() => _selectedGroupId = group.id),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: active ? 1 : 0.55,
                                    child: SizedBox(
                                      width: 72 * scale,
                                      child: Column(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            width: 44 * scale,
                                            height: 44 * scale,
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? group.color
                                                  : VFTheme.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      14 * scale),
                                            ),
                                            child: Icon(
                                              group.icon,
                                              size: 18 * scale,
                                              color: active
                                                  ? Colors.white
                                                  : VFTheme.textMuted,
                                            ),
                                          ),
                                          SizedBox(height: 6 * scale),
                                          Text(
                                            group.label,
                                            style: TextStyle(
                                              fontSize:
                                                  VFTheme.font(context, 10),
                                              fontWeight: FontWeight.w700,
                                              color: active
                                                  ? group.color
                                                  : VFTheme.textMuted,
                                            ),
                                          ),
                                          SizedBox(height: 1 * scale),
                                          Text(
                                            '${group.count} bài',
                                            style: TextStyle(
                                              fontSize:
                                                  VFTheme.font(context, 9),
                                              fontWeight: FontWeight.w500,
                                              color: VFTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                SizedBox(width: 6 * scale),
                            itemCount: muscleGroups.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  12 * scale,
                  padding.right,
                  widget.bottomPadding,
                ),
                children: [
                  Text(
                    '${activeGroup.label.toUpperCase()} · ${filteredExercises.length} bài tập',
                    style: VFTheme.label(context, color: activeGroup.color),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    'Chạm để mở bài có sẵn. Những bài chưa hỗ trợ sẽ được bổ sung sau.',
                    style: VFTheme.muted(context, size: 11),
                  ),
                  SizedBox(height: 10 * scale),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardHeight = (constraints.maxWidth * 0.24)
                          .clamp(84.0, 96.0)
                          .toDouble();

                      return Column(
                        children: filteredExercises.map((exercise) {
                          final definition =
                              lookupExerciseDefinition(exercise.name);
                          final isSupported = definition != null;

                          return Padding(
                            padding: EdgeInsets.only(bottom: 6 * scale),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12 * scale),
                                onTap: () => _handleExerciseTap(definition),
                                child: Opacity(
                                  opacity: isSupported ? 1 : 0.72,
                                  child: Container(
                                    height: cardHeight,
                                    decoration: BoxDecoration(
                                      color: VFTheme.surface,
                                      borderRadius:
                                          BorderRadius.circular(12 * scale),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4 * scale,
                                          color: exercise.isAi
                                              ? exercise.color
                                              : VFTheme.surfaceAlt,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              14 * scale,
                                              12 * scale,
                                              12 * scale,
                                              10 * scale,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 42 * scale,
                                                  height: 42 * scale,
                                                  decoration: BoxDecoration(
                                                    color: exercise.background,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12 * scale),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    exercise.name.substring(0, 1),
                                                    style: TextStyle(
                                                      fontSize: VFTheme.font(
                                                          context, 16),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: exercise.color,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 12 * scale),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              exercise.name,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: VFTheme
                                                                    .font(
                                                                        context,
                                                                        14),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color:
                                                                    VFTheme.text,
                                                                letterSpacing:
                                                                    -0.2,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                              width: 6 * scale),
                                                          Container(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                              horizontal:
                                                                  6 * scale,
                                                              vertical:
                                                                  1 * scale,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: exercise
                                                                  .background,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(4 *
                                                                          scale),
                                                            ),
                                                            child: Text(
                                                              isSupported
                                                                  ? (exercise.isAi
                                                                      ? 'AI'
                                                                      : 'OPEN')
                                                                  : 'SOON',
                                                              style: TextStyle(
                                                                fontSize: VFTheme
                                                                    .font(
                                                                        context,
                                                                        9),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: exercise
                                                                    .color,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 2 * scale),
                                                      Text(
                                                        exercise.muscles,
                                                        style: TextStyle(
                                                          fontSize:
                                                              VFTheme.font(
                                                                  context, 11),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              VFTheme.textMuted,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4 * scale),
                                                      Row(
                                                        children: [
                                                          ...List.generate(3,
                                                              (index) {
                                                            final active = index <
                                                                exercise
                                                                    .difficulty;
                                                            return Container(
                                                              width: 5 * scale,
                                                              height: 5 * scale,
                                                              margin:
                                                                  EdgeInsets.only(
                                                                right: 4 * scale,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: active
                                                                    ? (exercise
                                                                            .isAi
                                                                        ? exercise
                                                                            .color
                                                                        : VFTheme
                                                                            .textMuted)
                                                                    : VFTheme
                                                                        .surfaceAlt,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                            );
                                                          }),
                                                          SizedBox(
                                                              width: 2 * scale),
                                                          Text(
                                                            exercise.difficulty ==
                                                                    1
                                                                ? 'Cơ bản'
                                                                : exercise.difficulty ==
                                                                        2
                                                                    ? 'Trung bình'
                                                                    : 'Nâng cao',
                                                            style: TextStyle(
                                                              fontSize: VFTheme
                                                                  .font(context,
                                                                      9),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: VFTheme
                                                                  .textMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  isSupported
                                                      ? Icons
                                                          .play_circle_fill_rounded
                                                      : Icons
                                                          .lock_outline_rounded,
                                                  size: 18 * scale,
                                                  color: isSupported
                                                      ? exercise.color
                                                      : VFTheme.textMuted,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
