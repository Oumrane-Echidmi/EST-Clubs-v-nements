import 'package:dio/dio.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/token_storage.dart';

class AuthUser {
  AuthUser(
      {required this.id,
      required this.email,
      required this.role,
      this.fullName});
  final String id;
  final String email;
  final String role; // STUDENT | CLUB_ADMIN | SUPER_ADMIN
  final String? fullName;
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: '${j['id']}',
        email: '${j['email']}',
        role: '${j['role']}',
        fullName: j['fullName'] as String? ?? j['name'] as String?,
      );
}

class AuthRepository {
  AuthRepository(this._dio, this._tokens);
  final Dio _dio;
  final TokenStorage _tokens;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  // NOTE: field names follow docs/openapi.json once the backend publishes it;
  // adjust here only (see docs/TASKS.md).
  Future<AuthUser> login(String email, String password) => _guard(() async {
        final r = await _dio
            .post('/auth/login', data: {'email': email, 'password': password});
        final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
        await _tokens.save(d['accessToken'], d['refreshToken']);
        return AuthUser.fromJson(d['user'] as Map<String, dynamic>);
      });

  /// Public sign-up. The backend always creates a STUDENT account.
  Future<void> register(String fullName, String email, String password) =>
      _guard(() async {
        await _dio.post('/auth/register',
            data: {'fullName': fullName, 'email': email, 'password': password});
      });

  /// Always succeeds from the user's point of view (backend avoids revealing
  /// whether the email exists).
  Future<void> forgotPassword(String email) => _guard(() async {
        await _dio.post('/auth/forgot-password', data: {'email': email});
      });

  Future<void> resetPassword(String token, String newPassword) =>
      _guard(() async {
        await _dio.post('/auth/reset-password',
            data: {'token': token, 'newPassword': newPassword});
      });

  Future<AuthUser?> restore() async {
    if (await _tokens.accessToken == null) return null;
    try {
      final r = await _dio.get('/auth/me');
      return AuthUser.fromJson(
          ((r.data['data'] ?? r.data) as Map).cast<String, dynamic>());
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    final rt = await _tokens.refreshToken;
    try {
      if (rt != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': rt});
      }
    } catch (_) {}
    await _tokens.clear();
  }
}
