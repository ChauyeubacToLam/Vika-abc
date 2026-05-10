// AISpotlight — warm-dark hero card on the Library sheet introducing the
// 20 AI-camera exercises as the prestige tier. Has a corner camera-frame
// glyph and an italic display headline + CTA pill.
//
// Mirrors `AICameraSpotlight` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class AISpotlight extends StatelessWidget {
  const AISpotlight({super.key, required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Yellow radial wash, top-right.
          Positioned(
            top: -50,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.18),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          // Corner camera-frame mark.
          Positioned(
            top: 22,
            right: 22,
            child: SizedBox(
              width: 48,
              height: 48,
              child: CustomPaint(
                painter: _CameraFramePainter(
                  yellow: c.yellow,
                  fade: c.invInkFaint,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlanEyebrow(
                    'BỘ SƯU TẬP CHÍNH',
                    size: 10,
                    letterSpacing: 2,
                    color: c.yellow,
                    tabular: true,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '·',
                    style: TextStyle(
                      color: c.yellow.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PlanEyebrow(
                    '20 / 100',
                    size: 10,
                    letterSpacing: 2,
                    color: c.invInkSoft,
                    tabular: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: const PlanH1(
                  'Camera xem bạn tập.',
                  size: 36,
                  dark: true,
                  letterSpacing: -1.6,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: const PlanP(
                  'Hai mươi bài đã được dạy cho camera. Sửa lỗi tức thì khi bạn tập sai.',
                  dark: true,
                  soft: true,
                  size: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: c.borderDark),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SpotlightStat(value: '20', label: 'BÀI'),
                    const SizedBox(width: 22),
                    Container(
                      width: 1,
                      height: 22,
                      margin: const EdgeInsets.only(bottom: 3),
                      color: c.borderDark,
                    ),
                    const SizedBox(width: 22),
                    _SpotlightStat(value: '10', label: 'YOGA'),
                    const SizedBox(width: 22),
                    Container(
                      width: 1,
                      height: 22,
                      margin: const EdgeInsets.only(bottom: 3),
                      color: c.borderDark,
                    ),
                    const SizedBox(width: 22),
                    _SpotlightStat(value: '10', label: 'TẠI NHÀ'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Form chính xác. Không đoán.',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: c.invInkSoft,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEnter,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.yellow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Vào bộ sưu tập',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                                color: c.yellowInk,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: c.ink,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: c.yellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightStat extends StatelessWidget {
  const _SpotlightStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.2,
            height: 0.9,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(height: 4),
        PlanEyebrow(label, size: 9, letterSpacing: 1.4, dark: true),
      ],
    );
  }
}

class _CameraFramePainter extends CustomPainter {
  _CameraFramePainter({required this.yellow, required this.fade});

  final Color yellow;
  final Color fade;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final yellowStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = yellow;

    final fadeStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = fade;

    // Top-left bracket (yellow).
    canvas.drawPath(
      Path()
        ..moveTo(4 * scale, 12 * scale)
        ..lineTo(4 * scale, 6 * scale)
        ..relativeArcToPoint(
          Offset(2 * scale, -2 * scale),
          radius: Radius.circular(2 * scale),
          clockwise: true,
        )
        ..lineTo(12 * scale, 4 * scale),
      yellowStroke,
    );

    // Top-right bracket (faded).
    canvas.drawPath(
      Path()
        ..moveTo(44 * scale, 12 * scale)
        ..lineTo(44 * scale, 6 * scale)
        ..relativeArcToPoint(
          Offset(-2 * scale, -2 * scale),
          radius: Radius.circular(2 * scale),
          clockwise: false,
        )
        ..lineTo(36 * scale, 4 * scale),
      fadeStroke,
    );

    // Bottom-left bracket (faded).
    canvas.drawPath(
      Path()
        ..moveTo(4 * scale, 36 * scale)
        ..lineTo(4 * scale, 42 * scale)
        ..relativeArcToPoint(
          Offset(2 * scale, 2 * scale),
          radius: Radius.circular(2 * scale),
          clockwise: false,
        )
        ..lineTo(12 * scale, 44 * scale),
      fadeStroke,
    );

    // Bottom-right bracket (yellow).
    canvas.drawPath(
      Path()
        ..moveTo(44 * scale, 36 * scale)
        ..lineTo(44 * scale, 42 * scale)
        ..relativeArcToPoint(
          Offset(-2 * scale, 2 * scale),
          radius: Radius.circular(2 * scale),
          clockwise: true,
        )
        ..lineTo(36 * scale, 44 * scale),
      yellowStroke,
    );

    // Center dot + faint outer ring.
    canvas.drawCircle(p(24, 24), 3 * scale, Paint()..color = yellow);
    canvas.drawCircle(
      p(24, 24),
      7 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * scale
        ..color = yellow.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _CameraFramePainter oldDelegate) => false;
}
