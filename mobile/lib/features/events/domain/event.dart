import 'registration_state.dart';

/// Event model. Field names follow the backend contract in the project prompt;
/// verify against docs/openapi.json when it exists.
class Event {
  Event({
    required this.id,
    required this.title,
    required this.startAt,
    required this.registrationState,
    this.description,
    this.posterUrl,
    this.location,
    this.capacity,
    this.availableSeats,
    this.registeredCount,
    this.endAt,
    this.registrationDeadline,
    this.serverTime,
    this.myRegistrationId,
    this.canCancel = false,
    this.status,
    this.rejectionReason,
  });

  /// Approval status for admins: PENDING_APPROVAL | PUBLISHED | REJECTED ...
  final String? status;
  final String? rejectionReason;

  final String id;
  final String title;
  final String? description;
  final DateTime startAt; // UTC
  final DateTime? endAt;
  final DateTime? registrationDeadline;
  final String? posterUrl;
  final String? location;
  final int? capacity;
  final int? availableSeats;
  final int? registeredCount;
  final RegistrationState registrationState;
  final DateTime? serverTime;
  final String? myRegistrationId;

  /// Decided by the backend (cancellation cutoff). The app never computes it.
  final bool canCancel;

  /// serverTime - deviceTime at fetch moment; feeds [formatCountdown].
  Duration get serverOffset => serverTime == null
      ? Duration.zero
      : serverTime!.difference(DateTime.now().toUtc());

  static DateTime? _d(Object? v) =>
      v == null ? null : DateTime.parse('$v').toUtc();

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: '${j['id']}',
        title: '${j['title']}',
        description: j['description'] as String?,
        startAt: DateTime.parse('${j['startAt']}').toUtc(),
        endAt: _d(j['endAt']),
        registrationDeadline: _d(j['registrationDeadline']),
        posterUrl: j['posterUrl'] as String?,
        location: j['location'] as String?,
        capacity: j['capacity'] as int?,
        availableSeats: j['availableSeats'] as int?,
        registeredCount: j['registeredCount'] as int?,
        registrationState:
            RegistrationState.parse(j['registrationState'] as String?),
        serverTime: _d(j['serverTime']),
        myRegistrationId: j['myRegistrationId'] as String?,
        canCancel: j['canCancel'] as bool? ?? false,
        status: j['status'] as String?,
        rejectionReason: j['rejectionReason'] as String?,
      );
}
