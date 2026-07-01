import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════
// Ivory v9 Chrome Widgets for Active Exercise Screen
//
// No BackdropFilter anywhere in this file — chrome sits on solid
// high-alpha warm-dark fills so mid-range GPUs never pay for live blur.
// ═══════════════════════════════════════════════════════════════════

const String _font = VikaIvory.fontFamily;

/// Solid warm-dark chrome fill that replaces the old frosted glass. On the
/// camera scene the visual difference from blur is minor; the GPU saving on
/// mid-range Android is large.
final Color _chromeFill = VikaIvory.heroBg.withValues(alpha: 0.52);

// ─── Glass Icon Button ───

class IvoryGlassIconButton extends StatelessWidget {
  const IvoryGlassIconButton({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _chromeFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VikaIvory.glass12.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

// ─── Top Chrome Left: Back + HIỆP pill with timer ───

class IvoryTopChromeLeft extends StatelessWidget {
  const IvoryTopChromeLeft({
    super.key,
    required this.currentSet,
    required this.totalSets,
    required this.setSeconds,
    required this.onBack,
  });
  final int currentSet, totalSets, setSeconds;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final m = setSeconds ~/ 60;
    final s = setSeconds % 60;
    final timer = '$m:${s.toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IvoryGlassIconButton(
          onTap: onBack,
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: VikaIvory.invInk),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _chromeFill,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: VikaIvory.glass12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Hiệp ',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: VikaIvory.invInkFaint,
                    letterSpacing: 1.2,
                  )),
              Text('$currentSet',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.invInk,
                    letterSpacing: -0.2,
                  )),
              Text(' / $totalSets',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.invInkFaint,
                  )),
              Text(' · ',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VikaIvory.invInkDim,
                  )),
              Text(timer,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: VikaIvory.invInkSoft,
                    letterSpacing: -0.1,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── AI Live Pulse Pill (minimal richness only) ───

class IvoryAILivePulsePill extends StatelessWidget {
  const IvoryAILivePulsePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: _chromeFill,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: VikaIvory.glass12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: VikaIvory.live,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: VikaIvory.live.withValues(alpha: 0.7), blurRadius: 6)
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('AI THEO DÕI',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: VikaIvory.invInk,
                letterSpacing: 1.0,
              )),
        ],
      ),
    );
  }
}

// ─── Top Chrome Right: FormArc + flip + pause ───

class IvoryTopChromeRight extends StatelessWidget {
  const IvoryTopChromeRight({
    super.key,
    required this.onPause,
    required this.onFlipCamera,
    this.debugBadge,
  });
  final VoidCallback onPause;
  final VoidCallback onFlipCamera;
  final Widget? debugBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The live form arc has been removed — no real-time verdict lives on
        // the active screen. When staff debug is on, the debug badge takes the
        // leading slot; otherwise the row is simply flip + pause.
        if (debugBadge != null) ...[
          debugBadge!,
          const SizedBox(width: 8),
        ],
        IvoryGlassIconButton(
          onTap: onFlipCamera,
          child: Icon(Icons.cameraswitch_rounded,
              size: 14, color: VikaIvory.invInk),
        ),
        const SizedBox(width: 8),
        IvoryGlassIconButton(
          onTap: onPause,
          child: Icon(Icons.pause_rounded, size: 14, color: VikaIvory.invInk),
        ),
      ],
    );
  }
}

// ─── Coach Caption (upper third, timed) ───

/// The coach caption assumes the reader is 2.5 m away: upper-third placement,
/// large type, strong shadow — and short-lived. Each new message fades in,
/// stays ~2 s, then fades out; the voice channel carries the full sentence,
/// the caption is its visual echo. Message *selection* is untouched upstream.
class IvoryCoachCaption extends StatefulWidget {
  const IvoryCoachCaption({super.key, required this.message});
  // TODO(caption): Wire trigger conditions for mid-rep + post-rep captions.
  // TODO(caption): Keyword-ized copy (Vietnamese content pass) — until then
  // the existing sentences render in the new style, capped at 2 lines.
  final String message;

  @override
  State<IvoryCoachCaption> createState() => _IvoryCoachCaptionState();
}

class _IvoryCoachCaptionState extends State<IvoryCoachCaption>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  Timer? _hide;
  String _displayed = '';

  static const Duration _visibleFor = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 380),
    );
    if (widget.message.isNotEmpty) _show(widget.message);
  }

  @override
  void didUpdateWidget(IvoryCoachCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message && widget.message.isNotEmpty) {
      _show(widget.message);
    }
  }

  void _show(String message) {
    _displayed = message;
    _fade.forward();
    _hide?.cancel();
    _hide = Timer(_visibleFor, () {
      if (mounted) _fade.reverse();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: Text(
          _displayed,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: _font,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: VikaIvory.invInk,
            letterSpacing: -0.5,
            height: 1.22,
            shadows: [
              Shadow(
                  color: const Color(0xFF15110D).withValues(alpha: 0.95),
                  blurRadius: 18),
              Shadow(
                  color: const Color(0xFF15110D).withValues(alpha: 0.8),
                  blurRadius: 5,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pause Overlay ───

class IvoryPauseOverlay extends StatelessWidget {
  const IvoryPauseOverlay({
    super.key,
    required this.onResume,
    required this.onEnd,
    this.isManualPause = true,
  });
  final VoidCallback onResume;
  final VoidCallback onEnd;
  final bool isManualPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Solid warm-dark scrim (no blur) — a deeper alpha than the old
      // frosted 0.66 keeps the pause card readable against the camera.
      color: VikaIvory.heroBg.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: VikaIvory.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF15110D).withValues(alpha: 0.42),
              blurRadius: 60,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pause icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: VikaIvory.attention.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isManualPause ? Icons.pause_rounded : Icons.person_off_rounded,
                size: 22,
                color: VikaIvory.attention,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isManualPause ? 'ĐÃ TẠM NGHỈ' : 'MẤT TÍN HIỆU',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: VikaIvory.attention,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isManualPause ? 'Tạm nghỉ một chút?' : 'Bạn ở đâu rồi?',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: VikaIvory.ink,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isManualPause
                  ? 'Tiến độ set này được giữ nguyên.\nẤn nút bên dưới để tiếp tục tập.'
                  : 'Quay lại khung hình để AI tiếp tục theo dõi, hoặc ấn nút bên dưới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: VikaIvory.inkSoft,
                letterSpacing: -0.1,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // Resume button
            GestureDetector(
              onTap: onResume,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: VikaIvory.ink,
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
                child: Row(
                  children: [
                    Text('Tiếp tục tập',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: VikaIvory.invInk,
                          letterSpacing: -0.2,
                        )),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VikaIvory.yellow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.play_arrow_rounded,
                          size: 20, color: VikaIvory.yellowInk),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // End button
            GestureDetector(
              onTap: onEnd,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Text('Kết thúc buổi tập',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: VikaIvory.inkFaint,
                      letterSpacing: -0.1,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
