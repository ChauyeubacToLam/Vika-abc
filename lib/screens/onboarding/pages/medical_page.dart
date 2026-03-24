import 'package:flutter/material.dart';

import '../vf_theme.dart';

class MedicalPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const MedicalPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<MedicalPage> createState() => _MedicalPageState();
}

class _MedicalPageState extends State<MedicalPage> {
  bool _ok = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VFProgressBar(current: 2, total: 7, onBack: widget.onBack),
        Expanded(
          child: VFFitViewport(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick check before we coach',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: VF.text,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Onboarding vẫn là light theme. Chỉ camera viewport ở bước tiếp theo giữ nền tối để AI tracking rõ hơn.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: VF.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                VFPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Bài kiểm tra đầu vào',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: VF.text,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Một vòng squat ngắn để đọc baseline về độ sâu, nhịp và kiểm soát chuyển động.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: VF.textMuted,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 18),
                      _AssessmentLine(
                        title: '5 squats',
                        desc: 'Đánh giá hạ thân và khả năng giữ form.',
                      ),
                      SizedBox(height: 12),
                      _AssessmentLine(
                        title: '~45 giây',
                        desc: 'Không cần đổi vị trí hay setup phức tạp.',
                      ),
                      SizedBox(height: 12),
                      _AssessmentLine(
                        title: 'No equipment',
                        desc: 'Chỉ cần điện thoại và đủ sáng để camera nhìn rõ.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: VF.amberSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: VF.amber.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _ok = !_ok;
                        }),
                        child: VFCheckIcon(
                          size: 14,
                          color: _ok ? VF.accent : VF.textMuted,
                          filled: _ok,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tôi không có vấn đề sức khỏe nghiêm trọng về gối, lưng, hoặc tim mạch và có thể thực hiện squat nhẹ an toàn.',
                          style: TextStyle(
                            fontSize: 12.8,
                            color: VF.textSec,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: VFButton(
            label: 'Bắt đầu kiểm tra',
            onTap: _ok
                ? () {
                    widget.onNext();
                  }
                : null,
            enabled: _ok,
          ),
        ),
      ],
    );
  }
}

class _AssessmentLine extends StatelessWidget {
  final String title;
  final String desc;

  const _AssessmentLine({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: VFCheckIcon(size: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: VF.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12.2,
                  color: VF.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
