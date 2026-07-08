// SetPasswordSheet — Premium Ivory bottom sheet for adding or changing the
// account's email + password. For a Google/Apple account this ATTACHES a
// password to the same account (so email login works afterwards); for an email
// account it changes the existing one. Pops `true` once the password is saved.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'edit_sheet_chrome.dart';

class SetPasswordSheet extends StatefulWidget {
  const SetPasswordSheet({super.key, required this.onSave});

  /// Persists the new password. Returns null on success, or a user-facing error
  /// message to show inline (the sheet stays open so the user can retry).
  final Future<String?> Function(String password) onSave;

  @override
  State<SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<SetPasswordSheet> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscured = true;
  bool _saving = false;
  String? _error;

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

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_passwordController.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Only surface the mismatch hint once the user has typed a confirmation.
    final mismatch = _confirmController.text.isNotEmpty &&
        _passwordController.text != _confirmController.text;
    return ProfileEditSheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProfileSheetHeader(
            icon: Icons.lock_outline_rounded,
            eyebrow: 'BẢO MẬT',
            title: 'Đặt mật khẩu',
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo mật khẩu để đăng nhập bằng email — dùng chung tài khoản với '
            'Google/Apple bạn đang dùng.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 18),
          _PasswordField(
            controller: _passwordController,
            label: 'MẬT KHẨU MỚI',
            hint: 'Tối thiểu $_minLength ký tự',
            obscured: _obscured,
            onToggleObscure: () => setState(() => _obscured = !_obscured),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: _confirmController,
            label: 'NHẬP LẠI MẬT KHẨU',
            hint: 'Gõ lại mật khẩu',
            obscured: _obscured,
            onToggleObscure: () => setState(() => _obscured = !_obscured),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          if (mismatch || _error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 15, color: c.attention),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ?? 'Mật khẩu nhập lại chưa khớp.',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.attention,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ProfileSheetSaveButton(
            label: 'Lưu mật khẩu',
            saving: _saving,
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscured,
    required this.onToggleObscure,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscured;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.bgRaised,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: c.inkFaint,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscured,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: onSubmitted == null
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  cursorColor: c.yellow,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.inkFaint,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleObscure,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(
                    obscured
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: c.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
