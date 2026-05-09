import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exercise_lookup.dart';
import '../services/user_program_service.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/vf_primitives.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
  });

  final double bottomPadding;
  final UserProgramData? program;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late int selected;
  int weekIdx = 0;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    selected = DateTime.now().weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final weeks = _buildWeeks();
    final activeWeekIdx = weekIdx < 0
        ? 0
        : weekIdx >= weeks.length
            ? weeks.length - 1
            : weekIdx;
    final week = weeks[activeWeekIdx];
    final day = week.days[selected];
    final nextWorkoutDay = _findNextWorkoutDay(week.days, selected);
    final contextDays = week.days
        .where((item) => !item.rest && item.id != day.id)
        .take(2)
        .toList();

    return SingleChildScrollView(
      key: const PageStorageKey<String>('plan-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kế hoạch',
                    style: VFTheme.textStyle(
                      context,
                      size: 26,
                      weight: FontWeight.w900,
                      color: VFTheme.text,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(3 * s),
                  decoration: BoxDecoration(
                    color: VFTheme.surface,
                    borderRadius: BorderRadius.circular(10 * s),
                    border: Border.all(color: VFTheme.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(weeks.length, (index) {
                      final active = activeWeekIdx == index;
                      return GestureDetector(
                        onTap: () => setState(() => weekIdx = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14 * s,
                            vertical: 5 * s,
                          ),
                          decoration: BoxDecoration(
                            color: active ? VFTheme.jade : Colors.transparent,
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                          child: Text(
                            weeks[index].label,
                            style: VFTheme.textStyle(
                              context,
                              size: 11,
                              weight: FontWeight.w700,
                              color: active ? VFTheme.white : VFTheme.textMuted,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 0),
            child: Row(
              children: [
                Text(
                  '${week.completedWorkouts}/${week.totalWorkouts} buổi',
                  style: VFTheme.textStyle(
                    context,
                    size: 10,
                    weight: FontWeight.w700,
                    color: VFTheme.textMuted,
                  ),
                ),
                SizedBox(width: 8 * s),
                Expanded(
                  child: Container(
                    height: 4 * s,
                    decoration: BoxDecoration(
                      color: VFTheme.textMuted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: week.totalWorkouts == 0
                          ? 0
                          : week.completedWorkouts / week.totalWorkouts,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: VFTheme.jadeProgressGradient,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * s),
                Text(
                  week.label,
                  style: VFTheme.textStyle(
                    context,
                    size: 10,
                    weight: FontWeight.w700,
                    color: activeWeekIdx == 0 ? VFTheme.jade : VFTheme.text,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 0),
            child: Container(
              padding: EdgeInsets.fromLTRB(6 * s, 10 * s, 6 * s, 10 * s),
              decoration: BoxDecoration(
                color: VFTheme.surface,
                borderRadius: BorderRadius.circular(20 * s),
                border: Border.all(color: VFTheme.hairline),
              ),
              child: Row(
                children: week.days
                    .map(
                      (item) => Expanded(
                        child: _DateSelectorDay(
                          day: item,
                          selected: selected == item.id,
                          onTap: () => setState(() => selected = item.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offset,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('${activeWeekIdx}_${selected}_${day.focus}'),
                child: day.rest
                    ? _RestStage(nextWorkoutDayLabel: nextWorkoutDay?.shortDay)
                    : _WorkoutStage(
                        day: day,
                        contextDays: contextDays,
                        onSelectDay: (id) => setState(() => selected = id),
                        onStart: () => _startWorkout(day),
                      ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 24 * s),
            child: Container(
              padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
              decoration: BoxDecoration(
                color: VFTheme.jadeMist,
                borderRadius: BorderRadius.circular(18 * s),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18 * s,
                    color: VFTheme.jade,
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    child: Text(
                      'Kế hoạch này lấy từ chương trình bạn vừa được gán trong onboarding. Bài corrective vẫn khóa nếu chưa có PRO.',
                      style: VFTheme.textStyle(
                        context,
                        size: 11,
                        weight: FontWeight.w500,
                        color: VFTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_PlanWeek> _buildWeeks() {
    final program = widget.program ??
        UserProgramService.buildProgram(
          userName: '',
          level: 'beginner',
          goal: 'health',
          workoutDays: const [0, 2, 4],
          detectedIssues: const [],
          isPro: false,
        );
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const colors = [VFTheme.jade, VFTheme.blue, VFTheme.coral];

    return List.generate(2, (weekOffset) {
      final weekStart = monday.add(Duration(days: 7 * weekOffset));
      var workoutCount = 0;
      final days = List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        final workoutSlot = program.workoutDays.indexOf(index);
        if (workoutSlot == -1) {
          return _PlanDay(
            id: index,
            shortDay: _weekdayShort(index),
            number: date.day,
            label: _weekdayLong(index),
            rest: true,
            today: weekOffset == 0 && index == now.weekday - 1,
          );
        }

        final workout = program.workouts[workoutSlot % program.workouts.length];
        final color = colors[workoutSlot % colors.length];
        workoutCount++;
        return _PlanDay(
          id: index,
          shortDay: _weekdayShort(index),
          number: date.day,
          label: _weekdayLong(index),
          today: weekOffset == 0 && index == now.weekday - 1,
          color: color,
          focus: workout.title,
          duration: workout.duration,
          count: workout.exercises.length,
          workoutNumber: workoutSlot + 1,
          exercises: workout.exercises
              .map(
                (exercise) => _PlanExercise(
                  name: exercise.name,
                  type: UserProgramService.silhouetteType(exercise.pose),
                  color:
                      exercise.isCorrective ? const Color(0xFFCBB8F0) : color,
                  ai: !exercise.isCorrective,
                  locked: exercise.isCorrective && !program.isPro,
                ),
              )
              .toList(),
          muscles: workout.muscles,
          issueTag: workout.issueTag,
        );
      });

      return _PlanWeek(
        label: 'Tuần ${weekOffset + 1}',
        completedWorkouts: 0,
        totalWorkouts: workoutCount,
        days: days,
      );
    });
  }

  _PlanDay? _findNextWorkoutDay(List<_PlanDay> days, int currentIndex) {
    for (var index = currentIndex + 1; index < days.length; index++) {
      if (!days[index].rest) {
        return days[index];
      }
    }
    for (var index = 0; index < currentIndex; index++) {
      if (!days[index].rest) {
        return days[index];
      }
    }
    return null;
  }

  String _weekdayShort(int index) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return labels[index];
  }

  String _weekdayLong(int index) {
    const labels = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    return labels[index];
  }

  void _startWorkout(_PlanDay day) {
    for (final exercise in day.exercises) {
      if (exercise.locked) {
        continue;
      }
      final definition = lookupExerciseDefinition(exercise.name);
      if (definition == null) {
        continue;
      }
      Navigator.of(context).pushNamed('/exercise', arguments: definition);
      return;
    }
  }
}

class _DateSelectorDay extends StatelessWidget {
  const _DateSelectorDay({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _PlanDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final hasWorkout = !day.rest;
    final selectedColor =
        day.rest ? VFTheme.textMuted.withValues(alpha: 0.15) : VFTheme.jade;

    final labelColor = selected
        ? (hasWorkout
            ? VFTheme.white.withValues(alpha: 0.6)
            : VFTheme.textMuted)
        : VFTheme.textMuted;
    final numberColor = selected
        ? (hasWorkout ? VFTheme.white : VFTheme.text)
        : VFTheme.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.05 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(0, 8 * s, 0, 10 * s),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16 * s),
          ),
          child: Column(
            children: [
              Text(
                day.shortDay,
                style: VFTheme.textStyle(
                  context,
                  size: 9,
                  weight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              SizedBox(height: 3 * s),
              Text(
                '${day.number}',
                style: VFTheme.textStyle(
                  context,
                  size: 17,
                  weight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: numberColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4 * s),
              SizedBox(
                height: 6 * s,
                child: Center(child: _selectorDot(context, hasWorkout)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorDot(BuildContext context, bool hasWorkout) {
    final s = VFTheme.scale(context);

    if (selected) {
      return Container(
        width: 5 * s,
        height: 5 * s,
        decoration: BoxDecoration(
          color: hasWorkout
              ? VFTheme.white.withValues(alpha: 0.7)
              : VFTheme.white.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      );
    }

    if (day.today) {
      return Container(
        width: 6 * s,
        height: 6 * s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: VFTheme.jade, width: 1.5 * s),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _RestStage extends StatelessWidget {
  const _RestStage({required this.nextWorkoutDayLabel});

  final String? nextWorkoutDayLabel;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.fromLTRB(24 * s, 40 * s, 24 * s, 40 * s),
      decoration: BoxDecoration(
        color: VFTheme.surface,
        borderRadius: BorderRadius.circular(24 * s),
        border: Border.all(color: VFTheme.hairline),
      ),
      child: Column(
        children: [
          Text(
            '😴',
            style: TextStyle(fontSize: 36 * s, height: 1),
          ),
          SizedBox(height: 12 * s),
          Text(
            'Ngày nghỉ',
            style: VFTheme.textStyle(
              context,
              size: 20,
              weight: FontWeight.w900,
              color: VFTheme.text,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Cơ thể cần thời gian phục hồi. Hãy nghỉ ngơi và quay lại vào buổi kế tiếp.',
            textAlign: TextAlign.center,
            style: VFTheme.textStyle(
              context,
              size: 13,
              weight: FontWeight.w500,
              color: VFTheme.textMuted,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20 * s),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20 * s,
              vertical: 10 * s,
            ),
            decoration: BoxDecoration(
              color: VFTheme.jadeMist,
              borderRadius: BorderRadius.circular(12 * s),
            ),
            child: Text(
              'Tiếp tục vào ${nextWorkoutDayLabel ?? 'tuần sau'}',
              style: VFTheme.textStyle(
                context,
                size: 12,
                weight: FontWeight.w700,
                color: VFTheme.jade,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutStage extends StatelessWidget {
  const _WorkoutStage({
    required this.day,
    required this.contextDays,
    required this.onSelectDay,
    required this.onStart,
  });

  final _PlanDay day;
  final List<_PlanDay> contextDays;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24 * s),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: VFTheme.jadeCardGradient,
                  ),
                ),
              ),
              const Positioned.fill(child: VFGrainOverlay()),
              Positioned(
                right: -10 * s,
                bottom: -20 * s,
                child: Container(
                  width: 120 * s,
                  height: 120 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: day.color.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20 * s, 22 * s, 20 * s, 18 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 * s,
                            vertical: 3 * s,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6 * s),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Text(
                            day.today ? 'HÔM NAY' : 'BUỔI ${day.workoutNumber}',
                            style: VFTheme.textStyle(
                              context,
                              size: 9,
                              weight: FontWeight.w700,
                              color: VFTheme.jadeGlow,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          day.duration,
                          style: VFTheme.textStyle(
                            context,
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      day.label,
                      style: VFTheme.textStyle(
                        context,
                        size: 10,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2 * s),
                    Text(
                      day.focus,
                      style: VFTheme.textStyle(
                        context,
                        size: 26,
                        weight: FontWeight.w900,
                        color: VFTheme.white,
                        letterSpacing: -1.3,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 3 * s),
                    Text(
                      '${day.count} bài tập',
                      style: VFTheme.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 18 * s),
                      padding: EdgeInsets.fromLTRB(0, 14 * s, 0, 8 * s),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = 8 * s;
                          final itemWidth = (constraints.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final exercise in day.exercises)
                                SizedBox(
                                  width: itemWidth,
                                  child:
                                      _WorkoutExerciseTile(exercise: exercise),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (day.issueTag.isNotEmpty) ...[
                      SizedBox(height: 8 * s),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * s,
                          vertical: 4 * s,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFCBB8F0).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8 * s),
                          border: Border.all(
                            color:
                                const Color(0xFFCBB8F0).withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          day.issueTag,
                          style: VFTheme.textStyle(
                            context,
                            size: 10,
                            weight: FontWeight.w700,
                            color:
                                const Color(0xFFCBB8F0).withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 8 * s),
                    Wrap(
                      spacing: 5 * s,
                      runSpacing: 5 * s,
                      children: day.muscles
                          .map(
                            (muscle) => Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * s,
                                vertical: 3 * s,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6 * s),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.04),
                                ),
                              ),
                              child: Text(
                                muscle,
                                style: VFTheme.textStyle(
                                  context,
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 14 * s),
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onStart,
                          borderRadius: BorderRadius.circular(14 * s),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14 * s),
                            decoration: BoxDecoration(
                              color: VFTheme.white,
                              borderRadius: BorderRadius.circular(14 * s),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Bắt đầu buổi tập',
                              style: VFTheme.textStyle(
                                context,
                                size: 15,
                                weight: FontWeight.w800,
                                color: VFTheme.jadeDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (contextDays.isNotEmpty) ...[
          SizedBox(height: 10 * s),
          Row(
            children: [
              for (var index = 0; index < contextDays.length; index++) ...[
                Expanded(
                  child: _ContextDayCard(
                    day: contextDays[index],
                    onTap: () => onSelectDay(contextDays[index].id),
                  ),
                ),
                if (index < contextDays.length - 1) SizedBox(width: 8 * s),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _WorkoutExerciseTile extends StatelessWidget {
  const _WorkoutExerciseTile({
    required this.exercise,
  });

  final _PlanExercise exercise;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final locked = exercise.locked;
    final premium = const Color(0xFFCBB8F0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * s,
        vertical: 12 * s,
      ),
      decoration: BoxDecoration(
        color: locked
            ? const Color(0xFF101512)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(
          color: locked
              ? premium.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40 * s,
            height: 40 * s,
            decoration: BoxDecoration(
              color: locked
                  ? premium.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12 * s),
            ),
            alignment: Alignment.center,
            child: PoseSilhouette(
              type: exercise.type,
              size: 28 * s,
              color: locked
                  ? premium.withValues(alpha: 0.7)
                  : VFTheme.jadeGlow.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VFTheme.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(height: 2 * s),
                if (locked)
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 10 * s,
                        color: premium.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: 4 * s),
                      Text(
                        'PRO',
                        style: VFTheme.textStyle(
                          context,
                          size: 8,
                          weight: FontWeight.w800,
                          color: premium.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  )
                else if (exercise.ai)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5 * s,
                      vertical: 1 * s,
                    ),
                    decoration: BoxDecoration(
                      color: VFTheme.jadeGlow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3 * s),
                    ),
                    child: Text(
                      'AI FORM',
                      style: VFTheme.textStyle(
                        context,
                        size: 7.5,
                        weight: FontWeight.w800,
                        color: VFTheme.jadeGlow.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextDayCard extends StatelessWidget {
  const _ContextDayCard({
    required this.day,
    required this.onTap,
  });

  final _PlanDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16 * s),
        child: Container(
          padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
          decoration: BoxDecoration(
            color: VFTheme.surface,
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(color: VFTheme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8 * s,
                    height: 8 * s,
                    decoration: BoxDecoration(
                      color: day.color.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  Text(
                    day.shortDay,
                    style: VFTheme.textStyle(
                      context,
                      size: 10,
                      weight: FontWeight.w700,
                      color: day.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4 * s),
              Text(
                day.focus,
                style: VFTheme.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w800,
                  color: VFTheme.text,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2 * s),
              Text(
                '${day.count} bài · ${day.duration}',
                style: VFTheme.textStyle(
                  context,
                  size: 10,
                  weight: FontWeight.w500,
                  color: VFTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanWeek {
  const _PlanWeek({
    required this.label,
    required this.completedWorkouts,
    required this.totalWorkouts,
    required this.days,
  });

  final String label;
  final int completedWorkouts;
  final int totalWorkouts;
  final List<_PlanDay> days;
}

class _PlanDay {
  const _PlanDay({
    required this.id,
    required this.shortDay,
    required this.number,
    this.label = '',
    this.rest = false,
    this.today = false,
    this.color = VFTheme.jade,
    this.focus = '',
    this.duration = '',
    this.count = 0,
    this.workoutNumber = 0,
    this.exercises = const [],
    this.muscles = const [],
    this.issueTag = '',
  });

  final int id;
  final String shortDay;
  final int number;
  final String label;
  final bool rest;
  final bool today;
  final Color color;
  final String focus;
  final String duration;
  final int count;
  final int workoutNumber;
  final List<_PlanExercise> exercises;
  final List<String> muscles;
  final String issueTag;
}

class _PlanExercise {
  const _PlanExercise({
    required this.name,
    required this.type,
    required this.color,
    this.ai = false,
    this.locked = false,
  });

  final String name;
  final String type;
  final Color color;
  final bool ai;
  final bool locked;
}
