import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../vf_theme.dart';

class SignupPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  const SignupPage({super.key, required this.data, required this.onNext});

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

  bool get _valid =>
      _nameCtrl.text.trim().length >= 2 &&
      _emailCtrl.text.contains('@') &&
      _emailCtrl.text.contains('.');

  void _submit() {
    if (!_valid) return;
    widget.data.displayName = _nameCtrl.text.trim();
    widget.data.email = _emailCtrl.text.trim();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tạo tài khoản',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: VF.text,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('Lưu kết quả và theo dõi tiến trình',
                style: TextStyle(color: VF.textMuted, fontSize: 13)),
            const SizedBox(height: 28),

            _label('TÊN'),
            const SizedBox(height: 6),
            _input(_nameCtrl, 'Ví dụ: Minh'),
            const SizedBox(height: 18),

            _label('EMAIL'),
            const SizedBox(height: 6),
            _input(_emailCtrl, 'email@example.com',
                type: TextInputType.emailAddress),
            const SizedBox(height: 20),

            // Divider
            Row(children: [
              const Expanded(child: Divider(color: VF.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('hoặc',
                    style: TextStyle(fontSize: 11, color: VF.textMuted)),
              ),
              const Expanded(child: Divider(color: VF.border)),
            ]),
            const SizedBox(height: 16),

            // Social
            Row(children: [
              _socialBtn('Google'),
              const SizedBox(width: 10),
              _socialBtn('Zalo'),
            ]),

            const Spacer(),
            VFButton(
                label: 'Tiếp tục',
                onTap: _valid ? _submit : null,
                enabled: _valid),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: VF.textMuted,
          letterSpacing: 0.8));

  Widget _input(TextEditingController ctrl, String hint,
      {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15, color: VF.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: VF.textMuted),
        filled: true,
        fillColor: VF.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: VF.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: VF.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: VF.brand, width: 1.5)),
      ),
    );
  }

  Widget _socialBtn(String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // TODO: Social login integration (Phase 2)
        },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: VF.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VF.border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: VF.textSec)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }
}
