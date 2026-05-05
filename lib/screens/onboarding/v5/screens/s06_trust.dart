import 'package:flutter/material.dart';

import '../v5_primitives.dart';
import '../v5_theme.dart';

class S06Trust extends StatelessWidget {
  const S06Trust({super.key, required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.medical_services_outlined, 'Bác sĩ & PT kiểm chứng', 'Mỗi bài tập được duyệt bởi chuyên gia y tế'),
      (Icons.lock_outline_rounded, 'Dữ liệu là của bạn', 'Xoá toàn bộ bất cứ lúc nào'),
      (Icons.shield_outlined, 'Không chia sẻ', 'Vika không bán dữ liệu cho bên thứ ba'),
    ];
    return V5Screen(
      index: 6,
      onBack: onBack,
      children: [
        Positioned(
          top: 144,
          left: 16,
          right: 16,
          height: 200,
          child: V5FadeIn(
            child: V5HeroCard(
              child: Stack(
                children: [
                  const Positioned(
                    top: 18,
                    left: 18,
                    child: V5Eyebrow(label: 'An toàn & đáng tin', dark: true),
                  ),
                  Positioned(
                    top: 0,
                    right: -10,
                    bottom: 0,
                    width: 230,
                    child: CustomPaint(painter: _TrustShieldPainter()),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 22,
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIKA',
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w600,
                            color: V5.invInkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Đã được\nkiểm chứng',
                          style: V5.text(
                            context,
                            size: 24,
                            weight: FontWeight.w800,
                            color: V5.invInk,
                            letterSpacing: -0.8,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          'Bác sĩ & PT đồng hành',
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w500,
                            color: V5.invInkSoft,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 360,
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    children: items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: V5FadeIn(
                          delay: Duration(milliseconds: i * 60),
                          slideY: 8,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: V5.surface,
                              border: Border.all(color: V5.border),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [V5.cardShadow(0.08)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: V5.yellowSoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(item.$1, color: V5.yellowDeep, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.$2,
                                        style: V5.text(
                                          context,
                                          size: 14,
                                          weight: FontWeight.w800,
                                          color: V5.ink,
                                          letterSpacing: -0.2,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.$3,
                                        style: V5.text(
                                          context,
                                          size: 11,
                                          weight: FontWeight.w500,
                                          color: V5.inkSoft,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 108),
                child: Text.rich(
                  TextSpan(
                    children: const [
                      TextSpan(text: 'Bằng việc tiếp tục, bạn đồng ý với '),
                      TextSpan(text: 'Điều khoản', style: TextStyle(color: V5.yellowDeep, fontWeight: FontWeight.w700)),
                      TextSpan(text: ' và '),
                      TextSpan(text: 'Chính sách bảo mật', style: TextStyle(color: V5.yellowDeep, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: V5.text(
                    context,
                    size: 11,
                    weight: FontWeight.w500,
                    color: V5.inkFaint,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        V5PillCTA(label: 'Đồng ý & tiếp tục', onTap: onNext),
      ],
    );
  }
}

class _TrustShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final sx = size.width / 240;
    final sy = size.height / 240;
    canvas.scale(sx, sy);
    // Radial gradient glow — no MaskFilter pass to avoid first-frame
    // unblurred-disk flash on emulators.
    const glowRect = Rect.fromLTWH(20, 5, 200, 200);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            V5.yellow.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
    final shield = Path()
      ..moveTo(120, 38)
      ..lineTo(52, 68)
      ..lineTo(52, 132)
      ..quadraticBezierTo(52, 198, 120, 226)
      ..quadraticBezierTo(188, 198, 188, 132)
      ..lineTo(188, 68)
      ..close();
    canvas.drawPath(
      shield,
      Paint()..color = V5.yellow.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = V5.yellow.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final check = Path()
      ..moveTo(90, 130)
      ..lineTo(112, 152)
      ..lineTo(152, 102);
    canvas.drawPath(
      check,
      Paint()
        ..color = V5.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
