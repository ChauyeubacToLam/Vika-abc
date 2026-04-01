import 'package:flutter/material.dart';

import '../models/exercise_lookup.dart';
import '../theme/vf_theme.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/vf_primitives.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int selected = 4;
  int weekIdx = 0;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final week = _weeks[weekIdx];
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
                    children: List.generate(_weeks.length, (index) {
                      final active = weekIdx == index;
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
                            _weeks[index].label,
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
                      widthFactor: week.completedWorkouts / week.totalWorkouts,
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
                    color: weekIdx == 0 ? VFTheme.jade : VFTheme.text,
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
                key:
                    ValueKey('${weekIdx}_${selected}_${day.focus}_${day.done}'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI theo dõi mỗi buổi tập',
                          style: VFTheme.textStyle(
                            context,
                            size: 12,
                            weight: FontWeight.w700,
                            color: VFTheme.jadeDark,
                          ),
                        ),
                        SizedBox(height: 2 * s),
                        Text(
                          'Tuần 2 sẽ được điều chỉnh dựa trên kết quả tuần 1. Tiếp tục tập đúng form!',
                          style: VFTheme.textStyle(
                            context,
                            size: 11,
                            weight: FontWeight.w500,
                            color: VFTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
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

  _PlanDay? _findNextWorkoutDay(List<_PlanDay> days, int currentIndex) {
    for (int index = currentIndex + 1; index < days.length; index++) {
      if (!days[index].rest) return days[index];
    }
    return null;
  }

  void _startWorkout(_PlanDay day) {
    for (final exercise in day.exercises) {
      final definition = lookupExerciseDefinition(exercise.name);
      if (definition == null) continue;
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
    final selectedColor = day.done
        ? day.color
        : day.rest
            ? VFTheme.textMuted.withValues(alpha: 0.15)
            : VFTheme.jade;

    final labelColor = selected
        ? (hasWorkout
            ? VFTheme.white.withValues(alpha: 0.6)
            : VFTheme.textMuted)
        : VFTheme.textMuted;
    final numberColor = selected
        ? (hasWorkout ? VFTheme.white : VFTheme.text)
        : day.done
            ? VFTheme.text
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

    if (day.done) {
      return Container(
        width: 6 * s,
        height: 6 * s,
        decoration: BoxDecoration(
          color: day.color.withValues(alpha: 0.6),
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
            'Cơ thể cần thời gian phục hồi. Hãy nghỉ ngơi, uống đủ nước, và ngủ đủ giấc.',
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
    final isDone = day.done;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24 * s),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDone ? VFTheme.white : null,
                    gradient: isDone ? null : VFTheme.jadeCardGradient,
                    border: isDone ? Border.all(color: VFTheme.hairline) : null,
                  ),
                ),
              ),
              if (!isDone) const Positioned.fill(child: VFGrainOverlay()),
              if (!isDone)
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
                            color: isDone
                                ? day.color.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6 * s),
                            border: Border.all(
                              color: isDone
                                  ? day.color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Text(
                            isDone
                                ? 'HOÀN THÀNH ✓'
                                : day.today
                                    ? 'HÔM NAY'
                                    : 'BUỔI ${day.workoutNumber}',
                            style: VFTheme.textStyle(
                              context,
                              size: 9,
                              weight: FontWeight.w700,
                              color: isDone ? day.color : VFTheme.jadeGlow,
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
                            color: isDone
                                ? VFTheme.textMuted
                                : Colors.white.withValues(alpha: 0.35),
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
                        color: isDone
                            ? day.color
                            : Colors.white.withValues(alpha: 0.4),
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
                        color: isDone ? VFTheme.text : VFTheme.white,
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
                        color: isDone
                            ? VFTheme.textSecondary
                            : Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 18 * s),
                      padding: EdgeInsets.fromLTRB(0, 14 * s, 0, 8 * s),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDone
                                ? VFTheme.hairline
                                : Colors.white.withValues(alpha: 0.06),
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
                                  child: _WorkoutExerciseTile(
                                    exercise: exercise,
                                    doneStyle: isDone,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
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
                                color: isDone
                                    ? VFTheme.textMuted.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6 * s),
                                border: Border.all(
                                  color: isDone
                                      ? VFTheme.textMuted
                                          .withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.04),
                                ),
                              ),
                              child: Text(
                                muscle,
                                style: VFTheme.textStyle(
                                  context,
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: isDone
                                      ? VFTheme.textSecondary
                                      : Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    if (isDone && day.result != null)
                      Container(
                        margin: EdgeInsets.only(top: 14 * s),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16 * s,
                          vertical: 14 * s,
                        ),
                        decoration: BoxDecoration(
                          color: day.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14 * s),
                          border: Border.all(
                              color: day.color.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44 * s,
                              height: 44 * s,
                              decoration: BoxDecoration(
                                color: day.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12 * s),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${day.result!.form}%',
                                style: VFTheme.textStyle(
                                  context,
                                  size: 16,
                                  weight: FontWeight.w900,
                                  color: day.color,
                                ),
                              ),
                            ),
                            SizedBox(width: 12 * s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Form score: ${day.result!.form}%',
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: VFTheme.text,
                                    ),
                                  ),
                                  SizedBox(height: 1 * s),
                                  Text(
                                    day.result!.best,
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 11,
                                      weight: FontWeight.w500,
                                      color: VFTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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
              for (int index = 0; index < contextDays.length; index++) ...[
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
    required this.doneStyle,
  });

  final _PlanExercise exercise;
  final bool doneStyle;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * s,
        vertical: 12 * s,
      ),
      decoration: BoxDecoration(
        color: doneStyle
            ? exercise.color.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(
          color: doneStyle
              ? exercise.color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40 * s,
            height: 40 * s,
            decoration: BoxDecoration(
              color: doneStyle
                  ? exercise.color.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12 * s),
            ),
            alignment: Alignment.center,
            child: PoseSilhouette(
              type: exercise.type,
              size: 28 * s,
              color: doneStyle
                  ? exercise.color.withValues(alpha: 0.6)
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
                  style: VFTheme.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: doneStyle
                        ? VFTheme.text
                        : VFTheme.white.withValues(alpha: 0.8),
                  ),
                ),
                if (exercise.ai) ...[
                  SizedBox(height: 2 * s),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5 * s,
                      vertical: 1 * s,
                    ),
                    decoration: BoxDecoration(
                      color: doneStyle
                          ? exercise.color.withValues(alpha: 0.12)
                          : VFTheme.jadeGlow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3 * s),
                    ),
                    child: Text(
                      'AI FORM',
                      style: VFTheme.textStyle(
                        context,
                        size: 7.5,
                        weight: FontWeight.w800,
                        color: doneStyle
                            ? exercise.color
                            : VFTheme.jadeGlow.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
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

    return Opacity(
      opacity: day.done ? 0.68 : 1,
      child: Material(
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
                        color: day.done
                            ? day.color
                            : day.color.withValues(alpha: 0.3),
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
                    if (day.done) ...[
                      SizedBox(width: 4 * s),
                      Text(
                        '✓',
                        style: VFTheme.textStyle(
                          context,
                          size: 8,
                          weight: FontWeight.w700,
                          color: VFTheme.textMuted,
                        ),
                      ),
                    ],
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
    this.done = false,
    this.today = false,
    this.color = VFTheme.jade,
    this.focus = '',
    this.duration = '',
    this.count = 0,
    this.workoutNumber = 0,
    this.exercises = const [],
    this.muscles = const [],
    this.result,
  });

  final int id;
  final String shortDay;
  final int number;
  final String label;
  final bool rest;
  final bool done;
  final bool today;
  final Color color;
  final String focus;
  final String duration;
  final int count;
  final int workoutNumber;
  final List<_PlanExercise> exercises;
  final List<String> muscles;
  final _WorkoutResult? result;
}

class _PlanExercise {
  const _PlanExercise({
    required this.name,
    required this.type,
    required this.color,
    this.ai = false,
  });

  final String name;
  final String type;
  final Color color;
  final bool ai;
}

class _WorkoutResult {
  const _WorkoutResult({
    required this.form,
    required this.best,
  });

  final int form;
  final String best;
}

const List<_PlanWeek> _weeks = [
  _PlanWeek(
    label: 'Tuần 1',
    completedWorkouts: 2,
    totalWorkouts: 3,
    days: [
      _PlanDay(
        id: 0,
        shortDay: 'T2',
        number: 17,
        label: 'Thứ Hai',
        done: true,
        color: VFTheme.jade,
        focus: 'Toàn thân',
        duration: '15 phút',
        count: 4,
        workoutNumber: 1,
        exercises: [
          _PlanExercise(
            name: 'Squat',
            type: 'squat',
            color: VFTheme.jade,
            ai: true,
          ),
          _PlanExercise(
            name: 'Wall Push-up',
            type: 'pushup',
            color: VFTheme.blue,
            ai: true,
          ),
          _PlanExercise(
            name: 'Plank',
            type: 'plank',
            color: VFTheme.amber,
          ),
          _PlanExercise(
            name: 'Lunge',
            type: 'lunge',
            color: VFTheme.purple,
            ai: true,
          ),
        ],
        muscles: ['Đùi', 'Mông', 'Core', 'Ngực'],
        result: _WorkoutResult(form: 76, best: 'Squat depth 108°'),
      ),
      _PlanDay(id: 1, shortDay: 'T3', number: 18, rest: true),
      _PlanDay(
        id: 2,
        shortDay: 'T4',
        number: 19,
        label: 'Thứ Tư',
        done: true,
        color: VFTheme.blue,
        focus: 'Core & Thân trên',
        duration: '12 phút',
        count: 3,
        workoutNumber: 2,
        exercises: [
          _PlanExercise(
            name: 'Wall Push-up',
            type: 'pushup',
            color: VFTheme.blue,
            ai: true,
          ),
          _PlanExercise(
            name: 'Plank',
            type: 'plank',
            color: VFTheme.amber,
          ),
          _PlanExercise(
            name: 'McGill Curl-up',
            type: 'curlup',
            color: VFTheme.coral,
            ai: true,
          ),
        ],
        muscles: ['Ngực', 'Core', 'Vai'],
        result: _WorkoutResult(form: 81, best: 'Push-up cải thiện +8°'),
      ),
      _PlanDay(id: 3, shortDay: 'T5', number: 20, rest: true),
      _PlanDay(
        id: 4,
        shortDay: 'T6',
        number: 21,
        label: 'Thứ Sáu',
        today: true,
        color: VFTheme.coral,
        focus: 'Chân & Mông',
        duration: '15 phút',
        count: 4,
        workoutNumber: 3,
        exercises: [
          _PlanExercise(
            name: 'Squat',
            type: 'squat',
            color: VFTheme.jade,
            ai: true,
          ),
          _PlanExercise(
            name: 'Lunge',
            type: 'lunge',
            color: VFTheme.purple,
            ai: true,
          ),
          _PlanExercise(
            name: 'Glute Bridge',
            type: 'bridge',
            color: VFTheme.coral,
            ai: true,
          ),
          _PlanExercise(
            name: 'Jumping Jack',
            type: 'jump',
            color: VFTheme.amber,
          ),
        ],
        muscles: ['Đùi', 'Mông', 'Hông', 'Cardio'],
      ),
      _PlanDay(id: 5, shortDay: 'T7', number: 22, rest: true),
      _PlanDay(id: 6, shortDay: 'CN', number: 23, rest: true),
    ],
  ),
  _PlanWeek(
    label: 'Tuần 2',
    completedWorkouts: 0,
    totalWorkouts: 3,
    days: [
      _PlanDay(
        id: 0,
        shortDay: 'T2',
        number: 24,
        label: 'Thứ Hai',
        color: VFTheme.jade,
        focus: 'Toàn thân',
        duration: '16 phút',
        count: 4,
        workoutNumber: 1,
        exercises: [
          _PlanExercise(
            name: 'Squat',
            type: 'squat',
            color: VFTheme.jade,
            ai: true,
          ),
          _PlanExercise(
            name: 'Push-up',
            type: 'pushup',
            color: VFTheme.blue,
            ai: true,
          ),
          _PlanExercise(
            name: 'Plank',
            type: 'plank',
            color: VFTheme.amber,
          ),
          _PlanExercise(
            name: 'Lunge',
            type: 'lunge',
            color: VFTheme.purple,
            ai: true,
          ),
        ],
        muscles: ['Đùi', 'Mông', 'Core', 'Ngực'],
      ),
      _PlanDay(id: 1, shortDay: 'T3', number: 25, rest: true),
      _PlanDay(
        id: 2,
        shortDay: 'T4',
        number: 26,
        label: 'Thứ Tư',
        color: VFTheme.blue,
        focus: 'Core & Vai',
        duration: '14 phút',
        count: 4,
        workoutNumber: 2,
        exercises: [
          _PlanExercise(
            name: 'Push-up',
            type: 'pushup',
            color: VFTheme.blue,
            ai: true,
          ),
          _PlanExercise(
            name: 'Plank',
            type: 'plank',
            color: VFTheme.amber,
          ),
          _PlanExercise(
            name: 'McGill Curl-up',
            type: 'curlup',
            color: VFTheme.coral,
            ai: true,
          ),
          _PlanExercise(
            name: 'Glute Bridge',
            type: 'bridge',
            color: VFTheme.coral,
          ),
        ],
        muscles: ['Ngực', 'Vai', 'Core'],
      ),
      _PlanDay(id: 3, shortDay: 'T5', number: 27, rest: true),
      _PlanDay(
        id: 4,
        shortDay: 'T6',
        number: 28,
        label: 'Thứ Sáu',
        color: VFTheme.coral,
        focus: 'Chân & Mông',
        duration: '16 phút',
        count: 4,
        workoutNumber: 3,
        exercises: [
          _PlanExercise(
            name: 'Squat',
            type: 'squat',
            color: VFTheme.jade,
            ai: true,
          ),
          _PlanExercise(
            name: 'Lunge',
            type: 'lunge',
            color: VFTheme.purple,
            ai: true,
          ),
          _PlanExercise(
            name: 'Glute Bridge',
            type: 'bridge',
            color: VFTheme.coral,
            ai: true,
          ),
          _PlanExercise(
            name: 'Jumping Jack',
            type: 'jump',
            color: VFTheme.amber,
          ),
        ],
        muscles: ['Đùi', 'Mông', 'Hông', 'Cardio'],
      ),
      _PlanDay(id: 5, shortDay: 'T7', number: 29, rest: true),
      _PlanDay(id: 6, shortDay: 'CN', number: 30, rest: true),
    ],
  ),
];
