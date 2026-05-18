import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/vf_theme.dart';
import '../../utils/orientation_lock.dart';

class MagicLinkSentScreen extends StatefulWidget {
  const MagicLinkSentScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<MagicLinkSentScreen> createState() => _MagicLinkSentScreenState();
}

class _MagicLinkSentScreenState extends State<MagicLinkSentScreen> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _handleAuthState,
    );

    if (Supabase.instance.client.auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _popToRoot());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthState(AuthState data) {
    switch (data.event.name) {
      case 'signedIn':
      case 'initialSession':
      case 'userUpdated':
      case 'passwordRecovery':
      case 'mfaChallengeVerified':
        _popToRoot();
        break;
      case 'signedOut':
      case 'tokenRefreshed':
      case 'userDeleted':
        break;
      default:
        break;
    }
  }

  void _popToRoot() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: VFTheme.bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 24 * s, 24 * s, 28 * s),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 72 * s,
                      height: 72 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            VFTheme.jade.withValues(alpha: 0.92),
                            VFTheme.jadeDark,
                          ],
                        ),
                        boxShadow: VFTheme.jadeShadow,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.mail_outline_rounded,
                        color: Colors.white,
                        size: 28 * s,
                      ),
                    ),
                    SizedBox(height: 26 * s),
                    Text(
                      'Kiểm tra email',
                      textAlign: TextAlign.center,
                      style: VFTheme.textStyle(
                        context,
                        size: 26,
                        weight: FontWeight.w800,
                        color: VFTheme.text,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    Text(
                      'Link đăng nhập đã được gửi đến',
                      textAlign: TextAlign.center,
                      style: VFTheme.textStyle(
                        context,
                        size: 14,
                        weight: FontWeight.w500,
                        color: VFTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: VFTheme.textStyle(
                        context,
                        size: 15,
                        weight: FontWeight.w700,
                        color: VFTheme.jade,
                      ),
                    ),
                    SizedBox(height: 18 * s),
                    Text(
                      'Nhấn vào link trong email để đăng nhập. Nhớ kiểm tra hộp thư rác nhé!',
                      textAlign: TextAlign.center,
                      style: VFTheme.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w500,
                        color: VFTheme.textMuted,
                        height: 1.55,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        foregroundColor: VFTheme.jade,
                        textStyle: VFTheme.textStyle(
                          context,
                          size: 14,
                          weight: FontWeight.w700,
                          color: VFTheme.jade,
                        ),
                      ),
                      child: const Text('← Quay lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
