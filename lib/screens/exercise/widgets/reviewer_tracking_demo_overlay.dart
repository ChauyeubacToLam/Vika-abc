import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/vf_theme.dart';
import '../../../widgets/exercise/looping_asset_video.dart';

/// Full-screen playback of a bundled exercise demo clip.
///
/// Surfaced by a deliberate 5-second press-and-hold on the intro CTA.
/// A quick tap still starts the normal exercise flow.
class ReviewerTrackingDemoOverlay extends StatelessWidget {
  const ReviewerTrackingDemoOverlay({
    super.key,
    required this.asset,
  });

  final String asset;

  static const Color _warmDark = Color(0xFF1F1812);

  static Future<void> show(
    BuildContext context, {
    required String asset,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: _warmDark,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => ReviewerTrackingDemoOverlay(asset: asset),
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
            Positioned.fill(
              child: LoopingAssetVideo(
                asset: asset,
                fit: BoxFit.contain,
                loop: false,
                fallback: const _DemoPlaceholder(),
              ),
            ),
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

class _DemoPlaceholder extends StatelessWidget {
  const _DemoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Đang tải video mẫu...',
        style: TextStyle(
          fontFamily: VikaIvory.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: VikaIvory.invInkSoft,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Đóng',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color:
                ReviewerTrackingDemoOverlay._warmDark.withValues(alpha: 0.88),
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
      ),
    );
  }
}
