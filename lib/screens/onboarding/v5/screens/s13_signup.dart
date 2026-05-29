import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
        fallback: 'Không thể hoàn tất đăng nhập lúc này. Vui lòng thử lại.',
      ));
    }));
  }

  void _beginAuthAttempt(String provider) {
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
              'Không thể đăng nhập bằng Google lúc này. Vui lòng thử lại.'));
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
              'Không thể đăng nhập bằng Facebook lúc này. Vui lòng thử lại.'));
    } finally {
      _endAuthAttempt();
    }
  }

  Future<void> _signInWithApple() async {
    if (_busy) return;
    if (!Platform.isIOS) {
      _showError('Đăng nhập Apple chỉ hỗ trợ trên iPhone.');
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
              'Không thể đăng nhập bằng Apple lúc này. Vui lòng thử lại.'));
    } finally {
      _endAuthAttempt();
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
        setState(() => _notice = 'Link đăng nhập đã được gửi đến $email');
      }
    } catch (e) {
      _showError(_friendlyError(e,
          fallback: 'Không thể gửi link đăng nhập lúc này. Vui lòng thử lại.'));
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
    final p = derivePlanPersonalization(widget.data);
    final bmi = widget.data.bmi?.toStringAsFixed(1) ?? '22.0';
    final r = V5Responsive.of(context);
    final compact = r.isShort;
    final veryCompact = r.isVeryShort;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    final bottomInset = r.viewPadding.bottom;
    final topPadding = keyboardOpen
        ? r.viewPadding.top + r.pick(cozy: 72.0, veryShort: 58.0)
        : r.chromeTopPadding;
    final authContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (keyboardOpen)
          _EmailFocusHeader(busy: _busy)
        else ...[
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
            onGoogle: _signInWithGoogle,
            onFacebook: _signInWithFacebook,
          ),
          if (!compact) ...[
            const SizedBox(height: V5.space12),
            const _AccountValueStrip(),
          ],
          SizedBox(height: veryCompact ? V5.space8 : V5.space12),
        ],
        _EmailField(
          controller: _emailController,
          onChanged: (v) {
            widget.data.email = v;
            setState(() {});
          },
        ),
        const SizedBox(height: V5.space8),
        if (_notice != null)
          _NoticeBanner(message: _notice!)
        else if (!keyboardOpen)
          _SkipSignupButton(
            enabled: !_busy,
            onTap: widget.onNext,
          ),
      ],
    );
    return V5Screen(
      index: 15,
      onBack: widget.onBack,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              V5.gutter,
              topPadding,
              V5.gutter,
              bottomInset + (keyboardOpen ? 92 : (veryCompact ? 76 : 88)),
            ),
            child: keyboardOpen
                ? SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: authContent,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: authContent,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        V5PillCTA(
          label: _busy ? 'Đang xử lý...' : 'Gửi link đăng nhập',
          disabledLabel: 'Nhập email hoặc chọn tài khoản',
          enabled: _validEmail && !_busy,
          onTap: _magicLink,
          bottom: keyboardOpen ? keyboardInset + 12 : 32 + bottomInset,
        ),
      ],
    );
  }
}

class _EmailFocusHeader extends StatelessWidget {
  const _EmailFocusHeader({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: V5.space12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: V5.ink,
        borderRadius: BorderRadius.circular(V5.radiusMd),
        boxShadow: V5.elevation2,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: V5.yellow,
              borderRadius: BorderRadius.circular(V5.radiusSm),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: V5.yellowInk,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              busy ? 'Đang tạo lộ trình...' : 'Nhận link đăng nhập',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.titleSm(context, color: V5.invInk),
            ),
          ),
          const SizedBox(width: 8),
          const V5PulseDot(color: V5.yellow),
        ],
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

class _SkipSignupButton extends StatelessWidget {
  const _SkipSignupButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 640;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: dense ? 10 : 13,
          ),
          decoration: BoxDecoration(
            color: V5.ink.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(V5.radiusFull),
            border: Border.all(color: V5.borderHi),
          ),
          alignment: Alignment.center,
          child: Text(
            'Để sau, xem lộ trình',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V5.text(
              context,
              size: 13,
              weight: FontWeight.w700,
              color: V5.inkSoft,
              letterSpacing: -0.1,
            ),
          ),
        ),
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

class _ProviderRail extends StatelessWidget {
  const _ProviderRail({
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
            child: _ProviderTile(
              label: 'Apple',
              background: Colors.black,
              foreground: Colors.white,
              icon: const V5AppleMark(size: 18),
              onTap: busy ? null : onApple,
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
          const SizedBox(width: V5.space8),
          Expanded(
            child: _ProviderTile(
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

class _AccountValueStrip extends StatelessWidget {
  const _AccountValueStrip();

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

class _ProviderTile extends StatefulWidget {
  const _ProviderTile({
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
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
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
