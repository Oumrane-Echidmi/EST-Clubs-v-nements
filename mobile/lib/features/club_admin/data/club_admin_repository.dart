import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/paged.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clubs/data/clubs_repository.dart';
import '../../events/domain/event.dart';

/// Category label -> API enum value (shared by forms and filter chips).
const eventCategories = {
  'Technologie': 'TECHNOLOGY',
  'Sciences': 'SCIENCE',
  'Culture': 'CULTURE',
  'Sport': 'SPORTS',
  'Social': 'SOCIAL',
  'Entrepreneuriat': 'ENTREPRENEURSHIP',
};

/// API enum value -> French label (for display).
String categoryLabel(String? value) => eventCategories.entries
    .firstWhere((e) => e.value == value, orElse: () => MapEntry(value ?? '', value ?? ''))
    .key;

/// Values sent when creating / editing an event.
class EventInput {
  EventInput({
    required this.title,
    required this.description,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.registrationDeadline,
    required this.category,
    this.posterUrl,
  });
  final String? posterUrl;
  final String title, description, location;
  final DateTime startAt, endAt;
  final int capacity;
  final DateTime registrationDeadline;
  final String category; // TECHNOLOGY|SCIENCE|CULTURE|SPORTS|SOCIAL|ENTREPRENEURSHIP

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        'startsAt': startAt.toUtc().toIso8601String(),
        'endsAt': endAt.toUtc().toIso8601String(),
        'category': category,
        'registrationDeadline': registrationDeadline.toUtc().toIso8601String(),
        'capacity': capacity,
        if (posterUrl != null) 'posterUrl': posterUrl,
      };
}

/// Mirrors backend rules so users get quick feedback. The server still decides.
String? validateEventInput({
  required String title,
  required int? capacity,
  required DateTime? startAt,
  required DateTime? endAt,
  required DateTime? deadline,
  required String? category,
}) {
  if (title.trim().length < 3) return 'Titre trop court (3 caractères min.)';
  if (capacity == null || capacity < 1) return 'Capacité invalide (1 min.)';
  if (category == null) return 'Catégorie requise';
  if (startAt == null || endAt == null || deadline == null) return 'Dates requises';
  if (!endAt.isAfter(startAt)) return 'La fin doit être après le début';
  if (deadline.isAfter(startAt)) {
    return "La date limite d'inscription doit précéder le début";
  }
  return null;
}

class Registrant {
  Registrant(this.id, this.status, this.name, this.email, {this.studentId});
  final String id, status, name, email;
  final String? studentId;
  factory Registrant.fromJson(Map<String, dynamic> j) {
    final u = ((j['user'] ?? j['student'] ?? {}) as Map).cast<String, dynamic>();
    return Registrant('${j['id']}', '${j['status']}',
        '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(), '${u['email'] ?? ''}',
        studentId: u['studentId'] as String?);
  }
}

/// ASSUMED endpoints (not yet in an OpenAPI file): see docs/TASKS.md.
class ClubAdminRepository {
  ClubAdminRepository(this._dio);
  final Dio _dio;

  /// Clubs the signed-in user administers (GET /me/clubs): approved first.
  Future<List<Club>> myAdminClubs(String userId) => guarded(() async {
        final r = await _dio.get('/me/clubs');
        return (r.data['data'] as List)
            .cast<Map<String, dynamic>>()
            .map(Club.fromJson)
            .toList();
      });

  Future<Paged<Event>> myClubEvents(String clubId, int page) =>
      fetchPaged(_dio, '/clubs/$clubId/events', Event.fromJson, page: page);

  Future<void> create(String clubId, EventInput i) => guarded(() =>
      _dio.post('/events', data: {...i.toJson(), 'clubId': clubId}));

  Future<void> update(String id, EventInput i) =>
      guarded(() => _dio.patch('/events/$id', data: i.toJson()));

  Future<Paged<Registrant>> registrants(String eventId, int page) => fetchPaged(
      _dio, '/events/$eventId/registrations', Registrant.fromJson, page: page);

  Future<void> markAttended(String registrationId) => guarded(() =>
      _dio.patch('/registrations/$registrationId', data: {'status': 'ATTENDED'}));

  Future<void> cancelRegistration(String registrationId) =>
      guarded(() => _dio.delete('/registrations/$registrationId'));

  /// ASSUMED: PATCH /clubs/:id with any of description, logoUrl.
  Future<void> updateClub(String id, {String? description, String? logoUrl}) =>
      guarded(() => _dio.patch('/clubs/$id', data: {
            'description': ?description,
            'logoUrl': ?logoUrl,
          }));

  Future<void> delete(String id) => guarded(() => _dio.delete('/events/$id'));
}

final clubAdminRepositoryProvider =
    Provider((ref) => ClubAdminRepository(ref.watch(dioProvider)));
