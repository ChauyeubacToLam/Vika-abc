import 'package:flutter/material.dart';

import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
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
                      'Bai tap',
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
                              text: 'AI dang san sang. ',
                              style: VFTheme.textStyle(
                                context,
                                size: 11,
                                weight: FontWeight.w700,
                                color: VFTheme.jadeDark,
                                height: 1.45,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  'Chon bai tap co san de mo truc tiep giao dien tap.',
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
                          height: 158 * s,
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
                                onSelectExercise: onSelectExercise,
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
                  '${category.subtitle} · ${category.items.length} bai',
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
    required this.onSelectExercise,
  });

  final _ExerciseCategory category;
  final _ExerciseItem item;
  final bool showAiBadge;
  final ValueChanged<ExerciseDefinition> onSelectExercise;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final definition = item.definitionQuery == null
        ? null
        : lookupExerciseDefinition(item.definitionQuery!);
    final available = definition != null;
    final onTap = definition == null
        ? null
        : () => onSelectExercise(definition);

    return Opacity(
      opacity: available ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18 * s),
          child: Container(
            width: 135 * s,
            decoration: BoxDecoration(
              color: VFTheme.surface,
              borderRadius: BorderRadius.circular(18 * s),
              border: Border.all(
                color: available
                    ? category.color.withValues(alpha: 0.10)
                    : VFTheme.hairline,
              ),
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
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12 * s,
                      10 * s,
                      12 * s,
                      12 * s,
                    ),
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
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              available
                                  ? Icons.arrow_forward_rounded
                                  : Icons.lock_outline_rounded,
                              size: 12 * s,
                              color: available
                                  ? category.color
                                  : VFTheme.textMuted,
                            ),
                            SizedBox(width: 4 * s),
                            Text(
                              available ? 'Mo bai tap' : 'Sap co',
                              style: VFTheme.textStyle(
                                context,
                                size: 9,
                                weight: FontWeight.w700,
                                color: available
                                    ? category.color
                                    : VFTheme.textMuted,
                              ),
                            ),
                          ],
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
    this.definitionQuery,
  });

  final String name;
  final String type;
  final String description;
  final String? definitionQuery;
}

const List<_ExerciseCategory> _categories = [
  _ExerciseCategory(
    label: 'AI Form Check',
    subtitle: 'Camera theo doi form',
    color: VFTheme.jade,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [VFTheme.jadeMid, VFTheme.jadeDark],
    ),
    items: [
      _ExerciseItem(
        name: 'Squat',
        type: 'squat',
        description: 'Dui · Mong · Co ban',
        definitionQuery: 'squat',
      ),
      _ExerciseItem(
        name: 'Lunge',
        type: 'lunge',
        description: 'Dui · Hong · Co ban',
        definitionQuery: 'lunge',
      ),
      _ExerciseItem(
        name: 'Wall Push-up',
        type: 'pushup',
        description: 'Nguc · Vai · Co ban',
      ),
      _ExerciseItem(
        name: 'Push-up',
        type: 'pushup',
        description: 'Nguc · Core · Trung binh',
        definitionQuery: 'push_up',
      ),
      _ExerciseItem(
        name: 'Glute Bridge',
        type: 'bridge',
        description: 'Mong · Dui sau · Co ban',
        definitionQuery: 'glute_bridge',
      ),
      _ExerciseItem(
        name: 'McGill Curl-up',
        type: 'curlup',
        description: 'Bung truoc · Co ban',
        definitionQuery: 'curl_up',
      ),
      _ExerciseItem(
         name: 'Butterfly Stretch',
          type: 'lunge', // Khai báo Silhouette Icon (dùng tạm lunge hoặc tự vẽ thêm case 'stretch' trong pose_silhouette.dart)
          description: 'Giãn cơ • Phục hồi',
          definitionQuery: 'butterfly_stretch', // <--- Phải khớp với 'id' bạn khai báo ở bước 1
      ),
       _ExerciseItem(
          name: 'Sphinx Pose',
          type: 'bridge', // Dùng tạm silhouette của bài bridge vì form khá giống
          description: 'Lưng dưới   Cột sống   Trị liệu',
          definitionQuery: 'sphinx_pose', // <--- Bắt buộc phải trùng với 'id' ở Bước 1
), 
      _ExerciseItem(
        name: 'Seated Forward Fold',
        type: 'stretch', // Render silhouette stretch
        description: 'Gân kheo   Lưng   Cơ bản', // Format theo chuẩn UI Vika
        definitionQuery: 'seated_forward_fold', // Map đúng với id trong ExerciseDefinition
      ),
      _ExerciseItem(
        name: 'Bird Dog',
        type: 'bridge',
        description: 'Core · Cân bằng',
        definitionQuery: 'bird_dog',
      ),
      _ExerciseItem(
        name: 'Sit-Up',
        type: 'curlup',
        description: 'Cơ bụng · Cơ bản',
        definitionQuery: 'sit_up',
      ),
      _ExerciseItem(
        name: 'High Plank',
        type: 'plank',
        description: 'Core · Tĩnh',
        definitionQuery: 'high_plank',
      ),
      _ExerciseItem(
        name: 'Mountain Climber',
        type: 'plank',
        description: 'Core · Cardio',
        definitionQuery: 'mountain_climber',
      ),
      _ExerciseItem(
        name: 'Superman',
        type: 'bridge',
        description: 'Lưng dưới',
        definitionQuery: 'superman',
      ),
      _ExerciseItem(
        name: 'Plank Shoulder Tap',
        type: 'plank',
        description: 'Core · Chống xoay',
        definitionQuery: 'plank_shoulder_tap',
      ),
      _ExerciseItem(
        name: 'Leg Raises',
        type: 'curlup',
        description: 'Bụng dưới',
        definitionQuery: 'leg_raise',
      ),
      _ExerciseItem(
        name: 'Reverse Crunch',
        type: 'curlup',
        description: 'Bụng dưới',
        definitionQuery: 'reverse_crunch',
      ),
      _ExerciseItem(
        name: 'V-Up',
        type: 'curlup',
        description: 'Bụng toàn diện',
        definitionQuery: 'v_up',
      ),
      _ExerciseItem(
        name: 'Lying Leg Raise',
        type: 'curlup',
        description: 'Bụng dưới',
        definitionQuery: 'lying_leg_raise',
      ),
      _ExerciseItem(
        name: 'Dead Bug',
        type: 'bridge',
        description: 'Thần kinh cơ chéo',
        definitionQuery: 'dead_bug',
      ),
      _ExerciseItem(
        name: 'Plank Up-Down',
        type: 'plank',
        description: 'Vai · Core',
        definitionQuery: 'plank_up_down',
      ),
      _ExerciseItem(
        name: 'Bear Plank',
        type: 'plank',
        description: 'Đùi trước · Core tĩnh',
        definitionQuery: 'bear_plank',
      ),
    ],
  ),
  _ExerciseCategory(
    label: 'Video huong dan',
    subtitle: 'Xem va tap theo',
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
        description: 'Tay sau · Nang cao',
      ),
      _ExerciseItem(
        name: 'Pike Push-up',
        type: 'pushup',
        description: 'Vai · Nang cao',
      ),
      _ExerciseItem(
        name: 'Donkey Kick',
        type: 'bridge',
        description: 'Mong · Co ban',
      ),
      _ExerciseItem(
        name: 'Single-leg Bridge',
        type: 'bridge',
        description: 'Mong · Trung binh',
      ),
    ],
  ),
  _ExerciseCategory(
    label: 'Dem rep va Dong ho',
    subtitle: 'Tu tap, app dem giup',
    color: VFTheme.amber,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [VFTheme.amber, Color(0xFF7A4D12)],
    ),
    items: [
      _ExerciseItem(
        name: 'Plank',
        type: 'plank',
        description: 'Core · Vai · Timer',
        definitionQuery: 'plank',
      ),
      _ExerciseItem(
        name: 'Side Plank',
        type: 'plank',
        description: 'Core ben · Timer',
      ),
      _ExerciseItem(
        name: 'Jumping Jack',
        type: 'jump',
        description: 'Cardio · Dem rep',
        definitionQuery: 'jumping_jack',
      ),
      _ExerciseItem(
        name: 'Mountain Climber',
        type: 'plank',
        description: 'Core · Cardio',
      ),
      _ExerciseItem(
        name: 'Calf Raise',
        type: 'squat',
        description: 'Bap chan · Dem rep',
      ),
      _ExerciseItem(
        name: 'Wall Sit',
        type: 'squat',
        description: 'Dui truoc · Timer',
      ),
    ],
  ),
];
