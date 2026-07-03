import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';
import '../../../widgets/exercise/looping_asset_video.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ExerciseDemoPage — the follow-along page of the active-exercise PageView.
//
// A full-screen looping demo of the exercise (the PT reference), reachable by
// a horizontal swipe from the camera view. Detection, rep counting, timers
// and voice all keep running while this page is showing — the swipe changes
// what is DISPLAYED, never the session state.
//
// This page only owns the stage: video, scrims and the "HLV MẪU" header. The
// live metrics (rep hero, hold/rest rings, hold cue), top chrome and the
// compact guidance banner are lifted layers in ActiveExercisePage that sit
// ABOVE the PageView — one shared instance for both pages, fixed in place
// while the pages slide underneath. That is what makes this page livable for
// a whole set: same numbers, same positions, same pause button as the camera
// view, with the trainer as the hero.
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
    required this.isLandscape,
    required this.videoActive,
  });

  final String? videoAsset;
  final String exerciseName;

  /// True for hold exercises — the page paints a center dark pool so the
  /// lifted HoldHeroRing (whose center is deliberately transparent for the
  /// camera mirror) stays legible over the bright trainer video.
  final bool isTimeBased;

  /// In landscape the demo is letterboxed instead of cropped: a full-body
  /// reference cut to a torso by BoxFit.cover would defeat the page.
  final bool isLandscape;

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
              fit: isLandscape ? BoxFit.contain : BoxFit.cover,
              alignment: Alignment.center,
              fallback: fallback,
            )
          else
            fallback,

          // Top scrim — same 140px seam as the camera page so the chrome
          // band reads continuous mid-swipe; a touch stronger because the
          // trainer video is bright where the camera scene is dim.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
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

          // Bottom scrim — carries the lifted 128pt rep hero. Taller and
          // stronger than the camera page's 200/0.92 for the same
          // bright-video reason.
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromRGBO(15, 11, 9, 0.94),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Center dark pool for the hold rings. HoldHeroRing keeps its
          // center transparent on purpose (the camera mirror shows through);
          // over a bright video that transparency needs a floor. The rest
          // ring and hold cue paint their own pools — the extra underneath
          // is harmless.
          if (isTimeBased)
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          VikaIvory.heroBg.withValues(alpha: 0.45),
                          VikaIvory.heroBg.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.9],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Header — its own centered band BELOW the chrome row (back + set
          // pill left, pause right), so the title never crowds the buttons.
          // The eyebrow keeps the page's identity: this is the trainer, not
          // you.
          Positioned(
            top: media.padding.top + 54,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: VikaIvory.yellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: VikaIvory.yellowGlow, blurRadius: 8)
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HLV MẪU',
                        style: TextStyle(
                          fontFamily: VikaIvory.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: VikaIvory.invInk,
                          letterSpacing: 2.4,
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
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: VikaIvory.invInk,
                      letterSpacing: -0.6,
                      shadows: [
                        Shadow(
                          color: VikaIvory.heroBg.withValues(alpha: 0.85),
                          blurRadius: 8,
                        ),
                      ],
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
