import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/core/widgets/state_views.dart';
import 'package:est_clubs_events/features/events/domain/registration_state.dart';

void main() {
  test('parses every backend registration state', () {
    for (final w in [
      'OPEN',
      'FULL',
      'DEADLINE_PASSED',
      'NOT_PUBLISHED',
      'ENDED',
      'REGISTERED',
      'CANCELLED_BY_ME'
    ]) {
      expect(RegistrationState.parse(w).wire, w);
    }
    expect(RegistrationState.parse('???'), RegistrationState.unknown);
    expect(RegistrationState.open.canRegister, isTrue);
    expect(RegistrationState.full.canRegister, isFalse);
  });

  test('countdown uses fixed clock and server offset', () {
    final now = DateTime.utc(2026, 1, 1, 10);
    expect(formatCountdown(DateTime.utc(2026, 1, 3, 12, 30), now), '2j 2h 30m');
    expect(formatCountdown(DateTime.utc(2026, 1, 1, 11, 5, 9), now), '1h 5m 9s');
    expect(formatCountdown(DateTime.utc(2026, 1, 1, 10, 0, 30), now), '0m 30s');
    expect(formatCountdown(DateTime.utc(2026, 1, 1, 9), now), 'Terminé');
    // device clock 1 min behind server: 30s remain for the server, not 1m30s
    expect(
        formatCountdown(DateTime.utc(2026, 1, 1, 10, 1, 30), now,
            serverOffset: const Duration(minutes: 1)),
        '0m 30s');
  });

  testWidgets('empty and error views render; retry fires', (t) async {
    var retried = 0;
    await t.pumpWidget(MaterialApp(
        home: Column(children: [
      const Expanded(child: EmptyState(message: 'Aucun événement')),
      Expanded(child: ErrorView(message: 'Oups', onRetry: () => retried++)),
    ])));
    expect(find.text('Aucun événement'), findsOneWidget);
    await t.tap(find.text('Réessayer'));
    expect(retried, 1);
  });
}
