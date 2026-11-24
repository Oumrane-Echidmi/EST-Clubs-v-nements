import 'package:dio/dio.dart';
import '../errors/app_exception.dart';

/// One page of a backend list: `{ data: [...], meta: { page, totalPages } }`.
class Paged<T> {
  Paged(this.items, this.page, this.totalPages);
  final List<T> items;
  final int page;
  final int totalPages;
  bool get hasMore => page < totalPages;
}

/// Calls a list endpoint and converts errors to [AppException].
Future<Paged<T>> fetchPaged<T>(
  Dio dio,
  String path,
  T Function(Map<String, dynamic>) fromJson, {
  int page = 1,
  int limit = 20,
  Map<String, dynamic>? query,
}) async {
  try {
    final r = await dio.get(path,
        queryParameters: {'page': page, 'limit': limit, ...?query});
    final list = (r.data['data'] as List).cast<Map<String, dynamic>>();
    final meta = (r.data['meta'] ?? {}) as Map;
    return Paged(list.map(fromJson).toList(), (meta['page'] ?? page) as int,
        (meta['totalPages'] ?? 1) as int);
  } on DioException catch (e) {
    throw AppException.fromDio(e);
  }
}

/// Runs any Dio call and converts errors to [AppException].
Future<T> guarded<T>(Future<T> Function() f) async {
  try {
    return await f();
  } on DioException catch (e) {
    throw AppException.fromDio(e);
  }
}
