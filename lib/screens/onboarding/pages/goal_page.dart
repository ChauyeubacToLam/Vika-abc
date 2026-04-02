import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class GoalPage extends StatefulWidget {
  const GoalPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  static const _goals = [
    (
      id: 'health',
      title: 'Sức khỏe',
      desc: 'Dẻo dai, ít đau mỏi',
      color: VF.accent,
      icon: Icons.favorite_border_rounded,
    ),
    (
      id: 'body',
      title: 'Vóc dáng',
      desc: 'Giảm mỡ, săn chắc',
      color: VF.coral,
      icon: Icons.accessibility_new_rounded,
    ),
    (
      id: 'strength',
      title: 'Sức mạnh',
      desc: 'Cơ bắp, sức bền',
      color: VF.blue,
      icon: Icons.fitness_center_rounded,
    ),
    (
      id: 'flexible',
      title: 'Linh hoạt',
      desc: 'Mềm dẻo, an toàn',
      color: VF.amber,
      icon: Icons.self_improvement_rounded,
    ),
  ];

  static const _durations = [
    (id: '<3m', label: '< 3 tháng', subtitle: 'Mới bắt đầu'),
    (id: '3-11m', label: '3-11 tháng', subtitle: 'Đang quen'),
    (id: '1y+', label: '1 năm+', subtitle: 'Đã lâu'),
  ];

  bool get _canContinue =>
      widget.data.goal != null && widget.data.trainingDuration != null;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return ColoredBox(
      color: VF.bg,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 6 * s,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VF.accent,
                    VF.jadeGlow.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              VFOnboardingNavBar(
                current: 2,
                total: 10,
                onBack: widget.onBack,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(8 * s, 4 * s, 8 * s, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BƯỚC 2',
                              style: VF.textStyle(
                                context,
                                size: 10,
                                weight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: VF.textMuted,
                              ),
                            ),
                            SizedBox(height: 8 * s),
                            Text(
                              'Mục tiêu chính?',
                              style: VF.textStyle(
                                context,
                                size: 28,
                                weight: FontWeight.w900,
                                color: VF.text,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 8 * s),
                            Text(
                              'Chọn 1 để VinaFit xây lộ trình phù hợp',
                              style: VF.textStyle(
                                context,
                                size: 13,
                                weight: FontWeight.w500,
                                color: VF.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20 * s),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10 * s,
                          mainAxisSpacing: 10 * s,
                          childAspectRatio: 1.10,
                        ),
                        itemCount: _goals.length,
                        itemBuilder: (context, index) =>
                            _buildGoalTile(_goals[index]),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: widget.data.goal == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: EdgeInsets.only(top: 22 * s),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: 4 * s, bottom: 14 * s),
                                      child: Text(
                                        'Bạn đã tập được bao lâu rồi?',
                                        style: VF.textStyle(
                                          context,
                                          size: 20,
                                          weight: FontWeight.w700,
                                          color: VF.text,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: VF.surface,
                                        borderRadius:
                                            BorderRadius.circular(18 * s),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                            blurRadius: 8 * s,
                                            offset: Offset(0, 4 * s),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: _durations
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final item = entry.value;
                                          final selected =
                                              widget.data.trainingDuration ==
                                                  item.id;
                                          return Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => widget.data
                                                    .trainingDuration = item.id,
                                              ),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 16 * s,
                                                  horizontal: 4 * s,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? VF.accentSoft
                                                      : Colors.transparent,
                                                  border: Border(
                                                    right: index <
                                                            _durations.length -
                                                                1
                                                        ? const BorderSide(
                                                            color: VF.bg,
                                                          )
                                                        : BorderSide.none,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      item.label,
                                                      style: VF.textStyle(
                                                        context,
                                                        size: 16,
                                                        weight: FontWeight.w800,
                                                        letterSpacing: -0.3,
                                                        color: selected
                                                            ? VF.text
                                                            : VF.textSec,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2 * s),
                                                    Text(
                                                      item.subtitle,
                                                      style: VF.textStyle(
                                                        context,
                                                        size: 9,
                                                        weight: FontWeight.w600,
                                                        color: selected
                                                            ? VF.accent
                                                            : VF.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              if (_canContinue)
                VFOnboardingButton(
                  label: 'Tiếp theo',
                  onTap: widget.onNext,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalTile(
    ({
      String id,
      String title,
      String desc,
      Color color,
      IconData icon,
    }) goal,
  ) {
    final s = VF.scale(context);
    final selected = widget.data.goal == goal.id;
    return VFBottomAccentTile(
      selected: selected,
      accentColor: goal.color,
      onTap: () => setState(() => widget.data.goal = goal.id),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 20 * s, 16 * s, 16 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48 * s,
              height: 48 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15 * s),
                color: (selected ? goal.color : VF.textMuted)
                    .withValues(alpha: selected ? 0.12 : 0.06),
              ),
              alignment: Alignment.center,
              child: Icon(
                goal.icon,
                size: 24 * s,
                color: selected ? goal.color : VF.textMuted,
              ),
            ),
            SizedBox(height: 14 * s),
            Text(
              goal.title,
              style: VF.textStyle(
                context,
                size: 17,
                weight: FontWeight.w800,
                letterSpacing: -0.4,
                color: selected ? VF.text : VF.textSec,
              ),
            ),
            SizedBox(height: 3 * s),
            Text(
              goal.desc,
              style: VF.textStyle(
                context,
                size: 11,
                weight: FontWeight.w500,
                color: VF.textMuted,
                height: 1.4,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
