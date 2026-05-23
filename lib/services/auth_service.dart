// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_config.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _magicLinkRedirectUrl =
      'com.vikavn.app://login-callback/';

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<void> signInWithMagicLink(String email) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: _magicLinkRedirectUrl,
      );
    } on AuthException catch (error) {
      throw Exception(
        _translateAuthException(
          error,
          fallback: 'Không thể gửi link đăng nhập lúc này. Vui lòng thử lại.',
        ),
      );
    } catch (error) {
      throw Exception(
        _translateGenericException(
          error,
          fallback: 'Không thể gửi link đăng nhập lúc này. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    return _supabase.auth.signInAnonymously();
  }

  Future<AuthResponse> signInWithFacebook() async {
    return _supabase.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (error) {
      throw Exception(
        _translateAuthException(
          error,
          fallback: 'Không thể đăng xuất lúc này. Vui lòng thử lại.',
        ),
      );
    } catch (error) {
      throw Exception(
        _translateGenericException(
          error,
          fallback: 'Không thể đăng xuất lúc này. Vui lòng thử lại.',
        ),
      );
    }
  }

  String _translateAuthException(
    AuthException error, {
    required String fallback,
  }) {
    final message = error.message.toLowerCase();

    if (message.contains('rate') || message.contains('security purposes')) {
      return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
    }

    if (message.contains('network') || message.contains('socket')) {
      return 'Không thể kết nối mạng. Vui lòng kiểm tra kết nối rồi thử lại.';
    }

    if (message.contains('email') && message.contains('invalid')) {
      return 'Email không hợp lệ.';
    }

    if (message.contains('expired')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng thử lại.';
    }

    if (message.contains('user') && message.contains('not found')) {
      return 'Tài khoản chưa sẵn sàng. Vui lòng thử lại sau.';
    }

    return fallback;
  }

  String _translateGenericException(
    Object error, {
    required String fallback,
  }) {
    final rawMessage = error.toString().replaceFirst('Exception: ', '').trim();
    if (rawMessage.isEmpty) {
      return fallback;
    }

    final message = rawMessage.toLowerCase();
    if (message.contains('network') || message.contains('socket')) {
      return 'Không thể kết nối mạng. Vui lòng kiểm tra kết nối rồi thử lại.';
    }

    if (message.contains('cancel')) {
      return 'Bạn đã hủy thao tác.';
    }

    if (_looksLocalized(rawMessage)) {
      return rawMessage;
    }

    return fallback;
  }

  bool _looksLocalized(String value) {
    return RegExp(
      r'[ăâđêôơưĂÂĐÊÔƠƯàáạảãèéẹẻẽìíịỉĩòóọỏõùúụủũỳýỵỷỹ]',
    ).hasMatch(value);
  }
}
