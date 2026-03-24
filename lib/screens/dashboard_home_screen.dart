import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../theme/vf_theme.dart';
import '../widgets/accent_bar_card.dart';
import '../widgets/badge_pill.dart';
import '../widgets/insight_carousel.dart';
import '../widgets/section_head.dart';
import '../widgets/stat_card.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({
    super.key,
    required this.bottomPadding,
    required this.onOpenBrowser,
  });

  final double bottomPadding;
  final VoidCallback onOpenBrowser;

  ExerciseDefinition? _resolveTodayWorkoutStart() {
    for (final exercise in todayWorkout.exercises) {
      final definition = lookupExerciseDefinition(exercise.name);
      if (definition != null) {
        return definition;
      }
    }

    return null;
  }

  void _openExercise(BuildContext context, String exerciseName) {
    final definition = lookupExerciseDefinition(exerciseName);
    if (definition == null) {
      onOpenBrowser();
      return;
    }

    Navigator.of(context).pushNamed('/exercise', arguments: definition);
  }

  void _startTodayWorkout(BuildContext context) {
    final definition = _resolveTodayWorkoutStart();
    if (definition == null) {
      onOpenBrowser();
      return;
    }

    Navigator.of(context).pushNamed('/exercise', arguments: definition);
  }

  void _showPremiumPreview(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chương trình cá nhân hóa sẽ được mở ở bản cập nhật tới.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = VFTheme.screenPadding(context);
    final scale = VFTheme.scale(context);

    return SingleChildScrollView(
      key: const PageStorageKey<String>('dashboard-home-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        padding.left,
        14 * scale,
        padding.right,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào, ${dashboardUser.name}',
                      style: VFTheme.headerLarge(context),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      dashboardUser.dateLabel,
                      style: VFTheme.body(context, color: VFTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(
                  color: VFTheme.accent,
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: Text(
                  dashboardUser.initial,
                  style: TextStyle(
                    fontSize: VFTheme.font(context, 16),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          const InsightCarousel(items: homeInsights),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              for (var index = 0; index < homeMetrics.length; index++) ...[
                Expanded(
                  child: StatCard(
                    value: homeMetrics[index].value,
                    label: homeMetrics[index].label,
                    accent: homeMetrics[index].accent,
                  ),
                ),
                if (index < homeMetrics.length - 1) SizedBox(width: 6 * scale),
              ],
            ],
          ),
          SizedBox(height: 16 * scale),
          Row(
            children: weekStrip.map((day) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: day == weekStrip.last ? 0 : 4 * scale,
                  ),
                  child: _WeekStripTile(day: day),
                ),
              );
            }).toList(),
          ),
          const SectionHead(title: 'Hôm nay'),
          AccentBarCard(
            accentColor: VFTheme.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todayWorkout.label.toUpperCase(),
                            style:
                                VFTheme.label(context, color: VFTheme.accent),
                          ),
                          SizedBox(height: 3 * scale),
                          Text(
                            todayWorkout.title,
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 16),
                              fontWeight: FontWeight.w800,
                              color: VFTheme.text,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BadgePill(
                      label: todayWorkout.badge,
                      color: todayWorkout.badgeColor,
                      background: todayWorkout.badgeBackground,
                    ),
                  ],
                ),
                SizedBox(height: 10 * scale),
                Wrap(
                  spacing: 4 * scale,
                  runSpacing: 4 * scale,
                  children: todayWorkout.exercises.map((exercise) {
                    final definition = lookupExerciseDefinition(exercise.name);
                    final isSupported = definition != null;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5 * scale),
                        onTap: () => _openExercise(context, exercise.name),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale,
                            vertical: 3 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: exercise.background,
                            borderRadius: BorderRadius.circular(5 * scale),
                          ),
                          child: Text(
                            isSupported
                                ? (exercise.isAi
                                    ? '${exercise.name} · AI'
                                    : exercise.name)
                                : '${exercise.name} · Soon',
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 10),
                              fontWeight: FontWeight.w700,
                              color: exercise.color,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10 * scale),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3 * scale,
                        decoration: BoxDecoration(
                          color: VFTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(2 * scale),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: todayWorkout.progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: VFTheme.accent,
                              borderRadius: BorderRadius.circular(2 * scale),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Text(
                      todayWorkout.meta,
                      style: TextStyle(
                        fontSize: VFTheme.font(context, 9),
                        fontWeight: FontWeight.w600,
                        color: VFTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10 * scale),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Bắt đầu',
                        background: VFTheme.accent,
                        foreground: Colors.white,
                        onTap: () => _startTodayWorkout(context),
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    _IconActionButton(
                      icon: Icons.add_circle_outline_rounded,
                      color: VFTheme.textMuted,
                      background: VFTheme.surfaceAlt,
                      onTap: onOpenBrowser,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8 * scale),
          AccentBarCard(
            accentColor: VFTheme.purple,
            opacity: 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            premiumWorkout.label.toUpperCase(),
                            style:
                                VFTheme.label(context, color: VFTheme.purple),
                          ),
                          SizedBox(height: 3 * scale),
                          Text(
                            premiumWorkout.title,
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 15),
                              fontWeight: FontWeight.w800,
                              color: VFTheme.text,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const BadgePill(
                      label: 'PRO',
                      color: VFTheme.purple,
                      background: VFTheme.purpleBg,
                    ),
                  ],
                ),
                SizedBox(height: 8 * scale),
                Text(
                  premiumWorkout.description,
                  style: TextStyle(
                    fontSize: VFTheme.font(context, 11),
                    fontWeight: FontWeight.w600,
                    color: VFTheme.textSec,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Wrap(
                  spacing: 4 * scale,
                  runSpacing: 4 * scale,
                  children: premiumWorkout.tags.map((exercise) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * scale,
                        vertical: 3 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: exercise.background,
                        borderRadius: BorderRadius.circular(5 * scale),
                      ),
                      child: Text(
                        exercise.name,
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 9),
                          fontWeight: FontWeight.w700,
                          color: exercise.color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 8 * scale),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8 * scale),
                    onTap: () => _showPremiumPreview(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 8 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: VFTheme.purpleBg,
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14 * scale,
                            color: VFTheme.purple,
                          ),
                          SizedBox(width: 8 * scale),
                          Expanded(
                            child: Text(
                              'Mở khóa chương trình cá nhân',
                              style: TextStyle(
                                fontSize: VFTheme.font(context, 12),
                                fontWeight: FontWeight.w700,
                                color: VFTheme.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _WeekStripTile extends StatelessWidget {
  const _WeekStripTile({required this.day});

  final WeekStripDay day;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    final background = day.isDone
        ? VFTheme.accent
        : day.isToday
            ? Colors.transparent
            : VFTheme.surfaceAlt;
    final foreground = day.isDone
        ? Colors.white
        : day.isToday
            ? VFTheme.accent
            : VFTheme.textMuted;

    return Container(
      height: 38 * scale,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8 * scale),
        border:
            day.isToday ? Border.all(color: VFTheme.accent, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.label,
            style: TextStyle(
              fontSize: VFTheme.font(context, 11),
              fontWeight: FontWeight.w700,
              color: foreground,
              letterSpacing: -0.2,
            ),
          ),
          if (day.isDone)
            Icon(
              Icons.check_rounded,
              size: 10 * scale,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8 * scale),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10 * scale),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: VFTheme.font(context, 13),
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8 * scale),
        onTap: onTap,
        child: Container(
          width: 38 * scale,
          height: 38 * scale,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          child: Icon(
            icon,
            size: 16 * scale,
            color: color,
          ),
        ),
      ),
    );
  }
}
