import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/vf_theme.dart';
import 'magic_link_sent_screen.dart';

enum _LoginAction { google, facebook, email }

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.onAuthenticated,
  });

  final VoidCallback? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: VFTheme.bg,
        body: SafeArea(
          child: VikaLoginPanel(
            onAuthenticated: onAuthenticated,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          ),
        ),
      ),
    );
  }
}

class VikaLoginPanel extends StatefulWidget {
  const VikaLoginPanel({
    super.key,
    this.onAuthenticated,
    this.padding = EdgeInsets.zero,
  });

  final VoidCallback? onAuthenticated;
  final EdgeInsets padding;

  @override
  State<VikaLoginPanel> createState() => _VikaLoginPanelState();
}

class _VikaLoginPanelState extends State<VikaLoginPanel> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _showEmail = false;
  _LoginAction? _activeAction;

  bool get _hasValidEmail => _emailController.text.trim().contains('@');
  bool get _isBusy => _activeAction != null;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    await _runAction(
      _LoginAction.google,
      () async {
        await _authService.signInWithGoogle();
        widget.onAuthenticated?.call();
      },
    );
  }

  Future<void> _handleFacebookSignIn() async {
    await _runAction(
      _LoginAction.facebook,
      () async {
        await _authService.signInWithFacebook();
        widget.onAuthenticated?.call();
      },
    );
  }

  Future<void> _handleMagicLink() async {
    if (!_hasValidEmail || _isBusy) {
      return;
    }

    final email = _emailController.text.trim();
    setState(() => _activeAction = _LoginAction.email);

    try {
      await _authService.signInWithMagicLink(email);
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MagicLinkSentScreen(email: email),
        ),
      );
    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() => _activeAction = null);
      }
    }
  }

  Future<void> _runAction(
    _LoginAction action,
    Future<void> Function() task,
  ) async {
    if (_isBusy) {
      return;
    }

    setState(() => _activeAction = action);
    try {
      await task();
    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() => _activeAction = null);
      }
    }
  }

  void _expandEmail() {
    if (_isBusy) {
      return;
    }

    setState(() => _showEmail = true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        _emailFocusNode.requestFocus();
      }
    });
  }

  void _showErrorSnackBar(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: VFTheme.text,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showAppleComingSoon() {
    if (_isBusy) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sắp ra mắt trên iOS'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final basePadding = widget.padding;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentBottom =
              math.max(basePadding.bottom, keyboardInset + 16 * s);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              basePadding.left,
              basePadding.top,
              basePadding.right,
              contentBottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - basePadding.top - contentBottom,
                ),
              ),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      children: [
                        SizedBox(height: 52 * s),
                        const _BrandBadge(),
                        SizedBox(height: 28 * s),
                        Text(
                          'Huấn luyện viên\nAI trên điện thoại',
                          textAlign: TextAlign.center,
                          style: VFTheme.textStyle(
                            context,
                            size: 28,
                            weight: FontWeight.w700,
                            color: VFTheme.text,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        Text(
                          'Tập đúng form. Không cần PT.\nKhông cần mật khẩu.',
                          textAlign: TextAlign.center,
                          style: VFTheme.textStyle(
                            context,
                            size: 14,
                            weight: FontWeight.w500,
                            color: VFTheme.textMuted,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 36 * s),
                        _AuthButton(
                          label: 'Tiếp tục với Google',
                          icon: const _GoogleMark(),
                          enabled: !_isBusy,
                          isLoading: _activeAction == _LoginAction.google,
                          onTap: _handleGoogleSignIn,
                        ),
                        SizedBox(height: 10 * s),
                        _AuthButton(
                          label: 'Tiếp tục với Facebook',
                          icon: const _FacebookMark(),
                          enabled: !_isBusy,
                          isLoading: _activeAction == _LoginAction.facebook,
                          onTap: _handleFacebookSignIn,
                        ),
                        SizedBox(height: 10 * s),
                        _AuthButton(
                          label: 'Tiếp tục với Apple',
                          icon: Icon(
                            Icons.apple_rounded,
                            color: VFTheme.text,
                            size: 18 * s,
                          ),
                          enabled: !_isBusy,
                          onTap: _showAppleComingSoon,
                        ),
                        SizedBox(height: 22 * s),
                        const _SectionDivider(),
                        SizedBox(height: 22 * s),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: _showEmail
                              ? _ExpandedEmailSection(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  isEnabled: _hasValidEmail && !_isBusy,
                                  isLoading:
                                      _activeAction == _LoginAction.email,
                                  onChanged: (_) => setState(() {}),
                                  onSubmit: _handleMagicLink,
                                )
                              : _EmailButton(
                                  enabled: !_isBusy,
                                  onTap: _expandEmail,
                                ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: EdgeInsets.only(top: 28 * s, bottom: 28 * s),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: VFTheme.textStyle(
                                context,
                                size: 10.5,
                                weight: FontWeight.w500,
                                color: VFTheme.textMuted,
                                height: 1.5,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Bằng việc tiếp tục, bạn đồng ý với ',
                                ),
                                TextSpan(
                                  text: 'Điều khoản',
                                  style: TextStyle(
                                    color: VFTheme.jade,
                                  ),
                                ),
                                TextSpan(
                                  text: ' và ',
                                ),
                                TextSpan(
                                  text: 'Chính sách bảo mật',
                                  style: TextStyle(
                                    color: VFTheme.jade,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.fromLTRB(8 * s, 6 * s, 12 * s, 6 * s),
      decoration: BoxDecoration(
        color: VFTheme.jadeMist,
        borderRadius: BorderRadius.circular(20 * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20 * s,
            height: 20 * s,
            decoration: BoxDecoration(
              color: VFTheme.jade,
              borderRadius: BorderRadius.circular(6 * s),
            ),
            alignment: Alignment.center,
            child: Text(
              'V',
              style: VFTheme.textStyle(
                context,
                size: 10,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 6 * s),
          Text(
            'VIKA',
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w700,
              color: VFTheme.jade,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14 * s),
          child: Ink(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 16 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14 * s),
              border: Border.all(
                color: const Color(0xFFECE7DE),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18 * s,
                    height: 18 * s,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        VFTheme.jade,
                      ),
                    ),
                  )
                else
                  icon,
                SizedBox(width: 10 * s),
                Text(
                  label,
                  style: VFTheme.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: VFTheme.text,
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

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFECE7DE),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'HOẶC',
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w500,
              color: VFTheme.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFECE7DE),
          ),
        ),
      ],
    );
  }
}

class _EmailButton extends StatelessWidget {
  const _EmailButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14 * s),
          child: Ink(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 16 * s),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14 * s),
              border: Border.all(
                color: const Color(0xFFECE7DE),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  color: VFTheme.textMuted,
                  size: 16 * s,
                ),
                SizedBox(width: 8 * s),
                Text(
                  'Đăng nhập bằng email',
                  style: VFTheme.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: VFTheme.textSecondary,
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

class _ExpandedEmailSection extends StatelessWidget {
  const _ExpandedEmailSection({
    required this.controller,
    required this.focusNode,
    required this.isEnabled,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnabled;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                autocorrect: false,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
                style: VFTheme.textStyle(
                  context,
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: VFTheme.text,
                ),
                decoration: InputDecoration(
                  hintText: 'email@example.com',
                  hintStyle: VFTheme.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: VFTheme.textMuted,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14 * s,
                    vertical: 12 * s,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12 * s),
                    borderSide: const BorderSide(
                      color: Color(0xFFECE7DE),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12 * s),
                    borderSide: const BorderSide(
                      color: Color(0xFFECE7DE),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12 * s),
                    borderSide: const BorderSide(
                      color: Color(0xFFECE7DE),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * s),
            _SendButton(
              enabled: isEnabled,
              isLoading: isLoading,
              onTap: isEnabled ? onSubmit : null,
            ),
          ],
        ),
        SizedBox(height: 8 * s),
        Padding(
          padding: EdgeInsets.only(left: 2 * s),
          child: Text(
            'Không cần mật khẩu. Nhận link đăng nhập qua email.',
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w500,
              color: VFTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12 * s),
        child: Ink(
          width: 48 * s,
          height: 48 * s,
          decoration: BoxDecoration(
            color: enabled ? VFTheme.jade : const Color(0xFFECE7DE),
            borderRadius: BorderRadius.circular(12 * s),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18 * s,
                    height: 18 * s,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18 * s,
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _GoogleMarkPainter(),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    Path pathFor(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path;
    }

    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      pathFor([
        Offset(size.width * 0.54, size.height * 0.48),
        Offset(size.width * 0.94, size.height * 0.48),
        Offset(size.width * 0.90, size.height * 0.62),
        Offset(size.width * 0.54, size.height * 0.62),
      ]),
      paint,
    );

    final stroke = size.width * 0.18;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    void drawArc(Color color, double startAngle, double sweepAngle) {
      final arcPaint = Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }

    drawArc(const Color(0xFFEA4335), 1.05 * math.pi, 0.70 * math.pi);
    drawArc(const Color(0xFFFBBC05), 0.62 * math.pi, 0.48 * math.pi);
    drawArc(const Color(0xFF34A853), 0.05 * math.pi, 0.60 * math.pi);
    drawArc(const Color(0xFF4285F4), -0.45 * math.pi, 0.74 * math.pi);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FacebookMark extends StatelessWidget {
  const _FacebookMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Transform.translate(
        offset: const Offset(0, 1),
        child: const Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
