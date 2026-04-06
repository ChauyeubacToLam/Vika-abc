import 'package:flutter/material.dart';

import '../../onboarding/vf_theme.dart';
import 'form_score_arc.dart';

class ShareableCard extends StatelessWidget {
  const ShareableCard({
    super.key,
    required this.boundaryKey,
    required this.formScore,
    required this.exerciseName,
    required this.dateText,
    required this.metaLine,
    required this.winMessage,
    required this.setScores,
    this.onShare,
  });

  final GlobalKey boundaryKey;
  final int formScore;
  final String exerciseName;
  final String dateText;
  final String metaLine;
  final String winMessage;
  final List<int> setScores;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final scoreColor = formScore >= 80
        ? VF.jadeGlow
        : formScore >= 60
            ? VF.amber
            : VF.coral;
    final bestIndex = setScores.isEmpty
        ? -1
        : setScores.indexOf(setScores.reduce((a, b) => a > b ? a : b));

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1D1C),
              Color(0xFF101312),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'VINAFIT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: VF.jadeGlow.withValues(alpha: 0.28),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onShare,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chia sẻ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FormScoreArc(
              progress: formScore / 100,
              size: 150,
              color: scoreColor,
              trackColor: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 7,
              glow: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$formScore',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    'Điểm form',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              exerciseName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$dateText · $metaLine',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scoreColor.withValues(alpha: 0.08)),
              ),
              child: Text(
                winMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scoreColor.withValues(alpha: 0.78),
                ),
              ),
            ),
            if (setScores.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: setScores.asMap().entries.map((entry) {
                  final index = entry.key;
                  final score = entry.value;
                  final isBest = index == bestIndex;
                  return Padding(
                    padding: EdgeInsets.only(
                        right: index == setScores.length - 1 ? 0 : 18),
                    child: Column(
                      children: [
                        FormScoreArc(
                          progress: score / 100,
                          size: 48,
                          color: isBest
                              ? VF.jadeGlow
                              : Colors.white.withValues(alpha: 0.38),
                          trackColor: Colors.white.withValues(alpha: 0.06),
                          strokeWidth: 3.5,
                          child: Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isBest
                                  ? VF.jadeGlow.withValues(alpha: 0.86)
                                  : Colors.white.withValues(alpha: 0.64),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set ${index + 1}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isBest
                                ? VF.jadeGlow.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
