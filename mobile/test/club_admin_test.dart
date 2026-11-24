import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/features/club_admin/data/club_admin_repository.dart';

void main() {
  final s = DateTime.utc(2030, 1, 1, 10);
  final e = DateTime.utc(2030, 1, 1, 12);

  String? v({String t = 'Hackathon', int? cap = 10, DateTime? st, DateTime? en, DateTime? dl, String? cat = 'SPORTS'}) =>
      validateEventInput(
          title: t,
          capacity: cap,
          startAt: st ?? s,
          endAt: en ?? e,
          deadline: dl ?? s.subtract(const Duration(days: 1)),
          category: cat);

  test('valid input passes', () => expect(v(), isNull));
  test('short title rejected', () => expect(v(t: 'ab'), isNotNull));
  test('capacity must be >= 1', () {
    expect(v(cap: 0), isNotNull);
    expect(v(cap: null), isNotNull);
  });
  test('category is required', () => expect(v(cat: null), isNotNull));
  test('end must be after start', () => expect(v(en: s), isNotNull));
  test('deadline must not be after start',
      () => expect(v(dl: s.add(const Duration(hours: 1))), isNotNull));
  test('serializes dates as UTC ISO', () {
    final j = EventInput(
            title: 't',
            description: 'd',
            location: 'l',
            startAt: s,
            endAt: e,
            capacity: 5,
            category: 'SPORTS',
            registrationDeadline: s)
        .toJson();
    expect(j['startsAt'], '2030-01-01T10:00:00.000Z');
    expect(j['category'], 'SPORTS');
    expect(j.containsKey('registrationDeadline'), isTrue);
  });
}
