import 'package:flutter/material.dart';
import '../onboarding_data.dart';

const _cyan = Color(0xFF00E5FF);
const _cardBg = Color(0xFF0D1228);

class TimePage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const TimePage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  static const _options = [
    _TimeOption(
      id: '10',
      label: '10 phút/ngày',
      desc: 'Bận rộn? Vẫn tập được!',
      tag: 'Phổ biến nhất',
    ),
    _TimeOption(
      id: '20',
      label: '20 phút/ngày',
      desc: 'Cân bằng giữa công việc và tập luyện',
      tag: null,
    ),
    _TimeOption(
      id: '30',
      label: '30+ phút/ngày',
      desc: 'Nghiêm túc, muốn kết quả nhanh',
      tag: null,
    ),
  ];

  void _select(String id) {
    data.timeCommitment = id;
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
            'Bạn có bao nhiêu thời gian?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI sẽ điều chỉnh bài tập phù hợp với lịch trình của bạn',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          ..._options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TimeCard(
                  option: o,
                  selected: data.timeCommitment == o.id,
                  onTap: () => _select(o.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _TimeOption {
  final String id;
  final String label;
  final String desc;
  final String? tag;
  const _TimeOption({
    required this.id,
    required this.label,
    required this.desc,
    this.tag,
  });
}

class _TimeCard extends StatelessWidget {
  final _TimeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _TimeCard({
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (option.tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            option.tag!,
                            style: TextStyle(
                              color: _cyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
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
