import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_config.dart';

class AuthFlowCancelledException implements Exception {
  const AuthFlowCancelledException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _magicLinkRedirectUrl =
      'com.vikavn.app://login-callback';

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<void> signInWithMagicLink(String email) async {
    try {
      await _clearInteractiveAuthState();

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
      await _clearInteractiveAuthState();

      if (googleWebClientId.startsWith('YOUR_WEB_CLIENT_ID')) {
        throw Exception(
          'Thiếu Google Web Client ID. Hãy cấu hình VIKA_GOOGLE_WEB_CLIENT_ID.',
        );
      }

      final googleSignIn = GoogleSignIn(serverClientId: googleWebClientId);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw const AuthFlowCancelledException('Bạn đã hủy đăng nhập Google.');
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
    } on AuthFlowCancelledException {
      rethrow;
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
      await _clearInteractiveAuthState();

      final result = await FacebookAuth.instance.login(
        permissions: const ['public_profile', 'email'],
        loginTracking: LoginTracking.enabled,
      );

      switch (result.status) {
        case LoginStatus.success:
          final token = result.accessToken;
          if (token == null) {
            throw Exception('Không nhận được token từ Facebook.');
          }

          return await _signInToSupabaseWithFacebookToken(token);
        case LoginStatus.cancelled:
          throw const AuthFlowCancelledException(
            'Bạn đã hủy đăng nhập Facebook.',
          );
        case LoginStatus.failed:
          throw Exception(_facebookFailureMessage(result.message));
        case LoginStatus.operationInProgress:
          throw Exception('Đăng nhập Facebook đang được xử lý. Hãy thử lại.');
      }
    } on AuthFlowCancelledException {
      rethrow;
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

  Future<AuthResponse> signInWithApple() async {
    try {
      await _clearInteractiveAuthState();

      final rawNonce = _generateRawNonce();
      final hashedNonce = _sha256OfString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Không nhận được ID token từ Apple.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      await _persistAppleFullNameIfPresent(
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

      return response;
    } on AuthFlowCancelledException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthFlowCancelledException(
          'Bạn đã hủy đăng nhập Apple.',
        );
      }

      throw Exception(
        'Không thể đăng nhập bằng Apple lúc này. Vui lòng thử lại.',
      );
    } on AuthException catch (error) {
      throw Exception(
        _translateAuthException(
          error,
          fallback: 'Không thể đăng nhập bằng Apple lúc này. Vui lòng thử lại.',
        ),
      );
    } catch (error) {
      throw Exception(
        _translateGenericException(
          error,
          fallback: 'Không thể đăng nhập bằng Apple lúc này. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<void> _persistAppleFullNameIfPresent({
    required String? givenName,
    required String? familyName,
  }) async {
    final fullName = '${givenName ?? ''} ${familyName ?? ''}'.trim();
    if (fullName.isEmpty) {
      return;
    }

    await _supabase.auth.updateUser(
      UserAttributes(data: {'full_name': fullName}),
    );
  }

  Future<void> _clearInteractiveAuthState() async {
    await _safeGoogleSignOut();
    await _safeFacebookLogOut();
    await _safeSupabaseSignOut();
  }

  Future<void> _safeSupabaseSignOut() async {
    if (_supabase.auth.currentSession == null) {
      return;
    }

    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Best effort: Supabase removes the local session before network revoke.
    }
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await GoogleSignIn(serverClientId: googleWebClientId).signOut();
    } catch (_) {
      // Best effort: stale Google SDK state should not block another provider.
    }
  }

  Future<void> _safeFacebookLogOut() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {
      // Best effort: start the next Facebook login from a clean SDK session.
    }
  }

  Future<AuthResponse> _signInToSupabaseWithFacebookToken(
    AccessToken token,
  ) async {
    final idToken = token.tokenString.trim();
    if (idToken.isEmpty) {
      throw Exception('Không nhận được token từ Facebook.');
    }

    String? nonce;
    if (token is LimitedToken) {
      nonce = token.nonce.trim();
      if (nonce.isEmpty) {
        throw Exception('Không nhận được mã xác thực từ Facebook.');
      }
    }

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.facebook,
      idToken: idToken,
      nonce: nonce,
    );
  }

  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
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

  String _facebookFailureMessage(String? providerMessage) {
    final message = providerMessage?.toLowerCase().trim() ?? '';

    if (message.contains('key hash') || message.contains('hash key')) {
      return 'Cấu hình Facebook chưa khớp key hash của bản build này.';
    }

    if (message.contains('app not setup') ||
        message.contains('development mode') ||
        message.contains('login is currently unavailable')) {
      return 'Ứng dụng Facebook chưa sẵn sàng cho tài khoản này. Hãy kiểm tra trạng thái app và quyền tester trên Facebook Developers.';
    }

    if (message.contains('network') || message.contains('socket')) {
      return 'Không thể kết nối mạng. Vui lòng kiểm tra kết nối rồi thử lại.';
    }

    return 'Đăng nhập Facebook thất bại. Vui lòng thử lại sau ít phút.';
  }

  bool _looksLocalized(String value) {
    return RegExp(
      r'[ăâđêôơưĂÂĐÊÔƠƯàáạảãèéẹẻẽìíịỉĩòóọỏõùúụủũỳýỵỷỹ]',
    ).hasMatch(value);
  }
}
