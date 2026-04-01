import 'package:flutter/material.dart';

import '../models/exercise_definition.dart';
import '../theme/vf_theme.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/vf_primitives.dart';

class ExerciseBrowser extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Material(
      color: VFTheme.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24 * s, 10 * s, 24 * s, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bài tập',
                      style: VFTheme.textStyle(
                        context,
                        size: 26,
                        weight: FontWeight.w900,
                        color: VFTheme.text,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(10 * s),
                      child: Container(
                        width: 32 * s,
                        height: 32 * s,
                        decoration: BoxDecoration(
                          color: VFTheme.surface,
                          borderRadius: BorderRadius.circular(10 * s),
                          border: Border.all(color: VFTheme.hairline),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16 * s,
                          color: VFTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18 * s, 12 * s, 18 * s, 0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * s,
                  vertical: 10 * s,
                ),
                decoration: BoxDecoration(
                  color: VFTheme.jadeMist,
                  borderRadius: BorderRadius.circular(14 * s),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14 * s,
                      color: VFTheme.jade,
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: VFTheme.textStyle(
                            context,
                            size: 11,
                            weight: FontWeight.w500,
                            color: VFTheme.jadeDark,
                            height: 1.45,
                          ),
                          children: [
                            TextSpan(
                              text: 'Core đang yếu nhất. ',
                              style: VFTheme.textStyle(
                                context,
                                size: 11,
                                weight: FontWeight.w700,
                                color: VFTheme.jadeDark,
                                height: 1.45,
                              ),
                            ),
                            const TextSpan(
                              text: 'Thử thêm Plank hoặc Curl-up.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(0, 14 * s, 0, bottomPadding),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14 * s),
                          child: _CategoryHeader(category: category),
                        ),
                        SizedBox(height: 10 * s),
                        SizedBox(
                          height: 146 * s,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 14 * s),
                            itemCount: category.items.length,
                            separatorBuilder: (_, __) => SizedBox(width: 8 * s),
                            itemBuilder: (context, itemIndex) {
                              return _ExerciseCard(
                                category: category,
                                item: category.items[itemIndex],
                                showAiBadge: index == 0,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final _ExerciseCategory category;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20 * s),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: category.gradient),
            ),
          ),
          const Positioned.fill(child: VFGrainOverlay()),
          Positioned(
            right: 6 * s,
            bottom: -8 * s,
            child: Opacity(
              opacity: 0.07,
              child: PoseSilhouette(
                type: category.items.first.type,
                size: 75 * s,
                color: VFTheme.white,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 14 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: VFTheme.textStyle(
                    context,
                    size: 18,
                    weight: FontWeight.w900,
                    color: VFTheme.white,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2 * s),
                Text(
                  '${category.subtitle} · ${category.items.length} bài',
                  style: VFTheme.textStyle(
                    context,
                    size: 10,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(height: 10 * s),
                Wrap(
                  spacing: 4 * s,
                  runSpacing: 4 * s,
                  children: [
                    for (final item in category.items.take(4))
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * s,
                          vertical: 3 * s,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6 * s),
                        ),
                        child: Text(
                          item.name,
                          style: VFTheme.textStyle(
                            context,
                            size: 9,
                            weight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    if (category.items.length > 4)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * s,
                          vertical: 3 * s,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6 * s),
                        ),
                        child: Text(
                          '+${category.items.length - 4}',
                          style: VFTheme.textStyle(
                            context,
                            size: 9,
                            weight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
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

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.category,
    required this.item,
    required this.showAiBadge,
  });

  final _ExerciseCategory category;
  final _ExerciseItem item;
  final bool showAiBadge;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      width: 135 * s,
      decoration: BoxDecoration(
        color: VFTheme.surface,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: VFTheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 68 * s,
            color: category.color.withValues(alpha: 0.06),
            child: Stack(
              children: [
                Center(
                  child: PoseSilhouette(
                    type: item.type,
                    size: 40 * s,
                    color: category.color.withValues(alpha: 0.25),
                  ),
                ),
                if (showAiBadge)
                  Positioned(
                    top: 6 * s,
                    right: 6 * s,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6 * s,
                        vertical: 2 * s,
                      ),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4 * s),
                      ),
                      child: Text(
                        'AI',
                        style: VFTheme.textStyle(
                          context,
                          size: 7,
                          weight: FontWeight.w800,
                          color: category.color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 12 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: VFTheme.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w800,
                    color: VFTheme.text,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 3 * s),
                Text(
                  item.description,
                  style: VFTheme.textStyle(
                    context,
                    size: 9,
                    weight: FontWeight.w500,
                    color: VFTheme.textMuted,
                    height: 1.35,
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

class _ExerciseCategory {
  const _ExerciseCategory({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.gradient,
    required this.items,
  });

  final String label;
  final String subtitle;
  final Color color;
  final LinearGradient gradient;
  final List<_ExerciseItem> items;
}

class _ExerciseItem {
  const _ExerciseItem({
    required this.name,
    required this.type,
    required this.description,
  });

  final String name;
  final String type;
  final String description;
}

const List<_ExerciseCategory> _categories = [
  _ExerciseCategory(
    label: 'AI Form Check',
    subtitle: 'Camera theo dõi form',
    color: VFTheme.jade,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [VFTheme.jadeMid, VFTheme.jadeDark],
    ),
    items: [
      _ExerciseItem(
          name: 'Squat', type: 'squat', description: 'Đùi · Mông · Cơ bản'),
      _ExerciseItem(
          name: 'Lunge', type: 'lunge', description: 'Đùi · Hông · Cơ bản'),
      _ExerciseItem(
          name: 'Wall Push-up',
          type: 'pushup',
          description: 'Ngực · Vai · Cơ bản'),
      _ExerciseItem(
          name: 'Push-up',
          type: 'pushup',
          description: 'Ngực · Core · Trung bình'),
      _ExerciseItem(
          name: 'Glute Bridge',
          type: 'bridge',
          description: 'Mông · Đùi sau · Cơ bản'),
      _ExerciseItem(
          name: 'McGill Curl-up',
          type: 'curlup',
          description: 'Bụng trước · Cơ bản'),
    ],
  ),
  _ExerciseCategory(
    label: 'Video hướng dẫn',
    subtitle: 'Xem và tập theo',
    color: VFTheme.blue,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [VFTheme.blue, Color(0xFF1A3D6E)],
    ),
    items: [
      _ExerciseItem(
          name: 'Diamond Push-up',
          type: 'pushup',
          description: 'Tay sau · Nâng cao'),
      _ExerciseItem(
          name: 'Pike Push-up', type: 'pushup', description: 'Vai · Nâng cao'),
      _ExerciseItem(
          name: 'Donkey Kick', type: 'bridge', description: 'Mông · Cơ bản'),
      _ExerciseItem(
          name: 'Single-leg Bridge',
          type: 'bridge',
          description: 'Mông · Trung bình'),
    ],
  ),
  _ExerciseCategory(
    label: 'Đếm rep & Đồng hồ',
    subtitle: 'Tự tập, app đếm giùm',
    color: VFTheme.amber,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [VFTheme.amber, Color(0xFF7A4D12)],
    ),
    items: [
      _ExerciseItem(
          name: 'Plank', type: 'plank', description: 'Core · Vai · Timer'),
      _ExerciseItem(
          name: 'Side Plank', type: 'plank', description: 'Core bên · Timer'),
      _ExerciseItem(
          name: 'Jumping Jack', type: 'jump', description: 'Cardio · Đếm rep'),
      _ExerciseItem(
          name: 'Mountain Climber',
          type: 'plank',
          description: 'Core · Cardio'),
      _ExerciseItem(
          name: 'Calf Raise', type: 'squat', description: 'Bắp chân · Đếm rep'),
      _ExerciseItem(
          name: 'Wall Sit', type: 'squat', description: 'Đùi trước · Timer'),
    ],
  ),
];
