import 'package:flutter/material.dart';

/// Premium light theme for onboarding and future light UI work.
/// Camera/exercise flows remain dark and are themed separately.
class VF {
  VF._();

  static const Color bg = Color(0xFFF6F3EE);
  static const Color bgDeep = Color(0xFFEDE9E3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0B1A1A);

  static const Color accent = Color(0xFF0D7367);
  static const Color accentSoft = Color(0xFFE8F5F2);
  static const Color accentSoftStrong = Color(0xFFD9EEE9);

  static const Color green = Color(0xFF2E856E);
  static const Color greenSoft = Color(0xFFEAF5F0);
  static const Color amber = Color(0xFFE5920A);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color red = Color(0xFFDC3545);

  static const Color text = Color(0xFF1A2B2B);
  static const Color textSec = Color(0xFF4A6363);
  static const Color textMuted = Color(0xFF8FA3A3);
  static const Color textDim = Color(0xFFB8CACA);
  static const Color border = bgDeep;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: accent.withValues(alpha: 0.20),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: surface,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      );
}

class VFButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const VFButton({
    super.key,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? VF.accent : VF.bgDeep,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? VF.accentShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : VF.textDim,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class VFProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onBack;

  const VFProgressBar({
    super.key,
    required this.current,
    required this.total,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: VF.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VF.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: VF.textSec,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(text: 'Vina', style: TextStyle(color: VF.accent)),
                    TextSpan(text: 'Fit', style: TextStyle(color: VF.text)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: VF.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$current/$total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: VF.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: total == 0 ? 0 : current / total,
              backgroundColor: VF.bgDeep,
              valueColor: const AlwaysStoppedAnimation<Color>(VF.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class VFPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const VFPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? VF.surface,
        borderRadius: BorderRadius.circular(20),
        border: border ?? Border.all(color: VF.border),
        boxShadow: VF.cardShadow,
      ),
      child: child,
    );
  }
}

class VFCheckIcon extends StatelessWidget {
  final Color color;
  final double size;
  final bool filled;

  const VFCheckIcon({
    super.key,
    this.color = VF.accent,
    this.size = 18,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final stroke = filled ? Colors.white : color;
    return Container(
      width: size + 10,
      height: size + 10,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular((size + 10) / 2),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: _CheckPainter(stroke),
      ),
    );
  }
}

class VFPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const VFPill({
    super.key,
    required this.label,
    this.color = VF.accent,
    this.background = VF.accentSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class VFFitViewport extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const VFFitViewport({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = padding.resolve(Directionality.of(context));
        final width = constraints.maxWidth - resolvedPadding.horizontal;

        return Padding(
          padding: padding,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width > 0 ? width : constraints.maxWidth,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final Color color;

  const _CheckPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.78)
      ..lineTo(size.width * 0.82, size.height * 0.24);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
