import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/services/auth_service.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S13Signup extends StatefulWidget {
  const S13Signup({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
    this.onAuthenticated,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Future<void> Function()? onAuthenticated;

  @override
  State<S13Signup> createState() => _S13SignupState();
}

class _S13SignupState extends State<S13Signup> {
  late final TextEditingController _emailController;
  late final AuthService _authService;
  StreamSubscription<AuthState>? _authSubscription;
  bool _busy = false;
  String? _notice;
  bool _advancing = false;

  bool get _validEmail {
    final email = _emailController.text.trim();
    return email.contains('@') && email.contains('.');
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.data.email ?? '');
    _authService = AuthService();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(_advanceIfAuthenticated());
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_advanceIfAuthenticated()),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _advanceIfAuthenticated() async {
    if (!mounted || _advancing) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _advancing = true;
    setState(() {
      _busy = true;
      _notice = 'Đang tạo lộ trình cá nhân của bạn...';
    });
    widget.data.email = user.email ?? widget.data.email;
    try {
      await widget.onAuthenticated?.call();
    } catch (_) {
      // Plan bootstrap is best-effort here; S15 has its own retry state.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onNext();
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Native GoogleSignIn → signInWithIdToken. No browser hop, so no
      // Supabase callback page or chrome redirect.
      await _authService.signInWithGoogle();
      await _advanceIfAuthenticated();
    } catch (e) {
      _showError(_friendlyError(e,
          fallback:
              'Không thể đăng nhập bằng Google lúc này. Vui lòng thử lại.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithFacebook() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _authService.signInWithFacebook();
      await _advanceIfAuthenticated();
    } catch (e) {
      _showError(_friendlyError(e,
          fallback:
              'Không thể đăng nhập bằng Facebook lúc này. Vui lòng thử lại.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithApple() async {
    // Apple Sign-In requires a separate package on Android (sign_in_with_apple)
    // and iOS-side entitlements. Until that lands, surface a clear notice
    // rather than silently failing.
    _showError('Đăng nhập Apple sắp ra mắt — hãy dùng Google hoặc email.');
  }

  Future<void> _magicLink() async {
    if (!_validEmail || _busy) return;
    final email = _emailController.text.trim();
    setState(() => _busy = true);
    try {
      widget.data.email = email;
      await _authService.signInWithMagicLink(email);
      if (mounted) {
        setState(() => _notice = 'Link đăng nhập đã được gửi đến $email');
      }
    } catch (e) {
      _showError(_friendlyError(e,
          fallback: 'Không thể gửi link đăng nhập lúc này. Vui lòng thử lại.'));
    } finally {
      if (mounted) setState(() => _busy = false);
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
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: V5.ink));
  }

  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(widget.data);
    final bmi = widget.data.bmi?.toStringAsFixed(1) ?? '22.0';
    return V5Screen(
      index: 13,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: 144,
          left: 16,
          right: 16,
          height: 168,
          child: V5FadeIn(
            child: V5HeroCard(
              borderRadius: 24,
              child: Stack(
                children: [
                  Positioned(
                    top: 18,
                    left: 20,
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 12, color: V5.yellow),
                        const SizedBox(width: 8),
                        Text(
                          'LỘ TRÌNH CỦA BẠN ĐÃ SẴN SÀNG',
                          style: V5.text(
                            context,
                            size: 10,
                            weight: FontWeight.w800,
                            color: V5.invInk,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      children: [
                        _HeroStat(label: 'Mức tập', value: p.levelLabel),
                        const SizedBox(width: 8),
                        _HeroStat(
                          label: 'Lịch tập',
                          value: '${p.freq}',
                          suffix: 'buổi/tuần',
                          yellow: true,
                        ),
                        const SizedBox(width: 8),
                        _HeroStat(label: 'BMI', value: bmi),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 328,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khoá lộ trình',
                style: V5.text(
                  context,
                  size: 22,
                  weight: FontWeight.w800,
                  color: V5.ink,
                  letterSpacing: -.7,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tạo tài khoản để lưu & theo dõi tiến trình',
                style: V5.text(
                  context,
                  size: 12,
                  weight: FontWeight.w500,
                  color: V5.inkSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 396,
          left: 0,
          right: 0,
          bottom: 108,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _SocialButton(
                  label: 'Tiếp tục với Apple',
                  background: Colors.black,
                  foreground: Colors.white,
                  icon: const V5AppleMark(),
                  onTap: _signInWithApple,
                ),
                const SizedBox(height: 8),
                _SocialButton(
                  label: 'Tiếp tục với Google',
                  background: V5.surface,
                  foreground: V5.ink,
                  border: V5.borderHi,
                  icon: const V5GoogleMark(),
                  onTap: _signInWithGoogle,
                ),
                const SizedBox(height: 8),
                _SocialButton(
                  label: 'Tiếp tục với Facebook',
                  background: const Color(0xFF1877F2),
                  foreground: Colors.white,
                  icon: const V5FacebookMark(),
                  onTap: _signInWithFacebook,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: V5.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'HOẶC',
                        style: V5.text(
                          context,
                          size: 10,
                          weight: FontWeight.w700,
                          color: V5.inkFaint,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: V5.border)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: V5.surface,
                    border: Border.all(color: V5.border),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [V5.cardShadow(0.08)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'EMAIL',
                            style: V5.text(
                              context,
                              size: 9,
                              weight: FontWeight.w700,
                              color: V5.inkFaint,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.mail_outline_rounded,
                              size: 11, color: V5.yellowDeep),
                          const SizedBox(width: 4),
                          Text(
                            'Vika gửi link đăng nhập',
                            style: V5.text(
                              context,
                              size: 9,
                              weight: FontWeight.w700,
                              color: V5.yellowDeep,
                              letterSpacing: .3,
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) {
                          widget.data.email = value;
                          setState(() {});
                        },
                        style: V5.text(
                          context,
                          size: 14,
                          weight: FontWeight.w600,
                          color: V5.ink,
                          letterSpacing: -.1,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'ban@email.com',
                          hintStyle: V5.text(
                            context,
                            size: 14,
                            weight: FontWeight.w600,
                            color: V5.ink.withValues(alpha: .30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _notice!,
                    textAlign: TextAlign.center,
                    style: V5.text(
                      context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: V5.yellowDeep,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        V5PillCTA(
          label: _busy ? 'Đang xử lý...' : 'Gửi link đăng nhập',
          disabledLabel: 'Nhập email hoặc chọn tài khoản',
          enabled: _validEmail && !_busy,
          onTap: _magicLink,
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.suffix,
    this.yellow = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final bool yellow;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: V5.text(
                context,
                size: 8,
                weight: FontWeight.w700,
                color: V5.invInkSoft,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: V5.text(
                  context,
                  size: 14,
                  weight: FontWeight.w800,
                  color: yellow ? V5.yellow : V5.invInk,
                  letterSpacing: -.3,
                  height: 1,
                ),
                children: [
                  TextSpan(text: value),
                  if (suffix != null)
                    TextSpan(
                      text: ' $suffix',
                      style: V5.text(
                        context,
                        size: 9,
                        weight: FontWeight.w700,
                        color: V5.invInk,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
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
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: border == null ? null : Border.all(color: border!),
          boxShadow: [
            V5.cardShadow(background == const Color(0xFF1877F2) ? .10 : .18)
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: V5.text(
                context,
                size: 14,
                weight: FontWeight.w700,
                color: foreground,
                letterSpacing: -.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
