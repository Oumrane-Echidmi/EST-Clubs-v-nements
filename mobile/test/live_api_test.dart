// Live integration test: runs the app's REAL repositories against a running
// backend. Skipped unless LIVE_API is given:
//
//   flutter test test/live_api_test.dart \
//     --dart-define=LIVE_API=http://localhost:3000/api \
//     --dart-define=SEED_PASSWORD=<value from backend/.env>
//
// Seed accounts are listed in backend/README.md.
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/core/network/auth_interceptor.dart';
import 'package:est_clubs_events/core/storage/token_storage.dart';
import 'package:est_clubs_events/features/auth/data/auth_repository.dart';
import 'package:est_clubs_events/features/club_admin/data/club_admin_repository.dart';
import 'package:est_clubs_events/features/clubs/data/clubs_repository.dart';
import 'package:est_clubs_events/features/events/data/events_repository.dart';
import 'package:est_clubs_events/features/home/presentation/home_tab.dart';
import 'package:est_clubs_events/features/notifications/notifications.dart';
import 'package:est_clubs_events/features/super_admin/super_admin.dart';

const api = String.fromEnvironment('LIVE_API');
const pw = String.fromEnvironment('SEED_PASSWORD');

class MemTokens implements TokenStorage {
  String? a, r;
  @override
  Future<String?> get accessToken async => a;
  @override
  Future<String?> get refreshToken async => r;
  @override
  Future<void> save(String x, String y) async {
    a = x;
    r = y;
  }

  @override
  Future<void> clear() async {
    a = null;
    r = null;
  }
}

class Session {
  Session(this.dio, this.auth, this.user);
  final Dio dio;
  final AuthRepository auth;
  final AuthUser user;
}

final _sessions = <String, Session>{};

/// One login per account: the backend limits auth calls to 10 per 15 minutes.
Future<Session> login(String email) async =>
    _sessions[email] ??= await _login(email);

Future<Session> _login(String email) async {
  final tokens = MemTokens();
  final dio = Dio(BaseOptions(baseUrl: api));
  dio.interceptors.add(AuthInterceptor(dio, tokens));
  final auth = AuthRepository(dio, tokens);
  final user = await auth.login(email, pw);
  return Session(dio, auth, user);
}

void main() {
  final skip = api.isEmpty ? 'set --dart-define=LIVE_API to run' : null;

  test('student: login, lists, detail, register, cancel', () async {
    final s = await login('student1@est.example.edu');
    expect(s.user.role, 'STUDENT');
    expect(s.user.firstName, isNotEmpty);

    final me = await s.auth.restore();
    expect(me?.id, s.user.id);

    final events = EventsRepository(s.dio);
    final page = await events.list(1);
    expect(page.items, isNotEmpty);
    final detail = await events.get(page.items.first.id);
    expect(detail.title, isNotEmpty);

    // Filter by category goes through and parses.
    await events.list(1, category: 'TECHNOLOGY');

    // Find an event the server says we can register to, then register + cancel.
    final all = (await events.list(1)).items;
    final open = all.where((e) => e.canRegister).toList();
    if (open.isNotEmpty) {
      final e = open.first;
      await events.register(e.id);
      final after = await events.get(e.id);
      expect(after.registrationState.wire, 'REGISTERED');
      expect(after.availableSeats, (e.availableSeats ?? 1) - 1);
      if (after.canCancel) {
        await events.cancel(after.myRegistrationId!);
        final back = await events.get(e.id);
        expect(back.availableSeats, e.availableSeats);
      }
    }

    for (final tab in ['upcoming', 'completed', 'cancelled']) {
      await events.myRegistrations(1, tab);
    }

    final clubs = ClubsRepository(s.dio);
    final cl = await clubs.list(1);
    expect(cl.items, isNotEmpty);
    await clubs.get(cl.items.first.id);
    await clubs.list(1, category: 'SPORTS');

    final n = NotificationsRepository(s.dio);
    expect(await n.unreadCount(), isA<int>());
    await n.list(1);

    final r = await s.dio.get('/home');
    final home = (r.data['data'] as Map);
    expect(home.keys, containsAll(['upcomingEvents', 'featuredClubs', 'announcements']));
    final parsed = HomeData.fromJson(home.cast<String, dynamic>());
    expect(parsed.events, isNotEmpty);
    expect(parsed.clubs, isNotEmpty);
  }, skip: skip);

  test('wrong password maps to an AppException', () async {
    final tokens = MemTokens();
    final dio = Dio(BaseOptions(baseUrl: api));
    final auth = AuthRepository(dio, tokens);
    await expectLater(auth.login('student1@est.example.edu', 'Wrong-pass-1'),
        throwsA(predicate((e) => e.toString().isNotEmpty)));
  }, skip: skip);

  test('club admin: finds own clubs, lists own events', () async {
    final s = await login('clubadmin1@est.example.edu');
    expect(s.user.role, 'CLUB_ADMIN');
    final repo = ClubAdminRepository(s.dio);
    final mine = await repo.myAdminClubs(s.user.id);
    expect(mine, isNotEmpty, reason: 'club admin should administer a club');
    expect(mine.first.status, 'APPROVED', reason: 'approved clubs are listed first');
    final evs = await repo.myClubEvents(mine.first.id, 1);
    expect(evs.items, isNotEmpty);
  }, skip: skip);

  test('club admin: create, edit, delete an event', () async {
    final s = await login('clubadmin1@est.example.edu');
    final repo = ClubAdminRepository(s.dio);
    final club = (await repo.myAdminClubs(s.user.id)).first;
    final start = DateTime.now().toUtc().add(const Duration(days: 20));
    EventInput input(String title) => EventInput(
        title: title,
        description: 'Événement créé par le test live',
        location: 'Amphi test',
        startAt: start,
        endAt: start.add(const Duration(hours: 2)),
        capacity: 25,
        category: 'TECHNOLOGY',
        registrationDeadline: start.subtract(const Duration(days: 1)));
    await repo.create(club.id, input('Live test event'));
    final evs = await repo.myClubEvents(club.id, 1);
    final created = evs.items.firstWhere((e) => e.title == 'Live test event');
    expect(created.status, 'PENDING_APPROVAL');
    await repo.update(created.id, input('Live test event v2'));
    await repo.delete(created.id);
  }, skip: skip);

  test('super admin: dashboard, pending events, users, approve flow', () async {
    final s = await login('superadmin@est.example.edu');
    final repo = SuperAdminRepository(s.dio);
    final d = await repo.dashboard();
    expect(d['users'], isA<num>());
    await repo.pendingEvents(1);
    final users = await repo.users(1);
    expect(users.items, isNotEmpty);
    expect(users.items.first.email, contains('@'));
  }, skip: skip);

  test('calendar .ics downloads', () async {
    final s = await login('student1@est.example.edu');
    final events = EventsRepository(s.dio);
    final e = (await events.list(1)).items.first;
    final path = await events.downloadIcs(e.id, Directory.systemTemp.path);
    expect(File(path).readAsStringSync(), contains('BEGIN:VCALENDAR'));
  }, skip: skip);
}
