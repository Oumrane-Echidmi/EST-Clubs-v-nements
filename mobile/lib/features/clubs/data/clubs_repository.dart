import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/paged.dart';
import '../../auth/presentation/auth_providers.dart';

class Club {
  Club({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.category,
    this.isFollowing = false,
    this.memberCount,
    this.tags = const [],
    this.status = 'APPROVED',
  });

  /// PENDING | APPROVED | REJECTED (moderation state).
  final String status;

  /// memberCount comes from `_count.members`; the API has no tags field.
  final int? memberCount;
  final List<String> tags;
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? category;
  final bool isFollowing;

  factory Club.fromJson(Map<String, dynamic> j) => Club(
        id: '${j['id']}',
        name: '${j['name']}',
        description: j['description'] as String?,
        logoUrl: j['logoUrl'] as String?,
        category: j['category'] as String?,
        isFollowing: j['isFollowed'] as bool? ?? false,
        memberCount: (j['_count'] is Map) ? (j['_count'] as Map)['members'] as int? : null,
        tags: ((j['tags'] ?? const []) as List).map((t) => '$t').toList(),
        status: j['status'] as String? ?? 'APPROVED',
      );
}

class ClubsRepository {
  ClubsRepository(this._dio);
  final Dio _dio;

  Future<Paged<Club>> list(int page, {String? search, String? category}) =>
      fetchPaged(_dio, '/clubs', Club.fromJson, page: page, query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null) 'category': category,
      });

  Future<Club> get(String id) => guarded(() async {
        final r = await _dio.get('/clubs/$id');
        return Club.fromJson(
            ((r.data['data'] ?? r.data) as Map).cast<String, dynamic>());
      });

  Future<void> follow(String id) =>
      guarded(() => _dio.post('/clubs/$id/follow'));
  Future<void> unfollow(String id) =>
      guarded(() => _dio.delete('/clubs/$id/follow'));
}

final clubsRepositoryProvider =
    Provider((ref) => ClubsRepository(ref.watch(dioProvider)));

final clubDetailProvider = FutureProvider.autoDispose.family<Club, String>(
    (ref, id) => ref.watch(clubsRepositoryProvider).get(id));
