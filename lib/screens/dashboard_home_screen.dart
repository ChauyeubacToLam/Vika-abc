import 'package:flutter/material.dart';

import '../models/exercise_lookup.dart';
import '../services/user_program_service.dart';
import '../theme/vf_theme.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/vf_primitives.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({
    super.key,
    required this.bottomPadding,
    required this.onOpenBrowser,
    this.program,
  });

  final double bottomPadding;
  final VoidCallback onOpenBrowser;
  final UserProgramData? program;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final now = DateTime.now();
    final activeWorkout = _resolveHeroWorkout(now);
    final userName = (program?.userName ?? '').trim().isEmpty
        ? 'Nam'
        : program!.userName.trim();
    final weekStrip = _buildWeekStrip(
      program?.workoutDays ?? const [0, 2, 4],
      now,
    );

    return SingleChildScrollView(
      key: const PageStorageKey<String>('dashboard-home-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào, $userName',
                        style: VFTheme.textStyle(
                          context,
                          size: 26,
                          weight: FontWeight.w900,
                          color: VFTheme.text,
                          letterSpacing: -1.2,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 2 * s),
                      Text(
                        _formatHeaderDate(now),
                        style: VFTheme.textStyle(
                          context,
                          size: 13,
                          weight: FontWeight.w500,
                          color: VFTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * s,
                        vertical: 8 * s,
                      ),
                      decoration: BoxDecoration(
                        color: VFTheme.jadeMist,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${program?.workoutDays.length ?? 3} buổi/tuần',
                        style: VFTheme.textStyle(
                          context,
                          size: 12,
                          weight: FontWeight.w700,
                          color: VFTheme.jadeDark,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    const VFGradientAvatar(label: 'N'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 0),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * s,
                vertical: 9 * s,
              ),
              decoration: BoxDecoration(
                color: VFTheme.jadeMist,
                borderRadius: BorderRadius.circular(12 * s),
              ),
              child: Row(
                children: [
                  Text(
                    '🔥',
                    style: TextStyle(fontSize: 17 * s, height: 1),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    child: Text(
                      activeWorkout == null
                          ? 'Sẵn sàng cho chương trình đầu tiên'
                          : 'Bài tập hôm nay đã sẵn sàng',
                      style: VFTheme.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: VFTheme.jadeMid,
                      ),
                    ),
                  ),
                  Text(
                    UserProgramService.levelLabel(program?.level ?? 'beginner'),
                    style: VFTheme.textStyle(
                      context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: VFTheme.jade.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 0, 18 * s, 0),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * s,
                vertical: 12 * s,
              ),
              decoration: BoxDecoration(
                color: VFTheme.surface,
                borderRadius: BorderRadius.circular(20 * s),
                border: Border.all(color: VFTheme.hairline),
              ),
              child: Row(
                children: weekStrip
                    .map(
                      (day) => Expanded(
                        child: _WeekStripDay(
                          label: day.label,
                          status: day.status,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 0, 18 * s, 0),
            child: _WorkoutHero(
              workout: activeWorkout,
              isPro: program?.isPro ?? false,
              levelLabel: UserProgramService.levelLabel(
                program?.level ?? 'beginner',
              ),
              weekdayLabel: _heroWeekdayLabel(
                now,
                (program?.workoutDays ?? const <int>[]).contains(now.weekday - 1),
              ),
              onStart: () => _startWorkout(context, activeWorkout),
              onBrowse: onOpenBrowser,
            ),
          ),
          SizedBox(height: 6 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 0, 18 * s, 0),
            child: _FormProgressCard(scale: s),
          ),
          SizedBox(height: 24 * s),
        ],
      ),
    );
  }

  UserWorkoutData? _resolveHeroWorkout(DateTime now) {
    final data = program;
    if (data == null || data.workouts.isEmpty || data.workoutDays.isEmpty) {
      return null;
    }

    final today = now.weekday - 1;
    final todayIndex = data.workoutDays.indexOf(today);
    if (todayIndex != -1) {
      return data.workouts[todayIndex % data.workouts.length];
    }

    for (var index = 0; index < data.workoutDays.length; index++) {
      if (data.workoutDays[index] > today) {
        return data.workouts[index % data.workouts.length];
      }
    }

    return data.workouts.first;
  }

  List<_WeekDayData> _buildWeekStrip(List<int> workoutDays, DateTime now) {
    final today = now.weekday - 1;
    return List.generate(7, (index) {
      final status = index == today
          ? _WeekDayStatus.today
          : workoutDays.contains(index) && index < today
              ? _WeekDayStatus.done
              : _WeekDayStatus.future;
      return _WeekDayData(_weekdayShort(index), status);
    });
  }

  String _weekdayShort(int index) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final safeIndex = index < 0
        ? 0
        : index >= labels.length
            ? labels.length - 1
            : index;
    return labels[safeIndex];
  }

  String _heroWeekdayLabel(DateTime now, bool todayHasWorkout) {
    if (todayHasWorkout) {
      return 'HÔM NAY';
    }
    final today = now.weekday - 1;
    final days = program?.workoutDays ?? const <int>[];
    for (final day in days) {
      if (day > today) {
        return _weekdayShort(day);
      }
    }
    return days.isEmpty ? 'T2' : _weekdayShort(days.first);
  }

  String _formatHeaderDate(DateTime now) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month}';
  }

  void _startWorkout(BuildContext context, [UserWorkoutData? workout]) {
    final plannedExercises = workout?.exercises ?? const <UserExerciseData>[];
    for (final exercise in plannedExercises) {
      if (exercise.isCorrective) {
        continue;
      }
      final definition = lookupExerciseDefinition(exercise.name);
      if (definition == null) {
        continue;
      }
      Navigator.of(context).pushNamed('/exercise', arguments: definition);
      return;
    }

    const fallbackNames = ['Squat', 'Push-up', 'Plank', 'Lunge'];
    for (final name in fallbackNames) {
      final definition = lookupExerciseDefinition(name);
      if (definition == null) {
        continue;
      }
      Navigator.of(context).pushNamed('/exercise', arguments: definition);
      return;
    }

    onOpenBrowser();
  }
}

class _WorkoutHero extends StatelessWidget {
  const _WorkoutHero({
    required this.onStart,
    required this.onBrowse,
    required this.weekdayLabel,
    required this.levelLabel,
    required this.isPro,
    this.workout,
  });

  final VoidCallback onStart;
  final VoidCallback onBrowse;
  final String weekdayLabel;
  final String levelLabel;
  final bool isPro;
  final UserWorkoutData? workout;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final activeWorkout = workout;
    final heroTitle = activeWorkout?.title ?? 'Toàn thân';
    final heroDuration = activeWorkout?.duration ?? '15 phút';
    final heroExercises = activeWorkout?.exercises ??
        const [
          UserExerciseData(name: 'Squat', sets: '3×8', pose: 'squat'),
          UserExerciseData(name: 'Push-up', sets: '3×6', pose: 'pushup'),
          UserExerciseData(name: 'Plank', sets: '3×20s', pose: 'plank'),
          UserExerciseData(name: 'Lunge', sets: '3×8', pose: 'lunge'),
        ];
    final count = heroExercises.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24 * s),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: VFTheme.jadeCardGradient),
            ),
          ),
          const Positioned.fill(child: VFGrainOverlay()),
          Positioned(
            top: -30 * s,
            right: -20 * s,
            child: Container(
              width: 140 * s,
              height: 140 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VFTheme.jadeGlow.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22 * s, 26 * s, 22 * s, 22 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$weekdayLabel · TUẦN 1',
                        style: VFTheme.textStyle(
                          context,
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.35),
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * s,
                        vertical: 3 * s,
                      ),
                      decoration: BoxDecoration(
                        color: VFTheme.jadeGlow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6 * s),
                        border: Border.all(
                          color: VFTheme.jadeGlow.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        levelLabel,
                        style: VFTheme.textStyle(
                          context,
                          size: 10,
                          weight: FontWeight.w700,
                          color: VFTheme.jadeGlow,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10 * s),
                Text(
                  heroTitle,
                  style: VFTheme.textStyle(
                    context,
                    size: 30,
                    weight: FontWeight.w900,
                    color: VFTheme.white,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
                SizedBox(height: 5 * s),
                Text(
                  '$count bài · $heroDuration · Camera bên',
                  style: VFTheme.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 20 * s),
                  padding: EdgeInsets.fromLTRB(4 * s, 14 * s, 4 * s, 12 * s),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (var index = 0; index < heroExercises.length; index++) ...[
                        Expanded(
                          child: _HeroExerciseTile(
                            name: heroExercises[index].name,
                            type: UserProgramService.silhouetteType(
                              heroExercises[index].pose,
                            ),
                            tracked: !heroExercises[index].isCorrective,
                            locked:
                                heroExercises[index].isCorrective && !isPro,
                          ),
                        ),
                        if (index < heroExercises.length - 1)
                          SizedBox(width: 6 * s),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4 * s,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    Text(
                      '0/$count bài',
                      style: VFTheme.textStyle(
                        context,
                        size: 9.5,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12 * s),
                Row(
                  children: [
                    Expanded(
                      child: _HeroActionButton(
                        label: 'Bắt đầu',
                        onTap: onStart,
                      ),
                    ),
                    SizedBox(width: 8 * s),
                    _HeroIconButton(onTap: onBrowse),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroExerciseTile extends StatelessWidget {
  const _HeroExerciseTile({
    required this.name,
    required this.type,
    this.tracked = false,
    this.locked = false,
  });

  final String name;
  final String type;
  final bool tracked;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final premium = const Color(0xFFCBB8F0);

    return Container(
      padding: EdgeInsets.fromLTRB(2 * s, 10 * s, 2 * s, 8 * s),
      decoration: BoxDecoration(
        color: locked
            ? const Color(0xFF101512)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(
          color: locked
              ? premium.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        children: [
          PoseSilhouette(
            type: type,
            size: 38 * s,
            color: locked
                ? premium.withValues(alpha: 0.72)
                : VFTheme.jadeGlow.withValues(alpha: 0.55),
          ),
          SizedBox(height: 5 * s),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VFTheme.textStyle(
              context,
              size: 9.5,
              weight: FontWeight.w700,
              color: locked
                  ? Colors.white.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.75),
              letterSpacing: -0.1,
            ),
          ),
          if (locked) ...[
            SizedBox(height: 3 * s),
            Icon(
              Icons.lock_outline_rounded,
              size: 12 * s,
              color: premium.withValues(alpha: 0.7),
            ),
          ] else if (tracked) ...[
            SizedBox(height: 3 * s),
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
                'AI',
                style: VFTheme.textStyle(
                  context,
                  size: 7.5,
                  weight: FontWeight.w800,
                  color: VFTheme.jadeGlow.withValues(alpha: 0.7),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * s),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13 * s),
          decoration: BoxDecoration(
            color: VFTheme.white,
            borderRadius: BorderRadius.circular(14 * s),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
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
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * s),
        child: Container(
          width: 48 * s,
          height: 48 * s,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          alignment: Alignment.center,
          child: VFNavIcon(
            glyph: VFNavGlyph.plus,
            color: Colors.white.withValues(alpha: 0.55),
            size: 18 * s,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _FormProgressCard extends StatelessWidget {
  const _FormProgressCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 18 * scale,
      ),
      decoration: BoxDecoration(
        color: VFTheme.surface,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: VFTheme.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64 * scale,
            height: 64 * scale,
            child: CustomPaint(painter: _AngleImprovementPainter()),
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cải thiện tốt nhất tuần này',
                  style: VFTheme.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w600,
                    color: VFTheme.textMuted,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+12°',
                      style: VFTheme.textStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w900,
                        color: VFTheme.text,
                        letterSpacing: -1.8,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Padding(
                      padding: EdgeInsets.only(bottom: 3 * scale),
                      child: Text(
                        'sâu hơn',
                        style: VFTheme.textStyle(
                          context,
                          size: 13,
                          weight: FontWeight.w700,
                          color: VFTheme.jade,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'Squat depth · Plank +8s · Push-up +6°',
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
          SizedBox(width: 12 * scale),
          Container(
            width: 36 * scale,
            height: 36 * scale,
            decoration: BoxDecoration(
              color: VFTheme.jadeMist,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18 * scale,
              color: VFTheme.jade,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStripDay extends StatelessWidget {
  const _WeekStripDay({
    required this.label,
    required this.status,
  });

  final String label;
  final _WeekDayStatus status;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final isToday = status == _WeekDayStatus.today;
    final isDone = status == _WeekDayStatus.done;

    return Column(
      children: [
        Text(
          label,
          style: VFTheme.textStyle(
            context,
            size: 11,
            weight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday
                ? VFTheme.jade
                : isDone
                    ? VFTheme.text
                    : VFTheme.textMuted,
          ),
        ),
        SizedBox(height: 7 * s),
        Container(
          width: isDone ? 8 * s : 7 * s,
          height: isDone ? 8 * s : 7 * s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? VFTheme.jade : Colors.transparent,
            border: isToday
                ? Border.all(color: VFTheme.jade, width: 2.5 * s)
                : isDone
                    ? null
                    : Border.all(
                        color: VFTheme.textMuted.withValues(alpha: 0.25),
                        width: 1.5 * s,
                      ),
          ),
        ),
      ],
    );
  }
}

class _AngleImprovementPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64;
    final sy = size.height / 64;
    canvas.scale(sx, sy);

    final faded = Paint()
      ..color = VFTheme.coral.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final solid = Paint()
      ..color = VFTheme.jade.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = VFTheme.jadeGlow.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final before = Path()
      ..moveTo(32, 8)
      ..lineTo(22, 38)
      ..lineTo(18, 56);
    final after = Path()
      ..moveTo(32, 8)
      ..lineTo(16, 42)
      ..lineTo(12, 56);
    canvas.drawPath(before, faded);
    canvas.drawCircle(
      const Offset(22, 38),
      3,
      Paint()
        ..color = VFTheme.coral.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(after, solid);
    canvas.drawCircle(
      const Offset(16, 42),
      4,
      Paint()
        ..color = VFTheme.jade.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      const Offset(16, 42),
      4,
      Paint()
        ..color = VFTheme.jade.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      const Offset(32, 6),
      4,
      Paint()
        ..color = VFTheme.jade.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );

    final sweep = Path()
      ..moveTo(22, 38)
      ..arcToPoint(
        const Offset(16, 42),
        radius: const Radius.circular(8),
        clockwise: true,
      );
    canvas.drawPath(sweep, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _WeekDayStatus { done, today, future }

class _WeekDayData {
  const _WeekDayData(this.label, this.status);

  final String label;
  final _WeekDayStatus status;
}
