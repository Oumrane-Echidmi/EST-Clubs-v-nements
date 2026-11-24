import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/paged.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/event.dart';

class Registration {
  Registration(this.id, this.status, this.event);
  final String id;
  final String status; // CONFIRMED | ATTENDED | CANCELLED
  final Event event;
  factory Registration.fromJson(Map<String, dynamic> j) => Registration(
        '${j['id']}',
        '${j['status']}',
        Event.fromJson((j['event'] as Map).cast<String, dynamic>()),
      );
}

class EventsRepository {
  EventsRepository(this._dio);
  final Dio _dio;

  Future<Paged<Event>> list(int page, {String? search, String? category}) =>
      fetchPaged(_dio, '/events', Event.fromJson, page: page, query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null) 'category': category,
      });

  /// Fallback when the device calendar fails: downloads GET /events/:id/calendar.ics
  /// (authenticated) to a temp file and returns its path.
  Future<String> downloadIcs(String id, String dir) => guarded(() async {
        final path = '$dir/event-$id.ics';
        await _dio.download('/events/$id/calendar.ics', path);
        return path;
      });

  Future<Paged<Event>> byClub(String clubId, int page) =>
      fetchPaged(_dio, '/clubs/$clubId/events', Event.fromJson, page: page);

  Future<Event> get(String id) => guarded(() async {
        final r = await _dio.get('/events/$id');
        return Event.fromJson(
            ((r.data['data'] ?? r.data) as Map).cast<String, dynamic>());
      });

  Future<void> register(String eventId) =>
      guarded(() => _dio.post('/events/$eventId/register'));

  Future<void> cancel(String registrationId) =>
      guarded(() => _dio.delete('/registrations/$registrationId'));

  Future<Paged<Registration>> myRegistrations(int page) =>
      fetchPaged(_dio, '/me/registrations', Registration.fromJson, page: page);
}

final eventsRepositoryProvider =
    Provider((ref) => EventsRepository(ref.watch(dioProvider)));

/// Event details; `ref.invalidate(eventDetailProvider(id))` reloads after
/// registering/cancelling so seats and state refresh.
final eventDetailProvider = FutureProvider.autoDispose.family<Event, String>(
    (ref, id) => ref.watch(eventsRepositoryProvider).get(id));
