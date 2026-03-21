import 'package:flutter/material.dart';
import '../vf_theme.dart';

class MedicalPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const MedicalPage({super.key, required this.onNext, required this.onBack});

  @override
  State<MedicalPage> createState() => _MedicalPageState();
}

class _MedicalPageState extends State<MedicalPage> {
  bool _ok = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GradHeader(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Kiểm tra nhanh',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text('5 squats + 5 chống đẩy tường để AI hiểu cơ thể bạn',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                // Assessment card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: VF.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: VF.border),
                    boxShadow: VF.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: VF.brandGrad,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text('10',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bài kiểm tra',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: VF.text)),
                            SizedBox(height: 1),
                            Text('~ 45 giây, cùng vị trí đứng',
                                style: TextStyle(
                                    fontSize: 12, color: VF.textMuted)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 18),
                      ...[
                        ('5 Squats', 'Đánh giá hạ thân', VF.brand),
                        ('5 Chống đẩy tường', 'Đánh giá thân trên', VF.green),
                        ('AI phân tích', 'Tư thế & kiểm soát', VF.orange),
                      ].map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: VF.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: item.$3, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Text(item.$1,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: VF.text)),
                              const SizedBox(width: 6),
                              Text(item.$2,
                                  style: const TextStyle(
                                      fontSize: 12, color: VF.textMuted)),
                            ]),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // No equipment note
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: VF.green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VF.green.withValues(alpha: 0.12)),
                  ),
                  child: const Row(children: [
                    Text('✅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 10),
                    Text('Không cần thảm, không cần nằm xuống sàn',
                        style: TextStyle(
                            fontSize: 12,
                            color: VF.green,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Medical checkbox
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: VF.amberBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: VF.amber.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _ok = !_ok),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: _ok ? VF.brand : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: _ok ? VF.brand : const Color(0xFFD1D5DB),
                                width: 2),
                          ),
                          child: _ok
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tôi không có vấn đề sức khỏe nghiêm trọng về gối, lưng, hoặc tim mạch.',
                          style: TextStyle(
                              fontSize: 12.5, color: VF.textSec, height: 1.5),
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: VFButton(
              label: 'Bắt đầu kiểm tra', onTap: widget.onNext, enabled: _ok),
        ),
      ],
    );
  }
}
