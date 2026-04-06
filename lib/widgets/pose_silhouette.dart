import 'package:flutter/material.dart';

class PoseSilhouette extends StatelessWidget {
  const PoseSilhouette({
    super.key,
    required this.type,
    this.size = 44,
    this.color = const Color(0xB3FFFFFF),
  });

  final String type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PoseSilhouettePainter(
          type: type.toLowerCase(),
          color: color,
        ),
      ),
    );
  }
}

class _PoseSilhouettePainter extends CustomPainter {
  const _PoseSilhouettePainter({
    required this.type,
    required this.color,
  });

  final String type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 44;
    final scaleY = size.height / 44;
    canvas.scale(scaleX, scaleY);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case 'pushup':
        _drawPushUp(canvas, stroke, fill);
        break;
      case 'plank':
        _drawPlank(canvas, stroke, fill);
        break;
      case 'lunge':
        _drawLunge(canvas, stroke, fill);
        break;
      case 'bridge':
        _drawBridge(canvas, stroke, fill);
        break;
      case 'curlup':
        _drawCurlUp(canvas, stroke, fill);
        break;
      case 'jump':
        _drawJump(canvas, stroke, fill);
        break;
      case 'squat':
      default:
        _drawSquat(canvas, stroke, fill);
        break;
    }
  }

  void _drawSquat(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(22, 7), 3.5, fill);

    final leftBody = Path()
      ..moveTo(22, 10.5)
      ..lineTo(22, 15)
      ..lineTo(16.5, 22)
      ..lineTo(16.5, 29.5);
    canvas.drawPath(leftBody, stroke);

    final rightBody = Path()
      ..moveTo(22, 15)
      ..lineTo(27.5, 22)
      ..lineTo(27.5, 29.5);
    canvas.drawPath(rightBody, stroke);

    final arms = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(16.5, 17), const Offset(11.5, 18.5), arms);
    canvas.drawLine(const Offset(27.5, 17), const Offset(32.5, 18.5), arms);
  }

  void _drawPushUp(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(8, 19), 3.2, fill);

    final line = Path()
      ..moveTo(11, 19)
      ..lineTo(29.5, 19)
      ..lineTo(35, 28);
    canvas.drawPath(line, stroke);
    canvas.drawLine(const Offset(11, 19), const Offset(7.5, 28), stroke);

    final detail = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(29.5, 19), const Offset(32, 14), detail);
  }

  void _drawPlank(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2.2;
    canvas.drawCircle(const Offset(8, 18), 3.2, fill);
    canvas.drawLine(const Offset(11, 18), const Offset(33.5, 18), stroke);

    final limbs = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(33.5, 18), const Offset(35.5, 28), limbs);
    canvas.drawLine(const Offset(11, 18), const Offset(8, 28), limbs);
  }

  void _drawLunge(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(20, 5.5), 3.2, fill);

    final body = Path()
      ..moveTo(20, 9)
      ..lineTo(20, 16)
      ..lineTo(13, 25)
      ..lineTo(13, 31);
    canvas.drawPath(body, stroke);

    final leg = Path()
      ..moveTo(20, 16)
      ..lineTo(25, 21)
      ..lineTo(28.5, 30);
    canvas.drawPath(leg, stroke);

    final arms = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(15, 12), const Offset(11.5, 12), arms);
    canvas.drawLine(const Offset(25, 12), const Offset(28.5, 12), arms);
  }

  void _drawBridge(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(35, 18), 3, fill);

    final body = Path()
      ..moveTo(9, 28)
      ..lineTo(19, 28)
      ..lineTo(27, 18)
      ..lineTo(35, 18);
    canvas.drawPath(body, stroke);
    canvas.drawLine(const Offset(9, 28), const Offset(9, 24), stroke);
    canvas.drawLine(const Offset(26, 18), const Offset(23.5, 22), stroke);
  }

  void _drawCurlUp(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(13, 16), 3, fill);

    final body = Path()
      ..moveTo(16, 18)
      ..lineTo(26, 20.5)
      ..lineTo(26, 28);
    canvas.drawPath(body, stroke);
    canvas.drawLine(const Offset(16, 18), const Offset(14.5, 28), stroke);
    canvas.drawLine(const Offset(26, 20.5), const Offset(32, 19), stroke);
  }

  void _drawJump(Canvas canvas, Paint stroke, Paint fill) {
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(22, 6), 3.2, fill);

    final body = Path()
      ..moveTo(22, 9.5)
      ..lineTo(22, 17);
    canvas.drawPath(body, stroke);
    canvas.drawLine(const Offset(17.5, 17), const Offset(12.5, 27), stroke);
    canvas.drawLine(const Offset(26.5, 17), const Offset(31.5, 27), stroke);
    canvas.drawLine(const Offset(17, 12), const Offset(11, 8.5), stroke);
    canvas.drawLine(const Offset(27, 12), const Offset(33, 8.5), stroke);
  }

  @override
  bool shouldRepaint(covariant _PoseSilhouettePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
