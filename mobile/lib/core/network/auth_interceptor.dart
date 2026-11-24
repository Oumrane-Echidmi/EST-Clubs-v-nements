import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

/// Adds the bearer token and performs a single-flight refresh on 401.
/// Each request is retried at most once; auth endpoints never trigger refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokens, {this.onSessionExpired});
  final Dio _dio;
  final TokenStorage _tokens;
  final void Function()? onSessionExpired;
  Future<bool>? _refreshing;

  static bool _isAuthPath(String p) => p.contains('/auth/login') ||
      p.contains('/auth/register') ||
      p.contains('/auth/refresh') ||
      p.contains('/auth/forgot-password') ||
      p.contains('/auth/reset-password');

  @override
  Future<void> onRequest(
      RequestOptions o, RequestInterceptorHandler h) async {
    final t = await _tokens.accessToken;
    if (t != null && !_isAuthPath(o.path)) {
      o.headers['Authorization'] = 'Bearer $t';
    }
    h.next(o);
  }

  @override
  Future<void> onError(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    if (e.response?.statusCode != 401 ||
        _isAuthPath(o.path) ||
        o.extra['retried'] == true) {
      return h.next(e);
    }
    _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
    final ok = await _refreshing!;
    if (!ok) {
      await _tokens.clear();
      onSessionExpired?.call();
      return h.next(e);
    }
    o.extra['retried'] = true;
    o.headers['Authorization'] = 'Bearer ${await _tokens.accessToken}';
    try {
      h.resolve(await _dio.fetch(o));
    } on DioException catch (err) {
      h.next(err);
    }
  }

  Future<bool> _refresh() async {
    final rt = await _tokens.refreshToken;
    if (rt == null) return false;
    try {
      // Same adapter, no interceptors: avoids recursion.
      final bare = Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
        ..httpClientAdapter = _dio.httpClientAdapter;
      final r = await bare.post('/auth/refresh', data: {'refreshToken': rt});
      final d = (r.data['data'] ?? r.data) as Map;
      await _tokens.save(
          d['accessToken'] as String, d['refreshToken'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }
}
