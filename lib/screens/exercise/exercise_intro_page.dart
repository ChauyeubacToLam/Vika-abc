import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding/vf_theme.dart';
import 'widgets/skeleton_annotation.dart';

class ExerciseIntroBadge {
  const ExerciseIntroBadge({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;
}

class ExerciseIntroPage extends StatelessWidget {
  const ExerciseIntroPage({
    super.key,
    required this.title,
    required this.difficulty,
    required this.totalSets,
    required this.repsPerSet,
    required this.videoDuration,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.coachNote,
    required this.onStart,
    required this.onBack,
  });

  final String title;
  final String difficulty;
  final int totalSets;
  final int repsPerSet;
  final String videoDuration;
  final List<String> muscles;
  final List<String> tips;
  final List<ExerciseIntroBadge> badges;
  final List<SkeletonCallout> callouts;
  final String coachNote;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final heroHeight = media.size.height * 0.36;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: VF.bg,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: media.padding.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    media.padding.top + 14,
                    24,
                    24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        VF.surfaceDark,
                        VF.jadeDark,
                        Color(0xFF0A2E22),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: onBack,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              difficulty,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.56),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AspectRatio(
                        aspectRatio: 1.72,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Container(
                                  width: width * 0.13,
                                  height: width * 0.13,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.10),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white70,
                                    size: 26,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                bottom: 10,
                                child: Text(
                                  'Xem hướng dẫn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.30),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.44),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    videoDuration,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '$totalSets sets · $repsPerSet reps',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.34),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: muscles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final muscle = entry.value;
                          final primary = index < 2;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primary
                                  ? VF.jadeGlow.withValues(alpha: 0.10)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: primary
                                    ? VF.jadeGlow.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              muscle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    primary ? FontWeight.w700 : FontWeight.w600,
                                color: primary
                                    ? VF.jadeGlow.withValues(alpha: 0.78)
                                    : Colors.white.withValues(alpha: 0.34),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _SectionLabel(label: 'HƯỚNG DẪN'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    children:
                        tips.take(3).toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final tip = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: VF.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: VF.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: VF.accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: VF.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: VF.textSec,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: _SectionLabel(label: 'AI THEO DÕI FORM'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      color: VF.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: VF.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _IntroBadgeCard(badge: badges.first),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _IntroBadgeCard(badge: badges.last),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SkeletonAnnotation(callouts: callouts),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VF.amber.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: VF.amber.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: VF.amber.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tips_and_updates_outlined,
                            size: 16,
                            color: VF.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HLV AI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: VF.amber,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                coachNote,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: VF.textSec,
                                  height: 1.55,
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: VFButton(
                      label: 'Bắt đầu tập',
                      onTap: onStart,
                    ),
                  ),
                ),
                SizedBox(height: heroHeight * 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: VF.textMuted,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child:
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.78)),
      ),
    );
  }
}

class _IntroBadgeCard extends StatelessWidget {
  const _IntroBadgeCard({required this.badge});

  final ExerciseIntroBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badge.color.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badge.color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: badge.color.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            badge.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: badge.color,
            ),
          ),
        ],
      ),
    );
  }
}
