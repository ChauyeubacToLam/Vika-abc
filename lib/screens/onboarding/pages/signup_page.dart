import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/login_screen.dart';
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
  StreamSubscription<AuthState>? _authSubscription;
  bool _didAdvance = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _advanceIfAuthenticated(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _advanceIfAuthenticated();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _advanceIfAuthenticated() {
    if (!mounted || _didAdvance) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    widget.data.email ??= user.email;
    widget.data.displayName ??=
        _readMetadataString(user.userMetadata, 'full_name') ??
            _readMetadataString(user.userMetadata, 'name');

    _didAdvance = true;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final user = Supabase.instance.client.auth.currentUser;

    return ColoredBox(
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
            child: user == null
                ? VikaLoginPanel(
                    onAuthenticated: _advanceIfAuthenticated,
                    padding: EdgeInsets.fromLTRB(20 * s, 0, 20 * s, 0),
                  )
                : Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * s),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28 * s,
                            height: 28 * s,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                VF.accent,
                              ),
                              backgroundColor:
                                  VF.accent.withValues(alpha: 0.14),
                            ),
                          ),
                          SizedBox(height: 18 * s),
                          Text(
                            'Đã kết nối tài khoản',
                            textAlign: TextAlign.center,
                            style: VF.textStyle(
                              context,
                              size: 24,
                              weight: FontWeight.w800,
                              color: VF.text,
                              letterSpacing: -1.1,
                            ),
                          ),
                          SizedBox(height: 8 * s),
                          Text(
                            'Vika đang chuyển bạn sang bước tiếp theo.',
                            textAlign: TextAlign.center,
                            style: VF.textStyle(
                              context,
                              size: 13,
                              weight: FontWeight.w500,
                              color: VF.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String? _readMetadataString(Map<String, dynamic>? data, String key) {
  final value = data?[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}
