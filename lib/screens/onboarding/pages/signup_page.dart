import 'package:flutter/material.dart';
import '../onboarding_data.dart';

const _cyan = Color(0xFF00E5FF);
const _blue = Color(0xFF0091EA);
const _cardBg = Color(0xFF0D1228);

class SignupPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const SignupPage({super.key, required this.data, required this.onNext});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _nameValid = false;
  bool _emailValid = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if coming back
    if (widget.data.displayName != null) {
      _nameController.text = widget.data.displayName!;
      _nameValid = true;
    }
    if (widget.data.email != null) {
      _emailController.text = widget.data.email!;
      _emailValid = true;
    }
  }

  bool get _canProceed => _nameValid && _emailValid;

  void _validateName(String v) {
    setState(() => _nameValid = v.trim().length >= 2);
  }

  void _validateEmail(String v) {
    setState(() => _emailValid =
        v.contains('@') && v.contains('.') && v.trim().length >= 5);
  }

  void _submit() {
    if (!_canProceed) return;
    widget.data.displayName = _nameController.text.trim();
    widget.data.email = _emailController.text.trim();
    widget.onNext();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            const Text(
              'Tạo tài khoản',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lưu kết quả và theo dõi tiến trình của bạn',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // ── Name field ──
            Text(
              'TÊN CỦA BẠN',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: 'Ví dụ: Minh',
              icon: Icons.person_outline,
              onChanged: _validateName,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),

            // ── Email field ──
            Text(
              'EMAIL',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hint: 'email@example.com',
              icon: Icons.email_outlined,
              onChanged: _validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),

            // ── Social login divider ──
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'hoặc',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Google / Zalo buttons ──
            Row(
              children: [
                Expanded(
                  child: _socialButton('Google', Icons.g_mobiledata),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _socialButton('Zalo', Icons.chat_bubble_outline),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── CTA ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _canProceed
                      ? const LinearGradient(colors: [_cyan, _blue])
                      : null,
                  color: _canProceed
                      ? null
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _canProceed
                      ? [
                          BoxShadow(
                            color: _cyan.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _canProceed ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'TIẾP TỤC',
                    style: TextStyle(
                      color: _canProceed
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.15),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.2),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _socialButton(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement social login
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
