import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/core/widgets/event_widgets.dart';
import 'package:est_clubs_events/features/events/domain/event.dart';
import 'package:est_clubs_events/features/events/domain/registration_state.dart';

Event _e(String state, {int? seats = 12}) => Event.fromJson({
      'id': '1',
      'title': 'Hackathon EST',
      'startAt': '2030-01-01T10:00:00Z',
      'location': 'Amphi A',
      'capacity': 40,
      'availableSeats': seats,
      'registrationState': state,
    });

void main() {
  testWidgets('EventCard shows title, location, seats and state', (t) async {
    var tapped = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EventCard(event: _e('OPEN'), onTap: () => tapped = true))));
    expect(find.text('Hackathon EST'), findsOneWidget);
    expect(find.textContaining('Amphi A'), findsOneWidget);
    expect(find.textContaining('places'), findsWidgets);
    expect(find.text("S'inscrire"), findsOneWidget);
    await t.tap(find.byType(EventCard));
    expect(tapped, isTrue);
  });

  testWidgets('EventCard renders FULL and REGISTERED states', (t) async {
    for (final s in ['FULL', 'REGISTERED']) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: EventCard(event: _e(s, seats: null)))));
      expect(find.text(RegistrationState.parse(s).label), findsOneWidget);
    }
  });

  testWidgets('CountdownChip renders inside ProviderScope', (t) async {
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                body: CountdownChip(
                    target: DateTime.now().toUtc().add(const Duration(days: 2)))))));
    expect(find.textContaining('j '), findsOneWidget);
  });
}
