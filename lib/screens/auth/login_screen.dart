import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:vika/services/auth_service.dart';

import '../onboarding/v5/v5_primitives.dart';
import '../onboarding/v5/v5_theme.dart';
import 'auth_v5_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final AuthService _authService;
  bool _busy = false;
  String? _notice;

  bool get _validEmail {
    final email = _emailController.text.trim();
    return email.contains('@') && email.contains('.');
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _authService = AuthService();
    _emailController.addListener(_handleEmailChanged);
  }

  // The CTA's enabled state listens to the controller directly (see the
  // AnimatedBuilder in build), so typing must NOT setState the whole screen.
  // The only screen-level state a keystroke can touch is dismissing a stale
  // notice — and only when one is actually showing.
  void _handleEmailChanged() {
    if (_notice != null) {
      setState(() => _notice = null);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() => _notice = 'Đăng nhập thành công.');
      }
    } on AuthFlowCancelledException {
      // dismissed sheet
    } catch (error) {
      _showError(_friendlyError(
        error,
        fallback: 'Không thể đăng nhập lúc này. Vui lòng thử lại.',
      ));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (!Platform.isIOS) {
      _showError('Đăng nhập Apple chỉ hỗ trợ trên iPhone.');
      return;
    }
    await _runAuth(() async {
      await _authService.signInWithApple();
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuth(() async {
      await _authService.signInWithGoogle();
    });
  }

  Future<void> _signInWithFacebook() async {
    await _runAuth(() async {
      await _authService.signInWithFacebook();
    });
  }

  Future<void> _sendMagicLink() async {
    if (!_validEmail || _busy) return;
    final email = _emailController.text.trim();
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await _authService.signInWithMagicLink(email);
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/magic-link-sent',
        arguments: email,
      );
    } catch (error) {
      _showError(_friendlyError(
        error,
        fallback: 'Không thể gửi link đăng nhập lúc này. Vui lòng thử lại.',
      ));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _friendlyError(Object e, {required String fallback}) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    return raw.isEmpty ? fallback : raw;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: V5.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _handleBack() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final compact = r.isShort;

    // Gold-standard keyboard-aware form — see [V5KeyboardForm]. Shared verbatim
    // with the S13 onboarding sign-in so the two screens behave identically.
    return V5KeyboardForm(
      // Soft warm halo, top-right — the only ambient on the cream canvas.
      backgroundLayers: const [
        Positioned(
          top: -130,
          right: -90,
          child: V5AmbientGlow(
            size: Size(320, 340),
            opacity: 0.10,
            color: V5.yellow,
          ),
        ),
      ],
      // Pinned send button. Only this rebuilds as you type — it listens to the
      // controller, so keystrokes never touch the rest of the screen.
      footer: AnimatedBuilder(
        animation: _emailController,
        builder: (context, _) => _MagicLinkCta(
          label: _busy ? 'Đang xử lý...' : 'Gửi link đăng nhập',
          disabledLabel: 'Nhập email để nhận link',
          enabled: _validEmail && !_busy,
          onTap: _sendMagicLink,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoginTopBar(onBack: _handleBack),
              SizedBox(height: r.pick(cozy: V5.space28, short: V5.space16)),
              V5ScreenHeader(
                eyebrow: 'Đăng nhập',
                title: 'Chào mừng\ntrở lại.',
                size: compact ? V5HeaderSize.medium : V5HeaderSize.large,
              ),
              SizedBox(height: r.pick(cozy: V5.space20, short: V5.space14)),
              V5FadeIn(
                delay: const Duration(milliseconds: 120),
                slideY: 10,
                child: AuthWelcomeCard(compact: compact),
              ),
              SizedBox(height: r.pick(cozy: V5.space16, short: V5.space12)),
              V5FadeIn(
                delay: const Duration(milliseconds: 180),
                slideY: 8,
                child: AuthProviderRail(
                  busy: _busy,
                  onApple: _signInWithApple,
                  onGoogle: _signInWithGoogle,
                  onFacebook: _signInWithFacebook,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: V5.space12),
                const V5FadeIn(
                  delay: Duration(milliseconds: 240),
                  child: AuthValueStrip(),
                ),
              ],
              SizedBox(height: r.pick(cozy: V5.space16, short: V5.space12)),
              const _OrDivider(),
              SizedBox(height: r.pick(cozy: V5.space16, short: V5.space12)),
              V5FadeIn(
                delay: const Duration(milliseconds: 300),
                slideY: 8,
                child: AuthEmailField(
                  controller: _emailController,
                  // Notice-clearing is handled by the controller listener;
                  // typing must not setState the screen.
                  onChanged: (_) {},
                ),
              ),
              if (_notice != null) ...[
                const SizedBox(height: V5.space10),
                Text(
                  _notice!,
                  style: V5.bodySm(context, color: V5.inkSoft),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim header row: a circular back affordance + the wordmark. Replaces the
/// default AppBar so the screen reads as part of the editorial onboarding
/// system rather than a stock settings page.
class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBack,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: V5.borderHi, width: 1),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: V5.ink,
              size: 15,
            ),
          ),
        ),
        Text(
          'vika',
          style: V5.text(
            context,
            size: 20,
            weight: FontWeight.w800,
            color: V5.ink,
            letterSpacing: -1,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// "HOẶC" rule separating the social providers from the email magic-link.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: V5.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('HOẶC', style: V5.eyebrow(context, color: V5.inkFaint)),
        ),
        Expanded(child: Container(height: 1, color: V5.border)),
      ],
    );
  }
}

/// Inline send button — visually identical to [V5PillCTA] but laid out in a
/// Column (not Positioned), so it can pin to the bottom of the keyboard-aware
/// layout. Ink pill with a yellow arrow disc; disabled = outlined ghost.
class _MagicLinkCta extends StatefulWidget {
  const _MagicLinkCta({
    required this.label,
    required this.disabledLabel,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String disabledLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_MagicLinkCta> createState() => _MagicLinkCtaState();
}

class _MagicLinkCtaState extends State<_MagicLinkCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final fg = enabled ? V5.invInk : V5.inkFaint;
    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _pressed ? 0.97 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: V5.curveSharp,
          height: 60,
          padding: EdgeInsets.fromLTRB(28, 0, enabled ? 8 : 28, 0),
          decoration: BoxDecoration(
            color: enabled ? V5.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(V5.radiusFull),
            border:
                enabled ? null : Border.all(color: V5.borderHi, width: 1.4),
            boxShadow: enabled ? V5.elevation4 : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  enabled ? widget.label : widget.disabledLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.text(
                    context,
                    size: 15,
                    weight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: V5.curveSharp,
                width: enabled ? 44 : 24,
                height: enabled ? 44 : 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? V5.yellow : Colors.transparent,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: enabled ? 19 : 14,
                  color: enabled ? V5.yellowInk : V5.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
