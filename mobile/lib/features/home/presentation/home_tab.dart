import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/paged.dart';
import '../../../core/widgets/event_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clubs/data/clubs_repository.dart';
import '../../clubs/presentation/clubs_screens.dart';
import '../../events/domain/event.dart';

/// GET /home. Section names are assumptions: upcomingEvents, featuredClubs,
/// announcements[{id,title}] (see docs/TASKS.md).
class HomeData {
  HomeData(this.events, this.clubs, this.announcements);
  final List<Event> events;
  final List<Club> clubs;
  final List<String> announcements;

  factory HomeData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] ?? []) as List).cast<Map<String, dynamic>>().map(f).toList();
    return HomeData(
      list('upcomingEvents', Event.fromJson),
      list('featuredClubs', Club.fromJson),
      list('announcements', (m) => '${m['title']}'),
    );
  }
}

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) {
  final dio = ref.watch(dioProvider);
  return guarded(() async {
    final r = await dio.get('/home');
    return HomeData.fromJson(
        ((r.data['data'] ?? r.data) as Map).cast<String, dynamic>());
  });
});

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final async = ref.watch(homeProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '$e',
          onRetry: () => ref.invalidate(homeProvider)),
      data: (h) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(homeProvider),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
                child: Text('Bonjour ${user?.fullName ?? ''} 👋',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFDBCA),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department, size: 14, color: Color(0xFF341100)),
                Text(' Saison ${DateTime.now().year}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF341100))),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          if (h.clubs.isNotEmpty) ...[
            Text('Clubs en direct',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: h.clubs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (c, i) => ClubStory(
                    club: h.clubs[i], onTap: () => c.push('/clubs/${h.clubs[i].id}')),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final a in h.announcements)
            Card(child: ListTile(leading: const Icon(Icons.campaign), title: Text(a))),
          Text('Événements à venir', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (h.events.isEmpty) const EmptyState(message: 'Aucun événement à venir'),
          for (final e in h.events) ...[
            EventCard(event: e, onTap: () => context.push('/events/${e.id}')),
            const SizedBox(height: 12),
          ],
          Text('Clubs à découvrir', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final c in h.clubs)
            ClubCard(club: c, onTap: () => context.push('/clubs/${c.id}')),
        ]),
      ),
    );
  }
}
