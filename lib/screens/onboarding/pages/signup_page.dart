import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../vf_theme.dart';

class SignupPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SignupPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  String _method = 'email';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data.displayName ?? '');
    _emailCtrl = TextEditingController(text: widget.data.email ?? '');
  }

  bool get _validEmailFlow =>
      _nameCtrl.text.trim().length >= 2 &&
      _emailCtrl.text.contains('@') &&
      _emailCtrl.text.contains('.');

  bool get _canContinue => _method == 'email' ? _validEmailFlow : true;

  void _submit() {
    if (!_canContinue) return;
    widget.data.displayName =
        _method == 'email' ? _nameCtrl.text.trim() : widget.data.displayName;
    widget.data.email =
        _method == 'email' ? _emailCtrl.text.trim() : widget.data.email;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          VFProgressBar(current: 5, total: 7, onBack: widget.onBack),
          Expanded(
            child: VFFitViewport(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lưu tiến trình của bạn',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: VF.text,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Giữ phần này tối giản: card text-only, không icon màu, không game hóa.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: VF.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...[
                    ('email', 'Tiếp tục với Email'),
                    ('google', 'Tiếp tục với Google'),
                    ('apple', 'Tiếp tục với Apple'),
                  ].map((option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MethodCard(
                          label: option.$2,
                          selected: _method == option.$1,
                          onTap: () => setState(() => _method = option.$1),
                        ),
                      )),
                  const SizedBox(height: 12),
                  if (_method == 'email')
                    VFPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chi tiết tài khoản',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: VF.text,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _label('TÊN'),
                          const SizedBox(height: 6),
                          _input(_nameCtrl, 'Ví dụ: Minh'),
                          const SizedBox(height: 14),
                          _label('EMAIL'),
                          const SizedBox(height: 6),
                          _input(
                            _emailCtrl,
                            'email@example.com',
                            type: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    )
                  else
                    VFPanel(
                      child: Text(
                        'Auth cho $_method sẽ nối sau. Luồng onboarding vẫn tiếp tục để hoàn thiện lịch tập và chương trình.',
                        style: const TextStyle(
                          fontSize: 12.8,
                          color: VF.textSec,
                          height: 1.55,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: VFButton(
              label: 'Tiếp tục',
              onTap: _canContinue ? _submit : null,
              enabled: _canContinue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: VF.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    TextInputType? type,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15, color: VF.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: VF.textMuted),
        filled: true,
        fillColor: VF.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VF.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VF.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: VF.accent.withValues(alpha: 0.65),
            width: 1.5,
          ),
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

class _MethodCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? VF.accentSoft : VF.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? VF.accent.withValues(alpha: 0.28) : VF.border,
            width: 1.5,
          ),
          boxShadow: selected ? VF.cardShadow : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? VF.accent : VF.text,
                ),
              ),
            ),
            VFCheckIcon(size: 14, filled: selected),
          ],
        ),
      ),
    );
  }
}
