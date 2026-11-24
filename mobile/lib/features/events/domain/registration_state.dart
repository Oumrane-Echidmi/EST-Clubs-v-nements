import 'package:flutter/material.dart';

/// Backend-provided registrationState. The client never derives eligibility;
/// it only maps the state to a label / action.
enum RegistrationState {
  open('OPEN', "S'inscrire", true),
  full('FULL', 'Complet', false),
  deadlinePassed('DEADLINE_PASSED', 'Inscriptions closes', false),
  notPublished('NOT_PUBLISHED', 'Non publié', false),
  ended('ENDED', 'Terminé', false),
  registered('REGISTERED', 'Inscrit', false),
  cancelledByMe('CANCELLED_BY_ME', "S'inscrire à nouveau", true),
  unknown('UNKNOWN', '', false);

  const RegistrationState(this.wire, this.label, this.canRegister);
  final String wire;
  final String label;
  final bool canRegister;

  static RegistrationState parse(String? v) => RegistrationState.values
      .firstWhere((s) => s.wire == v, orElse: () => RegistrationState.unknown);

  Color color(ColorScheme cs) => switch (this) {
        open || cancelledByMe => cs.primary,
        registered => Colors.green.shade700,
        full || deadlinePassed || notPublished || ended => cs.outline,
        unknown => cs.outline,
      };
}

/// Countdown text from a server-corrected clock.
/// [serverOffset] = serverTime - deviceTime, measured when the event was fetched.
String formatCountdown(DateTime target, DateTime deviceNow,
    {Duration serverOffset = Duration.zero}) {
  final left = target.difference(deviceNow.add(serverOffset));
  if (left.isNegative || left == Duration.zero) return 'Terminé';
  final d = left.inDays;
  final h = left.inHours % 24;
  final m = left.inMinutes % 60;
  final s = left.inSeconds % 60;
  if (d > 0) return '${d}j ${h}h ${m}m';
  if (left.inHours > 0) return '${left.inHours}h ${m}m ${s}s';
  return '${m}m ${s}s';
}
