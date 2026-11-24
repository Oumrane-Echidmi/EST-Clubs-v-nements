import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

Dio buildDio(TokenStorage tokens, {void Function()? onSessionExpired}) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  dio.interceptors
      .add(AuthInterceptor(dio, tokens, onSessionExpired: onSessionExpired));
  return dio;
}
