import 'package:flutter/material.dart';
import '../vf_theme.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onStart;
  const WelcomePage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GradHeader(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Text('V',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Text('VINAFIT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      )),
                ]),
                const SizedBox(height: 24),
                const Text(
                  'HLV cá nhân AI\nngay trên điện thoại',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Phân tích tư thế. Phản hồi tức thì.\nChương trình riêng cho bạn.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              children: [
                _feature(
                    1,
                    'Phân tích AI thời gian thực',
                    'Camera nhận diện và sửa tư thế ngay khi bạn tập',
                    const [Color(0xFF0891B2), Color(0xFF06B6D4)]),
                const SizedBox(height: 18),
                _feature(
                    2,
                    'Không cần thiết bị',
                    'Chỉ cần điện thoại và 2m² không gian',
                    const [Color(0xFF10B981), Color(0xFF34D399)]),
                const SizedBox(height: 18),
                _feature(
                    3,
                    'Thiết kế cho người Việt',
                    'Bài tập phù hợp dân văn phòng, không gian nhỏ',
                    const [Color(0xFFF97316), Color(0xFFFB923C)]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: VFButton(label: 'Bắt đầu miễn phí', onTap: onStart),
        ),
      ],
    );
  }

  Widget _feature(int n, String title, String desc, List<Color> colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text('$n',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: VF.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      color: VF.textMuted, fontSize: 12.5, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
