import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

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
    this.skipping = false,
    this.onAuthenticated,
    this.onAuthStarted,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// When true, render a loader instead of the sign-in form — the navigator is
  /// auto-skipping this step for an already-authenticated user (routed here
  /// from the standalone login) so they aren't asked to sign in twice.
  final bool skipping;

  final Future<void> Function()? onAuthenticated;

  /// Called the instant a sign-in attempt begins (any provider or magic link),
  /// so the app entry gate can stand down while this screen owns the flow.
  final VoidCallback? onAuthStarted;

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
  bool _acceptAuthEvents = false;
  String? _pendingProvider;

  bool get _validEmail {
    final email = _emailController.text.trim();
    return email.contains('@') && email.contains('.');
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.data.email ?? '');
    _authService = AuthService();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: _handleAuthStreamError,
    );
  }

  /// Auth failures (e.g. an expired/used magic link opened via deep link)
  /// arrive as errors on this broadcast stream. Without an onError handler
  /// they'd crash the app. Reset the in-flight auth state and surface a
  /// friendly message instead.
  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    _acceptAuthEvents = false;
    _pendingProvider = null;
    _advancing = false;
    setState(() => _busy = false);
    _showError(
      'Link đã hết hạn hoặc không hợp lệ. Hãy thử gửi lại.',
    );
  }

  void _handleAuthStateChange(AuthState data) {
    if (!_acceptAuthEvents || data.event != AuthChangeEvent.signedIn) {
      return;
    }
    unawaited(_advanceIfAuthenticated(expectedProvider: _pendingProvider)
        .catchError((error) {
      _showError(_friendlyError(
        error,
        fallback: 'Đăng nhập chưa thành công. Vui lòng thử lại.',
      ));
    }));
  }

  void _beginAuthAttempt(String provider) {
    // Claim auth ownership BEFORE AuthService runs — its interactive sign-in
    // signs out any stale session first (a transient `signedOut`), and the gate
    // must already be standing down so it doesn't bounce us to the login page.
    widget.onAuthStarted?.call();
    _acceptAuthEvents = true;
    _pendingProvider = provider;
    setState(() {
      _busy = true;
      _notice = null;
    });
  }

  void _endAuthAttempt() {
    _acceptAuthEvents = false;
    _pendingProvider = null;
    if (mounted && !_advancing) {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _advanceIfAuthenticated({String? expectedProvider}) async {
    if (!mounted || _advancing) return;
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    if (user == null) return;

    if (expectedProvider != null &&
        !_sessionIncludesProvider(session!, expectedProvider)) {
      throw Exception(
        'Phiên đăng nhập hiện tại không phải $expectedProvider. Vui lòng thử lại.',
      );
    }

    _advancing = true;
    _acceptAuthEvents = false;
    setState(() {
      _busy = true;
      _notice = 'Đang tạo lộ trình cho bạn…';
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

  bool _sessionIncludesProvider(Session session, String provider) {
    final appMetadata = session.user.appMetadata;
    final primaryProvider = appMetadata['provider']?.toString();
    final providers = appMetadata['providers'];
    if (primaryProvider == provider) return true;
    return providers is List &&
        providers.map((value) => '$value').contains(provider);
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    _beginAuthAttempt('google');
    try {
      await _authService.signInWithGoogle();
      await _advanceIfAuthenticated(expectedProvider: 'google');
    } on AuthFlowCancelledException {
      // dismissed sheet
    } catch (e) {
      _showError(_friendlyError(e,
          fallback:
              'Đăng nhập bằng Google không thành công. Vui lòng thử lại.'));
    } finally {
      _endAuthAttempt();
    }
  }

  Future<void> _signInWithFacebook() async {
    if (_busy) return;
    _beginAuthAttempt('facebook');
    try {
      await _authService.signInWithFacebook();
      await _advanceIfAuthenticated(expectedProvider: 'facebook');
    } on AuthFlowCancelledException {
      // dismissed sheet
    } catch (e) {
      _showError(_friendlyError(e,
          fallback:
              'Đăng nhập bằng Facebook không thành công. Vui lòng thử lại.'));
    } finally {
      _endAuthAttempt();
    }
  }

  Future<void> _signInWithApple() async {
    if (_busy) return;
    if (!Platform.isIOS) {
      _showError('Đăng nhập bằng Apple chỉ khả dụng trên iPhone.');
      return;
    }
    _beginAuthAttempt('apple');
    try {
      await _authService.signInWithApple();
      await _advanceIfAuthenticated(expectedProvider: 'apple');
    } on AuthFlowCancelledException {
      // dismissed sheet
    } catch (e) {
      _showError(_friendlyError(e,
          fallback:
              'Đăng nhập bằng Apple không thành công. Vui lòng thử lại.'));
    } finally {
      _endAuthAttempt();
    }
  }

  Future<void> _showReviewerDemoPrompt() async {
    if (_busy || !mounted) return;

    // The dialog OWNS its TextEditingController (see [_ReviewerCodeDialog]) and
    // disposes it in its own State.dispose — which only fires after the route is
    // fully gone. The old code disposed a parent-owned controller synchronously
    // right after showDialog returned, while the dialog was still animating out
    // and its field still referenced it → "used after being disposed" crash.
    final code = await showDialog<String>(
      context: context,
      barrierColor: V5.ink.withValues(alpha: 0.42),
      builder: (_) => const _ReviewerCodeDialog(),
    );

    if (!mounted || code == null || code.isEmpty) return;
    await _enterReviewerDemo(code);
  }

  Future<void> _enterReviewerDemo(String code) async {
    if (_busy) return;

    // Claim auth ownership BEFORE touching Supabase: verifyOTP below fires a
    // `signedIn` event on the global auth stream, and the entry gate must
    // already be standing down so it can't race the navigation that follows.
    widget.onAuthStarted?.call();
    _acceptAuthEvents = false;
    _pendingProvider = null;
    setState(() {
      _busy = true;
      _notice = null;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'demo-session',
        body: {'code': code},
      );
      final data = res.data;
      final email = data is Map ? data['email']?.toString() : null;
      final otp = data is Map ? data['otp']?.toString() : null;
      if (email == null || email.isEmpty || otp == null || otp.isEmpty) {
        throw const FormatException('Invalid demo session response');
      }

      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.magiclink,
      );

      if (!mounted) return;
      // Reviewer sees a read-only plan reveal before entering the seeded home.
      Navigator.of(context).pushReplacementNamed('/reviewer-demo');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      // Reviewer-only chrome → English (audience is the Apple reviewer).
      _showError('Unable to open reviewer mode. Check the code and try again.');
    }
  }

  Future<void> _magicLink() async {
    if (!_validEmail || _busy) return;
    final email = _emailController.text.trim();
    _beginAuthAttempt('email');
    try {
      widget.data.email = email;
      await _authService.signInWithMagicLink(email);
      if (mounted) {
        setState(() => _notice = 'Đã gửi link đăng nhập đến $email');
      }
    } catch (e) {
      _showError(
          _friendlyError(e, fallback: 'Chưa gửi được link. Vui lòng thử lại.'));
      _acceptAuthEvents = false;
      _pendingProvider = null;
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
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: V5.ink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skipping) return _buildSkippingView(context);
    final p = derivePlanPersonalization(widget.data);
    final bmi = widget.data.bmi?.toStringAsFixed(1) ?? '22.0';
    final r = V5Responsive.of(context);
    final compact = r.isShort;
    final veryCompact = r.isVeryShort;

    // Gold-standard keyboard-aware form — see [V5KeyboardForm]. Shared verbatim
    // with the standalone LoginScreen so the two screens behave identically.
    // The onboarding chrome (back + phase progress) renders IN FLOW as the
    // first scroll child (not as a fixed overlay), so SafeArea keeps it clear of
    // the status bar and it scrolls naturally when the keyboard lifts the form.
    return V5KeyboardForm(
      footer: _InlineMagicLinkCta(
        label: _busy ? 'Đang xử lý...' : 'Gửi link đăng nhập',
        disabledLabel: 'Nhập email hoặc liên kết tài khoản',
        enabled: _validEmail && !_busy,
        onTap: _magicLink,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingChrome(onBack: widget.onBack),
          SizedBox(height: r.pick(cozy: V5.space24, short: V5.space14)),
          V5ScreenHeader(
            eyebrow: 'Mở khoá lộ trình',
            title: 'Lộ trình đã\nsẵn sàng.',
            size: veryCompact ? V5HeaderSize.medium : V5HeaderSize.large,
          ),
          SizedBox(height: veryCompact ? V5.space8 : V5.space12),
          V5FadeIn(
            delay: const Duration(milliseconds: 140),
            child: veryCompact
                ? _PlanMiniStrip(
                    levelLabel: p.levelLabel,
                    freq: p.freq,
                    bmi: bmi,
                  )
                : _PlanForgeCard(
                    levelLabel: p.levelLabel,
                    freq: p.freq,
                    bmi: bmi,
                    compact: compact,
                  ),
          ),
          SizedBox(height: compact ? V5.space10 : V5.space16),
          _ProviderRail(
            busy: _busy,
            onApple: _signInWithApple,
            onAppleReviewerDemo: _showReviewerDemoPrompt,
            onGoogle: _signInWithGoogle,
            onFacebook: _signInWithFacebook,
          ),
          if (!compact) ...[
            const SizedBox(height: V5.space12),
            const _AccountValueStrip(),
          ],
          SizedBox(height: veryCompact ? V5.space8 : V5.space12),
          _EmailField(
            controller: _emailController,
            onChanged: (v) {
              widget.data.email = v;
              setState(() {});
            },
          ),
          const SizedBox(height: V5.space8),
          if (_notice != null) _NoticeBanner(message: _notice!),
        ],
      ),
    );
  }

  /// Shown while the navigator auto-skips this step for an already-authenticated
  /// user. No chrome (back/progress) — it's a brief pass-through; the plan
  /// generation it kicks off is surfaced by S15's own loading state.
  Widget _buildSkippingView(BuildContext context) {
    return V5Screen(
      index: 15,
      showChrome: false,
      children: [
        Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(V5.yellow),
                  ),
                ),
                const SizedBox(height: V5.space16),
                Text(
                  'Đang tạo lộ trình cho bạn…',
                  style: V5.bodySm(context, color: V5.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// In-flow onboarding chrome (back affordance + index + phase progress).
/// Mirrors [V5TopChrome] but lives in the scroll flow instead of as a fixed
/// overlay, so SafeArea keeps it clear of the status bar and it scrolls with
/// the form when the keyboard lifts the layout.
class _OnboardingChrome extends StatelessWidget {
  const _OnboardingChrome({required this.onBack});

  final VoidCallback onBack;

  static const int _index = 15;
  static const int _total = 17;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
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
              '${_index.toString().padLeft(2, '0')} — ${_total.toString().padLeft(2, '0')}',
              style: V5.text(
                context,
                size: 11,
                weight: FontWeight.w600,
                color: V5.inkSoft,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const V5PhaseProgress(index: _index),
      ],
    );
  }
}

/// Inline send button — visually identical to [V5PillCTA] but laid out in a
/// Column (not Positioned), so it can pin to the bottom of the keyboard-aware
/// layout. Matches the standalone LoginScreen's CTA exactly.
class _InlineMagicLinkCta extends StatefulWidget {
  const _InlineMagicLinkCta({
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
  State<_InlineMagicLinkCta> createState() => _InlineMagicLinkCtaState();
}

class _InlineMagicLinkCtaState extends State<_InlineMagicLinkCta> {
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
            border: enabled ? null : Border.all(color: V5.borderHi, width: 1.4),
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

/// Reviewer access-code prompt, styled to the Premium Ivory design system.
///
/// Owns its [TextEditingController] and disposes it in its OWN [State.dispose],
/// which fires only after the dialog route is fully gone — so the field never
/// references a disposed controller mid dismiss-animation. (The prior version
/// disposed a parent-owned controller right after showDialog returned, while
/// the dialog was still animating out → "TextEditingController used after being
/// disposed".)
///
/// This is reviewer-only chrome, so the copy is ENGLISH (audience: the Apple
/// reviewer). Returns the trimmed code via [Navigator.pop], or null on cancel.
class _ReviewerCodeDialog extends StatefulWidget {
  const _ReviewerCodeDialog();

  @override
  State<_ReviewerCodeDialog> createState() => _ReviewerCodeDialogState();
}

class _ReviewerCodeDialogState extends State<_ReviewerCodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());
  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: V5.surface,
          borderRadius: BorderRadius.circular(V5.radiusLg),
          border: Border.all(color: V5.border),
          boxShadow: V5.elevation4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: V5.yellowSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: V5.yellowDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Reviewer access', style: V5.title(context, color: V5.ink)),
              ],
            ),
            const SizedBox(height: V5.space8),
            Text(
              'Enter the access code to open a read-only demo of the app.',
              style: V5.bodySm(context, color: V5.inkSoft),
            ),
            const SizedBox(height: V5.space16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: V5.bgSoft,
                border: Border.all(color: V5.border),
                borderRadius: BorderRadius.circular(V5.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCESS CODE',
                    style: V5.eyebrow(context, color: V5.inkFaint),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    cursorColor: V5.yellow,
                    style: V5.text(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                      color: V5.ink,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '••••••',
                      hintStyle: V5.text(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                        color: V5.inkFaint,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: V5.space16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _cancel,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(V5.radiusFull),
                        border: Border.all(color: V5.borderHi, width: 1.4),
                      ),
                      child: Text(
                        'Cancel',
                        style: V5.text(
                          context,
                          size: 14,
                          weight: FontWeight.w700,
                          color: V5.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                      decoration: BoxDecoration(
                        color: V5.ink,
                        borderRadius: BorderRadius.circular(V5.radiusFull),
                        boxShadow: V5.elevation2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Continue',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.text(
                                context,
                                size: 14,
                                weight: FontWeight.w700,
                                color: V5.invInk,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: V5.yellow,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: V5.yellowInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: V5.yellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: V5.yellow.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined,
              color: V5.yellowDeep, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V5.bodySm(context, color: V5.yellowDeep),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanForgeCard extends StatelessWidget {
  const _PlanForgeCard({
    required this.levelLabel,
    required this.freq,
    required this.bmi,
    required this.compact,
  });

  final String levelLabel;
  final int freq;
  final String bmi;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 112 : 178,
      child: V5HeroCard(
        borderRadius: V5.radiusLg,
        elevation: 2,
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -52,
              child: V5AmbientGlow(
                size: const Size(190, 190),
                opacity: 0.2,
                color: V5.yellow,
              ),
            ),
            Positioned(
              right: compact ? 12 : 18,
              top: compact ? 16 : 18,
              bottom: compact ? 16 : 18,
              width: compact ? 74 : 92,
              child: CustomPaint(
                painter: _PlanForgePainter(progress: compact ? 0.62 : 0.72),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                compact ? 14 : 17,
                compact ? 102 : 128,
                compact ? 14 : 17,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: V5.yellow,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'KẾ HOẠCH CÁ NHÂN',
                        style: V5.eyebrow(context, color: V5.invInkSoft),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Đăng nhập để xem lộ trình dành riêng cho bạn.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? V5.titleSm(context, color: V5.invInk)
                        : V5.title(context, color: V5.invInk),
                  ),
                  SizedBox(height: compact ? V5.space10 : V5.space14),
                  _PlanMetricRail(
                    levelLabel: levelLabel,
                    freq: freq,
                    bmi: bmi,
                    dark: true,
                    compact: compact,
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

class _PlanMiniStrip extends StatelessWidget {
  const _PlanMiniStrip({
    required this.levelLabel,
    required this.freq,
    required this.bmi,
  });

  final String levelLabel;
  final int freq;
  final String bmi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: V5.ink,
        borderRadius: BorderRadius.circular(V5.radiusMd),
        boxShadow: V5.elevation2,
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: V5.yellow, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: _PlanMetricRail(
              levelLabel: levelLabel,
              freq: freq,
              bmi: bmi,
              dark: true,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMetricRail extends StatelessWidget {
  const _PlanMetricRail({
    required this.levelLabel,
    required this.freq,
    required this.bmi,
    required this.dark,
    required this.compact,
  });

  final String levelLabel;
  final int freq;
  final String bmi;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlanChip(label: levelLabel, dark: dark, compact: compact),
            const SizedBox(width: 6),
            _PlanChip(label: '${freq}x/tuần', dark: dark, compact: compact),
            const SizedBox(width: 6),
            _PlanChip(label: 'BMI $bmi', dark: dark, compact: compact),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.label,
    this.dark = false,
    this.compact = false,
  });

  final String label;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 22 : 24),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.07)
            : V5.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: dark ? V5.heroBorderHi : V5.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: V5
            .eyebrow(context, color: dark ? V5.invInkSoft : V5.inkSoft)
            .copyWith(letterSpacing: compact ? 0.4 : 0.8),
      ),
    );
  }
}

// FB_LOGIN_PRELAUNCH_HIDE: Facebook app pending Meta verification, not Live, so
// a Facebook login fails for non-app-roles. Flip to true to restore the Facebook
// sign-in tile post-verification. (Top-level so the dead `if` branch below isn't
// flagged as dead_code while the flag is false; OAuth wiring stays intact.)
bool _showFacebookTile = false;

class _ProviderRail extends StatelessWidget {
  const _ProviderRail({
    required this.busy,
    required this.onApple,
    required this.onAppleReviewerDemo,
    required this.onGoogle,
    required this.onFacebook,
  });

  final bool busy;
  final VoidCallback onApple;
  final VoidCallback onAppleReviewerDemo;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 640;
    return SizedBox(
      height: dense ? 58 : 68,
      // Uniform light tiles with the authentic brand logos — matches the
      // standalone LoginScreen rail so the two sign-in surfaces read identically.
      child: Row(
        children: [
          Expanded(
            child: _ProviderTile(
              label: 'Apple',
              background: V5.surface,
              foreground: V5.ink,
              icon: const V5AppleMark(size: 18),
              onTap: busy ? null : onApple,
              onHoldComplete: busy ? null : onAppleReviewerDemo,
              border: V5.borderHi,
            ),
          ),
          const SizedBox(width: V5.space8),
          Expanded(
            child: _ProviderTile(
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
              child: _ProviderTile(
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
    );
  }
}

class _AccountValueStrip extends StatelessWidget {
  const _AccountValueStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.calendar_month_rounded, 'Lịch tập'),
      (Icons.insights_rounded, 'Phân tích form'),
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

class _ProviderTile extends StatefulWidget {
  const _ProviderTile({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
    this.border,
    this.onHoldComplete,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget icon;
  final VoidCallback? onTap;
  final Color? border;
  final VoidCallback? onHoldComplete;

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  static const Duration _reviewerHoldDuration = Duration(seconds: 5);

  Timer? _holdTimer;
  bool _pressed = false;
  bool _suppressNextTap = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() => _pressed = true);
    if (widget.onHoldComplete == null) return;

    _holdTimer?.cancel();
    _suppressNextTap = false;
    _holdTimer = Timer(_reviewerHoldDuration, () {
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
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final dense = MediaQuery.sizeOf(context).height < 640;
    return GestureDetector(
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

class _PlanForgePainter extends CustomPainter {
  const _PlanForgePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = SweepGradient(
        colors: const [V5.yellowSpark, V5.yellow, Color(0xFFF9E5A4)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi * 0.72, math.pi * 1.44, false, track);
    canvas.drawArc(
      rect,
      -math.pi * 0.72,
      math.pi * 1.44 * progress.clamp(0.0, 1.0),
      false,
      active,
    );

    final nodePaint = Paint()..color = V5.yellow;
    for (final point in const [
      Offset(0.34, 0.28),
      Offset(0.68, 0.46),
      Offset(0.42, 0.72)
    ]) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        3,
        nodePaint,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.28),
      Offset(size.width * 0.68, size.height * 0.46),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.46),
      Offset(size.width * 0.42, size.height * 0.72),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanForgePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// Email field — refined input with floating label
// ─────────────────────────────────────────────────────────────

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
                      const Icon(Icons.mail_outline_rounded,
                          size: 11, color: V5.yellowDeep),
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
          TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            onChanged: onChanged,
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
        ],
      ),
    );
  }
}
