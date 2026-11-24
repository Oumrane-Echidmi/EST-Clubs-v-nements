import 'registration_state.dart';

/// Minimal event model used by cards. Field names follow the backend contract
/// in the project prompt; verify against docs/openapi.json when it exists.
class Event {
  Event({
    required this.id,
    required this.title,
    required this.startAt,
    required this.registrationState,
    this.posterUrl,
    this.location,
    this.capacity,
    this.availableSeats,
    this.serverTime,
  });

  final String id;
  final String title;
  final DateTime startAt; // UTC
  final String? posterUrl;
  final String? location;
  final int? capacity;
  final int? availableSeats;
  final RegistrationState registrationState;
  final DateTime? serverTime;

  /// serverTime - deviceTime at fetch moment; feeds [formatCountdown].
  Duration get serverOffset => serverTime == null
      ? Duration.zero
      : serverTime!.difference(DateTime.now().toUtc());

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: '${j['id']}',
        title: '${j['title']}',
        startAt: DateTime.parse('${j['startAt']}').toUtc(),
        posterUrl: j['posterUrl'] as String?,
        location: j['location'] as String?,
        capacity: j['capacity'] as int?,
        availableSeats: j['availableSeats'] as int?,
        registrationState:
            RegistrationState.parse(j['registrationState'] as String?),
        serverTime: j['serverTime'] == null
            ? null
            : DateTime.parse('${j['serverTime']}').toUtc(),
      );
}
