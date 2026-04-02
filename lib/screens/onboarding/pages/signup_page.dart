import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data.displayName ?? '');
    _emailCtrl = TextEditingController(text: widget.data.email ?? '');
  }

  bool get _canSubmit {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    return name.length >= 2 && email.contains('@') && email.contains('.');
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.data.displayName = _nameCtrl.text.trim();
    widget.data.email = _emailCtrl.text.trim();
    widget.onNext();
  }

  void _continueSocial() {
    widget.onNext();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ColoredBox(
        color: VF.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VFOnboardingNavBar(
              current: 8,
              total: 10,
              onBack: widget.onBack,
            ),
            Expanded(
              child: keyboardOpen
                  ? SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24 * s, 20 * s, 24 * s, 0),
                      child: _SignupBody(
                        nameCtrl: _nameCtrl,
                        emailCtrl: _emailCtrl,
                        canSubmit: _canSubmit,
                        onNameChanged: (_) => setState(() {}),
                        onEmailChanged: (_) => setState(() {}),
                        onContinueSocial: _continueSocial,
                        onSubmit: _submit,
                        onSkip: widget.onNext,
                      ),
                    )
                  : VFFitViewport(
                      padding: EdgeInsets.fromLTRB(24 * s, 20 * s, 24 * s, 0),
                      child: _SignupBody(
                        nameCtrl: _nameCtrl,
                        emailCtrl: _emailCtrl,
                        canSubmit: _canSubmit,
                        onNameChanged: (_) => setState(() {}),
                        onEmailChanged: (_) => setState(() {}),
                        onContinueSocial: _continueSocial,
                        onSubmit: _submit,
                        onSkip: widget.onNext,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupBody extends StatelessWidget {
  const _SignupBody({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.canSubmit,
    required this.onNameChanged,
    required this.onEmailChanged,
    required this.onContinueSocial,
    required this.onSubmit,
    required this.onSkip,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final bool canSubmit;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onContinueSocial;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lưu tiến trình',
                style: VF.textStyle(
                  context,
                  size: 28,
                  weight: FontWeight.w900,
                  color: VF.text,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                'Tạo tài khoản để giữ chương trình và theo dõi tiến bộ',
                style: VF.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w500,
                  color: VF.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * s),
        _SocialButton.google(
          label: 'Tiếp tục với Google',
          onTap: onContinueSocial,
        ),
        SizedBox(height: 10 * s),
        _SocialButton.apple(
          label: 'Tiếp tục với Apple',
          onTap: onContinueSocial,
        ),
        SizedBox(height: 16 * s),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: VF.textMuted.withValues(alpha: 0.15),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              child: Text(
                'hoặc',
                style: VF.textStyle(
                  context,
                  size: 11,
                  weight: FontWeight.w600,
                  color: VF.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: VF.textMuted.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
        SizedBox(height: 16 * s),
        _LabeledField(
          label: 'TÊN',
          controller: nameCtrl,
          hintText: 'Tên hiển thị...',
          onChanged: onNameChanged,
        ),
        SizedBox(height: 10 * s),
        _LabeledField(
          label: 'EMAIL',
          controller: emailCtrl,
          hintText: 'email@example.com',
          keyboardType: TextInputType.emailAddress,
          onChanged: onEmailChanged,
        ),
        SizedBox(height: 16 * s),
        VFOnboardingButton(
          label: 'Đăng ký',
          onTap: canSubmit ? onSubmit : null,
          padding: EdgeInsets.zero,
        ),
        SizedBox(height: 20 * s),
        Center(
          child: GestureDetector(
            onTap: onSkip,
            child: Text(
              'Bỏ qua, tôi sẽ đăng ký sau',
              style: VF.textStyle(
                context,
                size: 13,
                weight: FontWeight.w600,
                color: VF.textMuted,
              ).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: VF.textMuted.withValues(alpha: 0.30),
                decorationThickness: 1.2 * s,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton._({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
    required this.leadingBuilder,
  });

  factory _SocialButton.google({
    required String label,
    required VoidCallback onTap,
  }) {
    return _SocialButton._(
      label: label,
      background: Colors.white,
      foreground: VF.text,
      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      onTap: onTap,
      leadingBuilder: (s) => VFGoogleMark(size: 20 * s),
    );
  }

  factory _SocialButton.apple({
    required String label,
    required VoidCallback onTap,
  }) {
    return _SocialButton._(
      label: label,
      background: Colors.black,
      foreground: Colors.white,
      onTap: onTap,
      leadingBuilder: (s) => VFAppleMark(size: 18 * s),
    );
  }

  final String label;
  final Color background;
  final Color foreground;
  final Border? border;
  final Widget Function(double s) leadingBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56 * s,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16 * s),
          border: border,
          boxShadow: background == Colors.white
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8 * s,
                    offset: Offset(0, 4 * s),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leadingBuilder(s),
            SizedBox(width: 12 * s),
            Text(
              label,
              style: VF.textStyle(
                context,
                size: 15,
                weight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VF.textStyle(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: VF.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: VF.textStyle(
              context,
              size: 15,
              weight: FontWeight.w600,
              color: VF.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: VF.textStyle(
                context,
                size: 15,
                weight: FontWeight.w500,
                color: VF.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
