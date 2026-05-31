import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';
import 'ivory_painters.dart';

// ═══════════════════════════════════════════════════════════════════
// Ivory v8 Chrome Widgets for Active Exercise Screen
// ═══════════════════════════════════════════════════════════════════

const String _font = VikaIvory.fontFamily;

// ─── Glass Icon Button ───

class IvoryGlassIconButton extends StatelessWidget {
  const IvoryGlassIconButton({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: VikaIvory.glass08,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: VikaIvory.glass12.withValues(alpha: 0.10)),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: VikaIvory.glass06,
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
          ),
        ),
      ],
    );
  }
}

// ─── Live Form Score Arc (44px) ───

class IvoryLiveFormScoreArc extends StatelessWidget {
  const IvoryLiveFormScoreArc({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    // NOTE(form-score): Replace hardcoded color with conditional:
    // score >= 75 → yellow, 60-74 → #E89A4B, <60 → attention
    final arcColor = VikaIvory.yellow;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(44, 44),
            painter: FormScoreArcPainter(score: score, arcColor: arcColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.invInk,
                    letterSpacing: -0.6,
                    height: 1,
                  )),
              Text('FORM',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    color: VikaIvory.invInkFaint,
                    letterSpacing: 0.6,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── AI Live Pulse Pill (minimal richness only) ───

class IvoryAILivePulsePill extends StatelessWidget {
  const IvoryAILivePulsePill({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: VikaIvory.glass06,
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
                        color: VikaIvory.live.withValues(alpha: 0.7),
                        blurRadius: 6)
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
        ),
      ),
    );
  }
}

// ─── Top Chrome Right: FormArc + flip + pause ───

class IvoryTopChromeRight extends StatelessWidget {
  const IvoryTopChromeRight({
    super.key,
    required this.formScore,
    required this.onPause,
    required this.onFlipCamera,
    this.debugBadge,
  });
  final int formScore;
  final VoidCallback onPause;
  final VoidCallback onFlipCamera;
  final Widget? debugBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // NOTE(form-score): Wire real form score here
        debugBadge ?? IvoryLiveFormScoreArc(score: formScore),
        const SizedBox(width: 8),
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

// ─── Form Score Sparkline ───

class IvoryFormScoreSparkline extends StatelessWidget {
  const IvoryFormScoreSparkline({super.key, required this.data});
  final List<int> data;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(60, 18),
          painter: SparklinePainter(data: data),
        ),
        const SizedBox(height: 2),
        Text('10s qua',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: VikaIvory.invInkFaint,
              letterSpacing: 0.8,
            )),
      ],
    );
  }
}

// ─── PT Reference Loop (80×108 placeholder) ───

class IvoryPTReferenceLoop extends StatelessWidget {
  const IvoryPTReferenceLoop({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 108,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A1F18), Color(0xFF15110D)],
            ),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF15110D).withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: Icon(Icons.play_circle_outline_rounded,
                color: VikaIvory.invInkDim, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: VikaIvory.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: VikaIvory.yellowGlow, blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text('HLV MẪU',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: VikaIvory.invInk,
                    letterSpacing: 1.6,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Coach Caption (center lower-third) ───

class IvoryCoachCaption extends StatelessWidget {
  const IvoryCoachCaption({super.key, required this.message});
  // NOTE(caption): Wire trigger conditions for mid-rep + post-rep captions
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow as a tight pill so the label always reads as a label,
        // never as noise on a busy camera scene.
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          decoration: BoxDecoration(
            color: const Color(0xFF15110D).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: VikaIvory.yellow.withValues(alpha: 0.32),
              width: 0.8,
            ),
          ),
          child: Row(
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
              const SizedBox(width: 6),
              Text('HLV AI',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.yellow,
                    letterSpacing: 1.6,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _font,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: VikaIvory.invInk,
            letterSpacing: -0.2,
            height: 1.35,
            shadows: [
              Shadow(
                  color: const Color(0xFF15110D).withValues(alpha: 0.95),
                  blurRadius: 16),
              Shadow(
                  color: const Color(0xFF15110D).withValues(alpha: 0.7),
                  blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Rep Tally Dots ───

class IvoryRepTallyDots extends StatelessWidget {
  const IvoryRepTallyDots({
    super.key,
    required this.count,
    required this.total,
    this.faultIndices = const [],
  });
  final int count, total;
  // NOTE(integration): Wire RepLog.faults into faultIndices
  final List<int> faultIndices;

  @override
  Widget build(BuildContext context) {
    final displayed = total.clamp(0, 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(displayed, (i) {
        final filled = i < count;
        final isCurrent = i == count - 1;
        final hasFault = faultIndices.contains(i);
        final dotSize = hasFault ? 8.0 : 6.0;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: filled ? VikaIvory.yellow : VikaIvory.invInkDim,
              shape: BoxShape.circle,
              border: hasFault && filled
                  ? Border.all(color: VikaIvory.attention, width: 1.5)
                  : null,
              boxShadow: isCurrent
                  ? [BoxShadow(color: VikaIvory.yellowGlow, blurRadius: 8)]
                  : (hasFault && filled
                      ? [
                          BoxShadow(
                              color: VikaIvory.attention.withValues(alpha: 0.5),
                              blurRadius: 4)
                        ]
                      : null),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Bottom Chrome: Phase verb + Rep counter ───

class IvoryBottomChrome extends StatelessWidget {
  const IvoryBottomChrome({
    super.key,
    required this.phaseVerb,
    required this.phaseHint,
    required this.repCount,
    required this.totalReps,
    this.holdProgress,
    this.holdRemaining,
    this.isHoldPhase = false,
    this.faultIndices = const [],
  });
  final String phaseVerb, phaseHint;
  final int repCount, totalReps;
  final double? holdProgress, holdRemaining;
  final bool isHoldPhase;
  final List<int> faultIndices;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Phase area (left)
        Expanded(child: isHoldPhase ? _buildHoldPhase() : _buildSimplePhase()),
        const SizedBox(width: 16),
        // Rep counter (right)
        _buildRepCounter(),
      ],
    );
  }

  Widget _buildSimplePhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Giai đoạn',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: VikaIvory.invInkFaint,
              letterSpacing: 1.6,
              shadows: [
                Shadow(
                    color: const Color(0xFF15110D).withValues(alpha: 0.6),
                    blurRadius: 6)
              ],
            )),
        const SizedBox(height: 3),
        Text(phaseVerb,
            style: TextStyle(
              fontFamily: _font,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: VikaIvory.yellow,
              letterSpacing: -1.6,
              height: 0.9,
              shadows: [
                Shadow(color: VikaIvory.yellowGlowWeak, blurRadius: 14),
                Shadow(
                    color: const Color(0xFF15110D).withValues(alpha: 0.6),
                    blurRadius: 4),
              ],
            )),
        const SizedBox(height: 4),
        Text(phaseHint,
            style: TextStyle(
              fontFamily: _font,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VikaIvory.invInkSoft,
              letterSpacing: -0.1,
              height: 1.3,
              shadows: [
                Shadow(
                    color: const Color(0xFF15110D).withValues(alpha: 0.6),
                    blurRadius: 6)
              ],
            )),
      ],
    );
  }

  Widget _buildHoldPhase() {
    final progress = (holdProgress ?? 0.0).clamp(0.0, 1.0);
    final remaining = holdRemaining ?? 2.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Giữ đáy',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: VikaIvory.yellow,
              letterSpacing: 1.8,
              shadows: [
                Shadow(
                    color: const Color(0xFF15110D).withValues(alpha: 0.6),
                    blurRadius: 6)
              ],
            )),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Smoothly interpolate between metric ticks. The squat
                  // bottom-hold timer fires in coarse increments; without
                  // this tween the ring stutters from value to value.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: progress, end: progress),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.linear,
                    builder: (context, animatedProgress, _) {
                      return CustomPaint(
                        size: const Size(68, 68),
                        painter:
                            HoldTimerRingPainter(progress: animatedProgress),
                      );
                    },
                  ),
                  // Remaining seconds text — same tween treatment so it
                  // counts down smoothly instead of jumping.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: remaining, end: remaining),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.linear,
                    builder: (context, value, _) {
                      return Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: VikaIvory.yellow,
                          letterSpacing: -1.0,
                          height: 1,
                          shadows: [
                            Shadow(color: VikaIvory.yellowGlow, blurRadius: 10)
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GIỮ',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: VikaIvory.yellow,
                      letterSpacing: -1.4,
                      height: 0.9,
                      shadows: [
                        Shadow(color: VikaIvory.yellowGlowWeak, blurRadius: 14),
                        Shadow(
                            color:
                                const Color(0xFF15110D).withValues(alpha: 0.6),
                            blurRadius: 4),
                      ],
                    )),
                const SizedBox(height: 3),
                Text('Cố thêm 1 nhịp nữa',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: VikaIvory.invInkSoft,
                      letterSpacing: -0.1,
                      shadows: [
                        Shadow(
                            color:
                                const Color(0xFF15110D).withValues(alpha: 0.6),
                            blurRadius: 6)
                      ],
                    )),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRepCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('LẦN',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: VikaIvory.invInkSoft,
              letterSpacing: 1.8,
              shadows: [
                Shadow(
                    color: const Color(0xFF15110D).withValues(alpha: 0.6),
                    blurRadius: 6)
              ],
            )),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(repCount.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: VikaIvory.yellow,
                  letterSpacing: -1.8,
                  height: 0.9,
                  shadows: [
                    Shadow(color: VikaIvory.yellowGlow, blurRadius: 16),
                    Shadow(
                        color: const Color(0xFF15110D).withValues(alpha: 0.6),
                        blurRadius: 4),
                  ],
                )),
            const SizedBox(width: 4),
            Text('/$totalReps',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: VikaIvory.invInkSoft,
                  letterSpacing: -0.4,
                  shadows: [
                    Shadow(
                        color: const Color(0xFF15110D).withValues(alpha: 0.6),
                        blurRadius: 4)
                  ],
                )),
          ],
        ),
        const SizedBox(height: 8),
        IvoryRepTallyDots(
            count: repCount, total: totalReps, faultIndices: faultIndices),
      ],
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: VikaIvory.heroBg.withValues(alpha: 0.66),
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
                    isManualPause
                        ? Icons.pause_rounded
                        : Icons.person_off_rounded,
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
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
        ),
      ),
    );
  }
}
