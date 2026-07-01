import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';
import '../../../widgets/exercise/looping_asset_video.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ExerciseDemoPage — the second page of the active-exercise PageView.
//
// A full-screen looping demo of the exercise (the PT reference), reachable by
// a horizontal swipe from the camera view. Detection, rep counting, timers
// and voice all keep running while this page is showing — the swipe changes
// what is DISPLAYED, never the session state. A small live indicator makes
// that visible so the user never wonders whether the set is still going.
//
// The video controller only exists while [videoActive] is true (the page is
// actually visible); the decoder never runs behind the camera view.
// ═══════════════════════════════════════════════════════════════════════════

class ExerciseDemoPage extends StatelessWidget {
  const ExerciseDemoPage({
    super.key,
    required this.videoAsset,
    required this.exerciseName,
    required this.isTimeBased,
    required this.liveValue,
    required this.totalValue,
    required this.videoActive,
  });

  final String? videoAsset;
  final String exerciseName;

  /// True for hold exercises — the live chip shows seconds instead of reps.
  final bool isTimeBased;

  /// Live rep count (or accrued correct seconds for holds).
  final int liveValue;

  /// Set target (reps or seconds).
  final int totalValue;

  /// Gate for the video decoder — only true while this page is on screen.
  final bool videoActive;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fallback = Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        size: 72,
        color: VikaIvory.invInkDim,
      ),
    );

    return ColoredBox(
      color: VikaIvory.heroBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoActive && videoAsset != null)
            LoopingAssetVideo(
              asset: videoAsset!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              fallback: fallback,
            )
          else
            fallback,

          // Top scrim anchoring the labels against the video.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 170,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(15, 11, 9, 0.82),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: media.padding.top + 16,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: VikaIvory.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: VikaIvory.yellowGlow, blurRadius: 8)
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'HLV MẪU',
                      style: TextStyle(
                        fontFamily: VikaIvory.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: VikaIvory.invInk,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  exerciseName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VikaIvory.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: VikaIvory.invInk,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Live session chip — proof the set is still running.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: VikaIvory.heroBg.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: VikaIvory.glass12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: VikaIvory.live,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: VikaIvory.live.withValues(alpha: 0.7),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$liveValue',
                        style: TextStyle(
                          fontFamily: VikaIvory.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: VikaIvory.invInk,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        '/$totalValue ${isTimeBased ? 'giây' : 'lần'}',
                        style: TextStyle(
                          fontFamily: VikaIvory.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: VikaIvory.invInkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quiet swipe-back hint at the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 18,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chevron_left_rounded,
                      size: 16, color: VikaIvory.invInkDim),
                  const SizedBox(width: 2),
                  Text(
                    'Vuốt để về camera',
                    style: TextStyle(
                      fontFamily: VikaIvory.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: VikaIvory.invInkDim,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
