import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_config.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _magicLinkRedirectUrl =
      'com.vikavn.app://login-callback/';
  static const String _googleWebClientId = googleWebClientId;

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
    try {
      if (_googleWebClientId.startsWith('YOUR_WEB_CLIENT_ID')) {
        throw Exception(
          'Thiếu Google Web Client ID. Hãy cấu hình VIKA_GOOGLE_WEB_CLIENT_ID.',
        );
      }

      final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Bạn đã hủy đăng nhập Google.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Không nhận được ID token từ Google.');
      }

      if (accessToken == null) {
        throw Exception('Không nhận được access token từ Google.');
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on AuthException catch (error) {
      throw Exception(
        _translateAuthException(
          error,
          fallback:
              'Không thể đăng nhập bằng Google lúc này. Vui lòng thử lại.',
        ),
      );
    } catch (error) {
      throw Exception(
        _translateGenericException(
          error,
          fallback:
              'Không thể đăng nhập bằng Google lúc này. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<AuthResponse> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();

      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken?.tokenString;
          if (accessToken == null || accessToken.isEmpty) {
            throw Exception('Không nhận được access token từ Facebook.');
          }

          return await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.facebook,
            idToken: accessToken,
          );
        case LoginStatus.cancelled:
          throw Exception('Bạn đã hủy đăng nhập Facebook.');
        case LoginStatus.failed:
          throw Exception(
            'Đăng nhập Facebook thất bại. Vui lòng thử lại sau ít phút.',
          );
        case LoginStatus.operationInProgress:
          throw Exception('Đăng nhập Facebook đang được xử lý. Hãy thử lại.');
      }
    } on AuthException catch (error) {
      throw Exception(
        _translateAuthException(
          error,
          fallback:
              'Không thể đăng nhập bằng Facebook lúc này. Vui lòng thử lại.',
        ),
      );
    } catch (error) {
      throw Exception(
        _translateGenericException(
          error,
          fallback:
              'Không thể đăng nhập bằng Facebook lúc này. Vui lòng thử lại.',
        ),
      );
    }
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
