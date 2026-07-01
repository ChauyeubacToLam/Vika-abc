import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/vf_theme.dart';
import '../../../widgets/exercise/looping_asset_video.dart';

/// Full-screen playback of the bundled squat tracking demo clip.
///
/// Surfaced by a deliberate 5-second press-and-hold on the squat intro's
/// "Bắt đầu tập" pill so an App Store reviewer can watch how Vika tracks
/// movement, rests, and summarises without performing the exercise. A quick
/// tap of the same pill starts a normal session — the hold is a separate
/// track. This is documented to the reviewer in the App Store submission
/// notes. It is NOT a staff feature: it works for ANY user on a normal release
/// build and is not gated on `is_staff`.
///
/// Playback reuses [LoopingAssetVideo] (unmuted, single-shot) — the same
/// `video_player` controller setup/dispose pattern that [IvoryPTReferenceLoop]
/// uses on the live screen. The overlay is pushed as a full-screen route on top
/// of the intro page; closing it returns straight to the intro.
class ReviewerTrackingDemoOverlay extends StatelessWidget {
  const ReviewerTrackingDemoOverlay({super.key});

  /// Bundled demo clip. Lives in the glob-registered `assets/video/` folder, so
  /// no pubspec change is required to ship it.
  static const String demoAsset = 'assets/video/squat_tracking_demo.mp4';

  static const Color _warmDark = Color(0xFF1F1812); // chrome surface
  static const Color _yellow = Color(0xFFFFB701); // reserved accent

  /// Pushes the demo as an opaque full-screen route. The live page below stays
  /// mounted (and its pose pipeline keeps running); we just stop painting it.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: _warmDark,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => const ReviewerTrackingDemoOverlay(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: _warmDark,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video (letterboxed on warm-dark; audible, plays once and
            //    rests on its final summary frame) ──
            const Positioned.fill(
              child: LoopingAssetVideo(
                asset: demoAsset,
                fit: BoxFit.contain,
                volume: 1.0,
                loop: false,
                fallback: _DemoPlaceholder(),
              ),
            ),

            // ── Reviewer caption (bottom) ──
            Positioned(
              left: 24,
              right: 24,
              bottom: media.padding.bottom + 28,
              child: const IgnorePointer(child: _DemoCaption()),
            ),

            // ── Close button (top-right) ──
            Positioned(
              top: media.padding.top + 12,
              right: 16,
              child: _CloseButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the clip loads, or if the bundled asset is unavailable. Reads as
/// an intentional preview state in either case.
class _DemoPlaceholder extends StatelessWidget {
  const _DemoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 56,
            color: ReviewerTrackingDemoOverlay._yellow.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            'Đang tải video minh hoạ…',
            style: TextStyle(
              fontFamily: VikaIvory.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VikaIvory.invInkSoft,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCaption extends StatelessWidget {
  const _DemoCaption();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Eyebrow pill — yellow dot + label, on a warm-dark glass chip.
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
          decoration: BoxDecoration(
            color:
                ReviewerTrackingDemoOverlay._warmDark.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color:
                  ReviewerTrackingDemoOverlay._yellow.withValues(alpha: 0.32),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: ReviewerTrackingDemoOverlay._yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'BẢN DEMO · THEO DÕI AI',
                style: TextStyle(
                  fontFamily: VikaIvory.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ReviewerTrackingDemoOverlay._yellow,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Video minh hoạ cách Vika theo dõi chuyển động trong bài Squat.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: VikaIvory.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: VikaIvory.invInk,
            height: 1.4,
            letterSpacing: -0.1,
            shadows: const [
              Shadow(color: Color(0xCC15110D), blurRadius: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: ReviewerTrackingDemoOverlay._warmDark.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: VikaIvory.invInk.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF15110D).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.close_rounded,
          size: 22,
          color: VikaIvory.invInk,
        ),
      ),
    );
  }
}
