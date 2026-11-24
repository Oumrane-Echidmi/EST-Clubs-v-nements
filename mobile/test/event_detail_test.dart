import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/features/events/data/events_repository.dart';
import 'package:est_clubs_events/features/events/domain/event.dart';
import 'package:est_clubs_events/features/events/presentation/events_screens.dart';

/// Fake repository: records calls, serves a fixed event JSON.
class FakeRepo extends EventsRepository {
  FakeRepo(this.json) : super(Dio());
  Map<String, dynamic> json;
  final calls = <String>[];
  @override
  Future<Event> get(String id) async => Event.fromJson(json);
  @override
  Future<void> register(String eventId) async => calls.add('register:$eventId');
  @override
  Future<void> cancel(String registrationId) async => calls.add('cancel:$registrationId');
}

Map<String, dynamic> _json(String state, {bool canCancel = false}) => {
      'id': '9',
      'title': 'Conférence IA',
      'startsAt': '2031-01-01T10:00:00Z',
      'registrationState': state,
      'registrationId': 'r1',
      'canCancel': canCancel,
      'canRegister': state == 'OPEN' || state == 'CANCELLED_BY_ME',
      'capacity': 50,
      'availableSeats': 10,
      'registeredCount': 40,
    };

Future<FakeRepo> _open(WidgetTester t, Map<String, dynamic> json) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final repo = FakeRepo(json);
  await t.pumpWidget(ProviderScope(
    overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: EventDetailScreen('9')),
  ));
  await t.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('OPEN: confirm dialog then registers', (t) async {
    final repo = await _open(t, _json('OPEN'));
    await t.tap(find.widgetWithText(FilledButton, "S'inscrire"));
    await t.pumpAndSettle();
    expect(find.text("Confirmer l'inscription"), findsOneWidget);
    await t.tap(find.text('Oui'));
    await t.pumpAndSettle();
    expect(repo.calls, ['register:9']);
  });

  testWidgets('OPEN: declining the dialog does nothing', (t) async {
    final repo = await _open(t, _json('OPEN'));
    await t.tap(find.widgetWithText(FilledButton, "S'inscrire"));
    await t.pumpAndSettle();
    await t.tap(find.text('Non'));
    await t.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('FULL: no action button, only status chip', (t) async {
    await _open(t, _json('FULL'));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Complet'), findsWidgets);
  });

  testWidgets('REGISTERED + canCancel: cancel uses registration id', (t) async {
    final repo = await _open(t, _json('REGISTERED', canCancel: true));
    await t.tap(find.text('Annuler mon inscription'));
    await t.pumpAndSettle();
    await t.tap(find.text('Oui'));
    await t.pumpAndSettle();
    expect(repo.calls, ['cancel:r1']);
  });

  testWidgets('REGISTERED but backend says cannot cancel: no cancel button', (t) async {
    await _open(t, _json('REGISTERED'));
    expect(find.text('Annuler mon inscription'), findsNothing);
  });
}
