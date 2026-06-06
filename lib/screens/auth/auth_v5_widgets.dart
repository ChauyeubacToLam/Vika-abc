import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../onboarding/v5/v5_primitives.dart';
import '../onboarding/v5/v5_theme.dart';

class AuthProviderRail extends StatelessWidget {
  const AuthProviderRail({
    super.key,
    required this.busy,
    required this.onApple,
    required this.onGoogle,
    required this.onFacebook,
  });

  final bool busy;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 640;
    return SizedBox(
      height: dense ? 58 : 68,
      child: Row(
        children: [
          Expanded(
            child: _AuthProviderTile(
              label: 'Apple',
              background: Colors.black,
              foreground: Colors.white,
              icon: const V5AppleMark(size: 18),
              onTap: busy ? null : onApple,
            ),
          ),
          const SizedBox(width: V5.space8),
          Expanded(
            child: _AuthProviderTile(
              label: 'Google',
              background: V5.surface,
              foreground: V5.ink,
              icon: const V5GoogleMark(size: 18),
              onTap: busy ? null : onGoogle,
              border: V5.borderHi,
            ),
          ),
          const SizedBox(width: V5.space8),
          Expanded(
            child: _AuthProviderTile(
              label: 'Facebook',
              background: const Color(0xFF1877F2),
              foreground: Colors.white,
              icon: const V5FacebookMark(size: 17),
              onTap: busy ? null : onFacebook,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthProviderTile extends StatefulWidget {
  const _AuthProviderTile({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget icon;
  final VoidCallback? onTap;
  final Color? border;

  @override
  State<_AuthProviderTile> createState() => _AuthProviderTileState();
}

class _AuthProviderTileState extends State<_AuthProviderTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final dense = MediaQuery.sizeOf(context).height < 640;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.48,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: V5.curveSharp,
          scale: _pressed ? 0.97 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: BorderRadius.circular(V5.radiusMd),
              border: widget.border == null
                  ? null
                  : Border.all(color: widget.border!),
              boxShadow: V5.elevation1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.icon,
                SizedBox(height: dense ? 4 : 6),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.text(
                    context,
                    size: dense ? 10.5 : 11.5,
                    weight: FontWeight.w800,
                    color: widget.foreground,
                    letterSpacing: 0,
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

class AuthEmailField extends StatefulWidget {
  const AuthEmailField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<AuthEmailField> createState() => _AuthEmailFieldState();
}

class _AuthEmailFieldState extends State<AuthEmailField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 640;
    return Container(
      padding: EdgeInsets.fromLTRB(16, dense ? 10 : 14, 16, dense ? 10 : 14),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusMd),
        boxShadow: V5.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'EMAIL',
                style: V5.eyebrow(context, color: V5.inkFaint),
              ),
              const Spacer(),
              if (!dense)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: V5.yellowSoft,
                    borderRadius: BorderRadius.circular(V5.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 11,
                        color: V5.yellowDeep,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LINK ĐĂNG NHẬP',
                        style: V5
                            .eyebrow(context, color: V5.yellowDeep)
                            .copyWith(letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Focus on touch-down (via a non-arena Listener, so it doesn't
          // disturb scrolling or tapping) so a long-press always lands on an
          // already-focused field. This dodges a Flutter framework crash where
          // long-pressing an UNFOCUSED field calls RenderEditable.selectWord
          // with a null _lastTapDownPosition (editable.dart selectWord).
          Listener(
            onPointerDown: (_) {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
            },
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.emailAddress,
              onChanged: widget.onChanged,
              cursorColor: V5.yellow,
              style: V5.text(
                context,
                size: 15,
                weight: FontWeight.w600,
                color: V5.ink,
                letterSpacing: -0.1,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'ban@email.com',
                hintStyle: V5.text(
                  context,
                  size: 15,
                  weight: FontWeight.w600,
                  color: V5.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Returning-user "welcome back" hero card. Mirrors the S13 onboarding
// sign-in composition (a dark plan card above the provider rail), but
// framed for a returning user whose progress is already saved.
// ─────────────────────────────────────────────────────────────

class AuthWelcomeCard extends StatelessWidget {
  const AuthWelcomeCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 120 : 158,
      child: V5HeroCard(
        borderRadius: V5.radiusLg,
        elevation: 2,
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -48,
              child: V5AmbientGlow(
                size: const Size(190, 190),
                opacity: 0.20,
                color: V5.yellow,
              ),
            ),
            Positioned(
              right: compact ? 14 : 20,
              top: compact ? 14 : 18,
              bottom: compact ? 14 : 18,
              width: compact ? 76 : 94,
              child: const CustomPaint(painter: _AuthOrbitPainter()),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                compact ? 14 : 18,
                compact ? 104 : 128,
                compact ? 14 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmark_added_rounded,
                        size: 13,
                        color: V5.yellow,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'TIẾP TỤC LỘ TRÌNH',
                        style: V5.eyebrow(context, color: V5.invInkSoft),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Tiến bộ của bạn\nvẫn được lưu lại.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? V5.titleSm(context, color: V5.invInk)
                        : V5.title(context, color: V5.invInk),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: V5.space10),
                    Text(
                      'Đăng nhập để tiếp tục ngay nơi bạn dừng lại.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V5.bodySm(context, color: V5.invInkSoft),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Account value strip — Lịch tập / Báo cáo / Tiến bộ. Reassures a returning
/// user what's waiting behind sign-in. Mirrors S13's account value strip.
class AuthValueStrip extends StatelessWidget {
  const AuthValueStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.calendar_month_rounded, 'Lịch tập'),
      (Icons.insights_rounded, 'Báo cáo'),
      (Icons.history_rounded, 'Tiến bộ'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusMd),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: Row(
        children: [
          for (final entry in items.asMap().entries) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(entry.value.$1, size: 14, color: V5.yellowDeep),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.value.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V5
                          .text(
                            context,
                            size: 11.5,
                            weight: FontWeight.w800,
                            color: V5.inkSoft,
                            letterSpacing: 0,
                          )
                          .copyWith(height: 1),
                    ),
                  ),
                ],
              ),
            ),
            if (entry.key != items.length - 1)
              Container(width: 1, height: 22, color: V5.border),
          ],
        ],
      ),
    );
  }
}

class _AuthOrbitPainter extends CustomPainter {
  const _AuthOrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;

    // Concentric rings — quiet structure behind the accent arc.
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        radius * (0.5 + i * 0.25),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.10),
      );
    }

    // Gold sweep arc — the "progress saved" motif.
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi * 0.72,
      math.pi * 1.18,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [V5.yellowSpark, V5.yellow, Color(0xFFF9E5A4)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // Nodes — a small constellation, echoing the plan-graph language.
    final nodePaint = Paint()..color = V5.yellow;
    for (final p in const [
      Offset(0.32, 0.30),
      Offset(0.66, 0.50),
      Offset(0.40, 0.72),
    ]) {
      canvas.drawCircle(
        Offset(size.width * p.dx, size.height * p.dy),
        3,
        nodePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuthOrbitPainter oldDelegate) => false;
}
