import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../onboarding/v5/v5_primitives.dart';
import '../onboarding/v5/v5_theme.dart';
import 'auth_v5_widgets.dart';

/// Shown when the app opens from a password-reset email link. At this point the
/// Supabase SDK has established a temporary `passwordRecovery` session, so the
/// user just needs to choose a new password — [AuthService.setPassword] writes
/// it to that same account. [onCompleted] hands control back to the entry gate,
/// which routes on into the app now that the session is a full one.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _busy = false;
  String? _notice;

  static const int _minLength = 8;

  bool get _valid {
    final password = _passwordController.text;
    return password.length >= _minLength && password == _confirmController.text;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await _authService.setPassword(_passwordController.text);
      if (!mounted) return;
      widget.onCompleted();
    } catch (error) {
      _showError(error
          .toString()
          .replaceFirst('Exception: ', '')
          .trim());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Abandon the reset: sign out of the recovery session; the entry gate reacts
  // to the resulting `signedOut` and returns to the login screen.
  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _authService.signOut();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final compact = r.isShort;
    final mismatch = _confirmController.text.isNotEmpty &&
        _passwordController.text != _confirmController.text;

    return V5KeyboardForm(
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
      footer: AnimatedBuilder(
        animation: Listenable.merge([_passwordController, _confirmController]),
        builder: (context, _) => _ResetCta(
          label: _busy ? 'Đang lưu…' : 'Cập nhật mật khẩu',
          disabledLabel: 'Nhập mật khẩu mới',
          enabled: _valid && !_busy,
          onTap: _submit,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: V5.space16),
              V5ScreenHeader(
                eyebrow: 'Đặt lại mật khẩu',
                title: 'Chọn mật khẩu\nmới.',
                size: compact ? V5HeaderSize.medium : V5HeaderSize.large,
              ),
              SizedBox(height: r.pick(cozy: V5.space24, short: V5.space16)),
              AuthPasswordField(
                controller: _passwordController,
                onChanged: (_) {
                  if (_notice != null) setState(() => _notice = null);
                },
                label: 'MẬT KHẨU MỚI',
                hintText: 'Tối thiểu $_minLength ký tự',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: V5.space10),
              AuthPasswordField(
                controller: _confirmController,
                onChanged: (_) {
                  if (_notice != null) setState(() => _notice = null);
                },
                label: 'NHẬP LẠI MẬT KHẨU',
                hintText: 'Gõ lại mật khẩu',
                onSubmitted: (_) {
                  if (_valid) _submit();
                },
              ),
              if (mismatch) ...[
                const SizedBox(height: V5.space10),
                Text(
                  'Mật khẩu nhập lại chưa khớp.',
                  style: V5.bodySm(context, color: V5.yellowDeep),
                ),
              ],
              const SizedBox(height: V5.space16),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : _cancel,
                  child: Text(
                    'Huỷ',
                    style: V5.bodySm(context, color: V5.inkSoft),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline submit pill — mirrors the login screen's CTA (ink pill, yellow arrow
/// disc; disabled = outlined ghost) so the auth surfaces stay one family.
class _ResetCta extends StatefulWidget {
  const _ResetCta({
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
  State<_ResetCta> createState() => _ResetCtaState();
}

class _ResetCtaState extends State<_ResetCta> {
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
