import 'package:flutter/material.dart';

/// VinaFit Light Theme Design System (onboarding + future light screens).
/// Camera/exercise screens keep the existing dark theme.
class VF {
  VF._();

  // ── Brand ──
  static const Color brand = Color(0xFF0891B2);
  static const Color brandDark = Color(0xFF0369A1);
  static const Color brandLight = Color(0xFFE0F7FA);
  static const LinearGradient brandGrad = LinearGradient(
    colors: [brand, brandDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Surfaces ──
  static const Color bg = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);

  // ── Text ──
  static const Color text = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ── Semantic ──
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberBg = Color(0xFFFEF3C7);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFEF4444);

  // ── Border ──
  static const Color border = Color(0xFFE2E8F0);

  // ── Shadows ──
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> heroShadow = [
    BoxShadow(
      color: brand.withValues(alpha: 0.15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Light theme data (wrap onboarding screens with this) ──
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: bg,
        colorSchemeSeed: brand,
        useMaterial3: true,
        fontFamily: 'Roboto',
      );
}

/// Gradient hero header with decorative circles.
class GradHeader extends StatelessWidget {
  final Widget child;
  final double radius;
  const GradHeader({super.key, required this.child, this.radius = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: VF.brandGrad,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Primary CTA button with brand gradient.
class VFButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  const VFButton(
      {super.key, required this.label, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: enabled ? VF.brandGrad : null,
          color: enabled ? null : VF.border,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled ? VF.heroShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : VF.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Progress bar with back button.
class VFProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onBack;
  const VFProgressBar(
      {super.key,
      required this.current,
      required this.total,
      required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: VF.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VF.border),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: VF.textSec),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                  color: VF.border, borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (current / total).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: VF.brandGrad,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$current/$total',
              style: const TextStyle(
                  fontSize: 11,
                  color: VF.textMuted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
