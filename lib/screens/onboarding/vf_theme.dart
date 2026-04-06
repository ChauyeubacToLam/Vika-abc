import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium light theme for onboarding and future light UI work.
/// Camera/exercise flows remain dark and are themed separately.
class VF {
  VF._();

  // ─── Scaling ───
  static double scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 393).clamp(0.85, 1.15).toDouble();
  }

  static double sp(BuildContext context, double size) => size * scale(context);

  static TextStyle textStyle(
    BuildContext context, {
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = text,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.dmSans(
      fontSize: sp(context, size),
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ─── Colors ───
  static const Color bg = Color(0xFFF0EDE6);
  static const Color bgDeep = Color(0xFFE4DFD5);
  static const Color surface = Color(0xFFFEFCF7);
  static const Color surfaceDark = Color(0xFF18594A);

  static const Color accent = Color(0xFF1B6B52);
  static const Color accentSoft = Color(0xFFD4E8DF);
  static const Color accentSoftStrong = accentSoft;
  static const Color jadeDark = Color(0xFF0F4435);
  static const Color jadeGlow = Color(0xFF5CEAA8);

  static const Color green = accent;
  static const Color greenSoft = accentSoft;
  static const Color amber = Color(0xFFB87320);
  static const Color amberSoft = Color(0xFFF6EFE6);
  static const Color coral = Color(0xFFB84435);
  static const Color blue = Color(0xFF2B5EA6);
  static const Color red = coral;

  static const Color text = Color(0xFF181B19);
  static const Color textSec = Color(0xFF4A4D47);
  static const Color textMuted = Color(0xFF97958D);
  static const Color textDim = Color(0xFFBBB7AE);
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

  static ThemeData get lightTheme {
    final base = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: surface,
      ),
      useMaterial3: true,
      fontFamily: 'DM Sans',
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.dmSansTextTheme(base.primaryTextTheme),
    );
  }
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
    final s = VF.scale(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 54 * s,
        decoration: BoxDecoration(
          color: enabled ? VF.accent : VF.bgDeep,
          borderRadius: BorderRadius.circular(16 * s),
          boxShadow: enabled ? VF.accentShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: VF.textStyle(
            context,
            size: 15,
            weight: FontWeight.w800,
            color: enabled ? Colors.white : VF.textDim,
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
    final s = VF.scale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24 * s, 12 * s, 24 * s, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36 * s,
                  height: 36 * s,
                  decoration: BoxDecoration(
                    color: VF.surface,
                    borderRadius: BorderRadius.circular(12 * s),
                    border: Border.all(color: VF.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14 * s,
                    color: VF.textSec,
                  ),
                ),
              ),
              SizedBox(width: 12 * s),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: VF.sp(context, 16),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  children: const [
                    TextSpan(text: 'Vina', style: TextStyle(color: VF.accent)),
                    TextSpan(text: 'Fit', style: TextStyle(color: VF.text)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * s,
                  vertical: 6 * s,
                ),
                decoration: BoxDecoration(
                  color: VF.accentSoft,
                  borderRadius: BorderRadius.circular(10 * s),
                ),
                child: Text(
                  '$current/$total',
                  style: VF.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: VF.accent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4 * s,
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
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Border? border;

  const VFPanel({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: padding ?? EdgeInsets.all(18 * s),
      decoration: BoxDecoration(
        color: color ?? VF.surface,
        borderRadius: BorderRadius.circular(20 * s),
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
    final s = VF.scale(context);
    final scaledSize = size * s;
    final stroke = filled ? Colors.white : color;
    return Container(
      width: scaledSize + 10 * s,
      height: scaledSize + 10 * s,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular((scaledSize + 10 * s) / 2),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: EdgeInsets.all(4 * s),
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
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10 * s),
      ),
      child: Text(
        label,
        style: VF.textStyle(
          context,
          size: 11,
          weight: FontWeight.w700,
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
