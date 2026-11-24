import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/core/errors/app_exception.dart';
import 'package:est_clubs_events/core/network/auth_interceptor.dart';
import 'package:est_clubs_events/core/router/app_router.dart';
import 'package:est_clubs_events/core/storage/token_storage.dart';
import 'package:est_clubs_events/features/auth/presentation/login_screen.dart';

class MemTokens implements TokenStorage {
  String? a = 'old', r = 'rt';
  @override
  Future<String?> get accessToken async => a;
  @override
  Future<String?> get refreshToken async => r;
  @override
  Future<void> save(String x, String y) async {
    a = x;
    r = y;
  }

  @override
  Future<void> clear() async {
    a = null;
    r = null;
  }
}

/// /data returns 401 unless bearer is "new"; /auth/refresh is counted.
class FakeAdapter implements HttpClientAdapter {
  int refreshCalls = 0;
  bool refreshOk = true;
  @override
  Future<ResponseBody> fetch(RequestOptions o,
      Stream<Uint8List>? s, Future<void>? c) async {
    ResponseBody json(String b, int code) => ResponseBody.fromString(b, code,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
    if (o.path.contains('/auth/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return refreshOk
          ? json('{"data":{"accessToken":"new","refreshToken":"rt2"}}', 200)
          : json('{"error":{"code":"UNAUTHORIZED","message":"x"}}', 401);
    }
    return o.headers['Authorization'] == 'Bearer new'
        ? json('{"data":1}', 200)
        : json('{"error":{"code":"UNAUTHORIZED","message":"x"}}', 401);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('validators', () {
    expect(validateEmail('a@b.co'), isNull);
    expect(validateEmail('nope'), isNotNull);
    expect(validatePassword('abcdefg1'), isNull);
    expect(validatePassword('abcdefgh'), isNotNull);
    expect(validatePassword('a1'), isNotNull);
  });

  test('role-based redirects', () {
    expect(redirectFor(loading: false, role: null, location: '/student'),
        '/login');
    expect(redirectFor(loading: false, role: null, location: '/register'), isNull);
    expect(redirectFor(loading: false, role: null, location: '/forgot-password'), isNull);
    expect(redirectFor(loading: false, role: 'STUDENT', location: '/login'),
        '/student');
    expect(
        redirectFor(loading: false, role: 'STUDENT', location: '/club-admin'),
        '/student');
    expect(
        redirectFor(
            loading: false, role: 'CLUB_ADMIN', location: '/super-admin'),
        '/club-admin');
    expect(
        redirectFor(
            loading: false, role: 'SUPER_ADMIN', location: '/super-admin'),
        isNull);
  });

  test('error mapping', () {
    final ro = RequestOptions();
    final e = AppException.fromDio(DioException(
        requestOptions: ro,
        response: Response(requestOptions: ro, statusCode: 409, data: {
          'error': {'code': 'EVENT_FULL', 'message': 'x'}
        })));
    expect(e.code, 'EVENT_FULL');
    expect(AppException.fromDio(DioException(requestOptions: ro)).code,
        'NETWORK_ERROR');
  });

  test('concurrent 401s trigger a single refresh and succeed', () async {
    final t = MemTokens();
    final ad = FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://x/api'))
      ..httpClientAdapter = ad;
    dio.interceptors.add(AuthInterceptor(dio, t));
    final rs = await Future.wait(List.generate(5, (_) => dio.get('/data')));
    expect(rs.every((r) => r.statusCode == 200), isTrue);
    expect(ad.refreshCalls, 1);
  });

  test('refresh failure clears tokens and signals logout', () async {
    final t = MemTokens();
    final ad = FakeAdapter()..refreshOk = false;
    var expired = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://x/api'))
      ..httpClientAdapter = ad;
    dio.interceptors
        .add(AuthInterceptor(dio, t, onSessionExpired: () => expired = true));
    await expectLater(dio.get('/data'), throwsA(isA<DioException>()));
    expect(await t.accessToken, isNull);
    expect(expired, isTrue);
  });
}
