import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorage {
  Future<String?> get accessToken;
  Future<String?> get refreshToken;
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? s])
      : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  @override
  Future<String?> get accessToken => _s.read(key: 'access_token');
  @override
  Future<String?> get refreshToken => _s.read(key: 'refresh_token');
  @override
  Future<void> save(String access, String refresh) async {
    await _s.write(key: 'access_token', value: access);
    await _s.write(key: 'refresh_token', value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: 'access_token');
    await _s.delete(key: 'refresh_token');
  }
}
