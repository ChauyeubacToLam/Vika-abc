import 'package:flutter/material.dart';
import '../onboarding_data.dart';

const _cyan = Color(0xFF00E5FF);
const _blue = Color(0xFF0091EA);
const _cardBg = Color(0xFF0D1228);

class GoalPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const GoalPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  static const _goals = [
    _GoalOption(
      id: 'lose_weight',
      icon: Icons.local_fire_department,
      label: 'Giảm cân',
      desc: 'Đốt mỡ, giảm cân hiệu quả',
    ),
    _GoalOption(
      id: 'tone',
      icon: Icons.fitness_center,
      label: 'Rắn chắc cơ bắp',
      desc: 'Săn chắc, tăng sức mạnh',
    ),
    _GoalOption(
      id: 'health',
      icon: Icons.favorite_outline,
      label: 'Khỏe mạnh hơn',
      desc: 'Cải thiện sức khỏe tổng thể',
    ),
  ];

  void _select(String id) {
    data.goal = id;
    // Small delay so user sees selection highlight before advancing
    Future.delayed(const Duration(milliseconds: 300), onNext);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mục tiêu của bạn?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn mục tiêu chính để AI cá nhân hóa cho bạn',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          ..._goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GoalCard(
                  option: g,
                  selected: data.goal == g.id,
                  onTap: () => _select(g.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _GoalOption {
  final String id;
  final IconData icon;
  final String label;
  final String desc;
  const _GoalOption({
    required this.id,
    required this.icon,
    required this.label,
    required this.desc,
  });
}

class _GoalCard extends StatelessWidget {
  final _GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.08) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _cyan.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(colors: [_cyan, _blue])
                    : null,
                color: selected ? null : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                option.icon,
                color: selected ? Colors.white : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.desc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Check
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: _cyan,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
