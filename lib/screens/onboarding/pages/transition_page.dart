import 'package:flutter/material.dart';
import '../vf_theme.dart';

class TransitionPage extends StatelessWidget {
  final VoidCallback onNext;
  const TransitionPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080C1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Checkmark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: VF.green.withValues(alpha: 0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 12))
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Tuyệt vời!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text('Squat hoàn thành. Giờ thử\n5 chống đẩy tường nhé!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.6)),
              const SizedBox(height: 24),

              // Wall push-up hint
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text('🧱', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                      'Đứng cách tường ~1 bước chân\nTay chống tường ngang vai',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          height: 1.5)),
                ]),
              ),
              const SizedBox(height: 28),

              // Progress chips
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: VF.green.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: VF.green.withValues(alpha: 0.26)),
                    ),
                    child: const Text('✓ Squat',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: VF.green)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: VF.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: VF.accent.withValues(alpha: 0.26)),
                    ),
                    child: const Text('→ Chống đẩy tường',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: VF.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // CTA
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  decoration: BoxDecoration(
                    color: VF.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: VF.accentShadow,
                  ),
                  child: const Text('Bắt đầu',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
