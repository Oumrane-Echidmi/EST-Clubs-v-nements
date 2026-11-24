import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/paged.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../events/domain/event.dart';

/// Values sent when creating / editing an event.
class EventInput {
  EventInput({
    required this.title,
    required this.description,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    this.registrationDeadline,
    this.posterUrl,
  });
  final String? posterUrl;
  final String title, description, location;
  final DateTime startAt, endAt;
  final int capacity;
  final DateTime? registrationDeadline;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        'capacity': capacity,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (registrationDeadline != null)
          'registrationDeadline': registrationDeadline!.toUtc().toIso8601String(),
      };
}

/// Mirrors backend rules so users get quick feedback. The server still decides.
String? validateEventInput({
  required String title,
  required int? capacity,
  required DateTime? startAt,
  required DateTime? endAt,
  DateTime? deadline,
}) {
  if (title.trim().length < 3) return 'Titre trop court (3 caractères min.)';
  if (capacity == null || capacity < 1) return 'Capacité invalide (1 min.)';
  if (startAt == null || endAt == null) return 'Dates requises';
  if (!endAt.isAfter(startAt)) return 'La fin doit être après le début';
  if (deadline != null && deadline.isAfter(startAt)) {
    return "La date limite d'inscription doit précéder le début";
  }
  return null;
}

class Registrant {
  Registrant(this.id, this.status, this.name, this.email);
  final String id, status, name, email;
  factory Registrant.fromJson(Map<String, dynamic> j) {
    final u = ((j['user'] ?? j['student'] ?? {}) as Map).cast<String, dynamic>();
    return Registrant('${j['id']}', '${j['status']}',
        '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(), '${u['email'] ?? ''}');
  }
}

/// ASSUMED endpoints (not yet in an OpenAPI file): see docs/TASKS.md.
class ClubAdminRepository {
  ClubAdminRepository(this._dio);
  final Dio _dio;

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
