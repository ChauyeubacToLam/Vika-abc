import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../vf_theme.dart';

class GoalPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;
  const GoalPage(
      {super.key,
      required this.data,
      required this.onNext,
      required this.onBack});

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  static const _goals = [
    _Goal('lose_weight', '🔥', Color(0xFFF97316), Color(0xFFFFF7ED), 'Giảm cân',
        'Đốt mỡ hiệu quả tại nhà'),
    _Goal('tone', '💪', Color(0xFF0891B2), Color(0xFFE0F7FA), 'Rắn chắc',
        'Tăng sức mạnh, săn chắc cơ thể'),
    _Goal('health', '🌿', Color(0xFF10B981), Color(0xFFD1FAE5), 'Khỏe mạnh',
        'Cải thiện sức khỏe tổng thể'),
  ];

  void _select(String id) {
    setState(() => widget.data.goal = id);
    Future.delayed(const Duration(milliseconds: 250), widget.onNext);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VFProgressBar(current: 1, total: 1, onBack: widget.onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mục tiêu của bạn là gì?',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: VF.text,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('Chọn mục tiêu chính để AI xây dựng chương trình',
                    style: TextStyle(color: VF.textMuted, fontSize: 13)),
                const SizedBox(height: 28),
                ..._goals.map((g) => _buildCard(g)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(_Goal g) {
    final on = widget.data.goal == g.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _select(g.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: on ? g.bg : VF.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: on ? g.color.withValues(alpha: 0.4) : VF.border,
                width: 2),
            boxShadow: on
                ? [
                    BoxShadow(
                        color: g.color.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ]
                : VF.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: on ? g.color.withValues(alpha: 0.1) : VF.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(g.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: VF.text)),
                    const SizedBox(height: 2),
                    Text(g.desc,
                        style: const TextStyle(
                            fontSize: 12.5, color: VF.textMuted)),
                  ],
                ),
              ),
              if (on)
                Container(
                  width: 24,
                  height: 24,
                  decoration:
                      BoxDecoration(color: g.color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Goal {
  final String id, emoji, label, desc;
  final Color color, bg;
  const _Goal(this.id, this.emoji, this.color, this.bg, this.label, this.desc);
}
