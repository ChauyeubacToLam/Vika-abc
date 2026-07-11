import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../onboarding/v5/v5_primitives.dart';
import '../onboarding/v5/v5_theme.dart';
import 'reviewer_demo_gate.dart';

// FB_LOGIN_PRELAUNCH_HIDE: Facebook app pending Meta verification, not Live, so
// a Facebook login fails for non-app-roles. Flip to true to restore the Facebook
// sign-in tile post-verification. (Top-level so the dead `if` branch below isn't
// flagged as dead_code while the flag is false; OAuth wiring stays intact.)
bool _showFacebookTile = false;

/// App Review safe Sign in with Apple control.
///
/// The logo file is the unmodified left aligned white medium artwork from
/// Apple Design Resources. Its height always matches the button height, and
/// the title is one of the three variants allowed by Apple's HIG.
class V5SignInWithAppleButton extends StatefulWidget {
  const V5SignInWithAppleButton({
    super.key,
    required this.onPressed,
    this.onHoldComplete,
    this.height = 52,
  });

  static const title = 'Continue with Apple';
  static const officialLogoAsset =
      'assets/brands/apple_siwa_left_aligned_white_medium.svg';
  static const officialLogoKey = Key('official_apple_sign_in_logo');

  final VoidCallback? onPressed;
  final VoidCallback? onHoldComplete;
  final double height;

  @override
  State<V5SignInWithAppleButton> createState() =>
      _V5SignInWithAppleButtonState();
}

class _V5SignInWithAppleButtonState extends State<V5SignInWithAppleButton> {
  Timer? _holdTimer;
  bool _pressed = false;
  bool _suppressNextTap = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = true);
    if (widget.onHoldComplete == null) return;

    _holdTimer?.cancel();
    _suppressNextTap = false;
    _holdTimer = Timer(reviewerHoldDuration, () {
      if (!mounted) return;
      _suppressNextTap = true;
      setState(() => _pressed = false);
      widget.onHoldComplete?.call();
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    _holdTimer?.cancel();
    _suppressNextTap = false;
    if (!mounted) return;
    setState(() => _pressed = false);
  }

  void _handleTap() {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: V5SignInWithAppleButton.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _handleTap : null,
        onTapDown: enabled ? _handleTapDown : null,
        onTapUp: enabled ? _handleTapUp : null,
        onTapCancel: enabled ? _handleTapCancel : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.48,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            curve: V5.curveSharp,
            scale: _pressed ? 0.98 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(V5.radiusSm),
                boxShadow: V5.elevation1,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(V5.radiusSm),
                child: ColoredBox(
                  color: Colors.black,
                  child: SizedBox(
                    height: widget.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SvgPicture.asset(
                            V5SignInWithAppleButton.officialLogoAsset,
                            key: V5SignInWithAppleButton.officialLogoKey,
                            height: widget.height,
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                V5SignInWithAppleButton.title,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: '.SF Pro Text',
                                  fontSize: widget.height * 0.43,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthProviderRail extends StatelessWidget {
  const AuthProviderRail({
    super.key,
    required this.busy,
    required this.onApple,
    required this.onGoogle,
    required this.onFacebook,
    this.onAppleHoldComplete,
  });

  final bool busy;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;

  /// Optional silent press-and-hold on the Apple tile (5s, no visible hint) for
  /// the reviewer-access gate. A normal tap still triggers [onApple] unchanged.
  final VoidCallback? onAppleHoldComplete;

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 640;
    final providerHeight = dense ? 48.0 : 52.0;
    return SizedBox(
      height: providerHeight * 2 + V5.space8,
      child: Column(
        children: [
          V5SignInWithAppleButton(
            height: providerHeight,
            onPressed: busy ? null : onApple,
            onHoldComplete: busy ? null : onAppleHoldComplete,
          ),
          const SizedBox(height: V5.space8),
          Expanded(
            child: Row(
              children: [
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
                if (_showFacebookTile) ...[
                  const SizedBox(width: V5.space8),
                  Expanded(
                    child: _AuthProviderTile(
                      label: 'Facebook',
                      background: V5.surface,
                      foreground: V5.ink,
                      icon: const V5FacebookMark(size: 18),
                      onTap: busy ? null : onFacebook,
                      border: V5.borderHi,
                    ),
                  ),
                ],
              ],
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

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final dense = MediaQuery.sizeOf(context).height < 640;
    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      onTapDown: enabled ? _handleTapDown : null,
      onTapUp: enabled ? _handleTapUp : null,
      onTapCancel: enabled ? _handleTapCancel : null,
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
          Text(
            'EMAIL',
            style: V5.eyebrow(context, color: V5.inkFaint),
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

/// Which email flow the sign-in surfaces are showing: log into an existing
/// account, or create a new one. Shared by the standalone [LoginScreen] and the
/// onboarding S13 sign-in so both read identically.
enum AuthMode { signIn, signUp }

/// Segmented pill toggling [AuthMode]. Active segment = ink fill + cream label.
class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: Row(
        children: [
          _segment(context, 'Đăng nhập', AuthMode.signIn),
          _segment(context, 'Tạo tài khoản', AuthMode.signUp),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, AuthMode value) {
    final active = mode == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !active ? () => onChanged(value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: V5.curveSharp,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? V5.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(V5.radiusFull),
          ),
          child: Text(
            label,
            style: V5.text(
              context,
              size: 13,
              weight: FontWeight.w700,
              color: active ? V5.invInk : V5.inkSoft,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Obscured password input matching [AuthEmailField]'s framed style, with an
/// inline show/hide toggle. Shared by the standalone login and onboarding S13.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.label = 'MẬT KHẨU',
    this.hintText = 'Tối thiểu 8 ký tự',
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String label;
  final String hintText;
  final TextInputAction textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  final FocusNode _focusNode = FocusNode();
  bool _obscured = true;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 640;
    return Container(
      padding: EdgeInsets.fromLTRB(16, dense ? 8 : 12, 8, dense ? 8 : 12),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusMd),
        boxShadow: V5.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              widget.label,
              style: V5.eyebrow(context, color: V5.inkFaint),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                // Same touch-down focus workaround as [AuthEmailField] — dodges
                // the RenderEditable.selectWord crash on an unfocused field.
                child: Listener(
                  onPointerDown: (_) {
                    if (!_focusNode.hasFocus) _focusNode.requestFocus();
                  },
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: _obscured,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: widget.textInputAction,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
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
                      hintText: widget.hintText,
                      hintStyle: V5.text(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                        color: V5.inkFaint,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _obscured = !_obscured),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(
                    _obscured
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: V5.inkFaint,
                  ),
                ),
              ),
            ],
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
