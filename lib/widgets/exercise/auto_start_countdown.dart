// Auto-start countdown CTA used at the bottom of intermediate exercise
// intros (Exercise 2 onwards), after the previous-exercise rating popup
// has been dismissed.
//
// Pattern: countdown is the default — hands-free start so the user can
// step away from the phone. Override actions available:
//   • "Bắt đầu ngay" — skip the wait and start immediately
//   • "+30s · Cần thêm thời gian" — extend the timer by 30s
//
// Default duration is 30s (set by caller). When the timer hits zero
// `onStartNow` is fired exactly once.
//
// Surface: warm-dark dock with rounded top corners and a yellow timer
// ring on the left, so it reads as "next action" even at a distance.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class AutoStartCountdown extends StatefulWidget {
  const AutoStartCountdown({
    super.key,
    required this.totalSeconds,
    required this.onStartNow,
    this.extendSeconds = 30,
    this.label = 'Bài tiếp theo bắt đầu trong',
    this.startNowLabel = 'Bắt đầu ngay',
    this.extendLabel = 'Cần thêm thời gian',
  });

  final int totalSeconds;
  final VoidCallback onStartNow;
  final int extendSeconds;
  final String label;
  final String startNowLabel;
  final String extendLabel;

  @override
  State<AutoStartCountdown> createState() => _AutoStartCountdownState();
}

class _AutoStartCountdownState extends State<AutoStartCountdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _ring;
  Timer? _ticker;
  late int _remaining;
  late int _totalForCycle;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _totalForCycle = widget.totalSeconds;
    _remaining = widget.totalSeconds;
    _ring = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (_fired) return;
    _ring.forward(from: 1 - (_remaining / _totalForCycle));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, 999));
      if (_remaining <= 0 && !_fired) {
        _fired = true;
        _ticker?.cancel();
        widget.onStartNow();
      }
    });
  }

  void _extend() {
    if (_fired) return;
    HapticFeedback.lightImpact();
    setState(() {
      _remaining += widget.extendSeconds;
      _totalForCycle = _remaining;
    });
    _ring
      ..stop()
      ..duration = Duration(seconds: _remaining)
      ..forward(from: 0);
  }

  void _startNow() {
    if (_fired) return;
    _fired = true;
    _ticker?.cancel();
    HapticFeedback.mediumImpact();
    widget.onStartNow();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ring.dispose();
    super.dispose();
  }

  String _format(int s) {
    final m = (s ~/ 60).toString().padLeft(1, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final progress = 1.0 - (_remaining / _totalForCycle);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 14 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TimerRing(
                  progress: progress,
                  remaining: _format(_remaining),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TỰ ĐỘNG BẮT ĐẦU',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: c.invInkSoft.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                          letterSpacing: -0.1,
                          color: c.invInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _PrimaryCta(label: widget.startNowLabel, onTap: _startNow),
              ],
            ),
            const SizedBox(height: 10),
            _SecondaryCta(
              icon: Icons.add_rounded,
              label: '+${widget.extendSeconds}s · ${widget.extendLabel}',
              onTap: _extend,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.progress, required this.remaining});
  final double progress;
  final String remaining;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(58, 58),
            painter: _RingPainter(
              progress: progress,
              color: c.yellow,
              trackColor: c.invInkSoft.withValues(alpha: 0.18),
            ),
          ),
          Text(
            remaining,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.6,
              color: c.invInk,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - 5) / 2,
    );
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.2832, false, track);
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

class _PrimaryCta extends StatefulWidget {
  const _PrimaryCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: c.yellowInk,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16, color: c.yellowInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatelessWidget {
  const _SecondaryCta({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: c.invInkSoft),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: c.invInkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
