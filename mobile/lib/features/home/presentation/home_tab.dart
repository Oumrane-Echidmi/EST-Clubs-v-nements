import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/paged.dart';
import '../../../core/widgets/event_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../club_admin/data/club_admin_repository.dart' show eventCategories;
import '../../clubs/data/clubs_repository.dart';
import '../../clubs/presentation/clubs_screens.dart';
import '../../events/domain/event.dart';

class Announcement {
  Announcement(this.title, this.body);
  final String title, body;
}

/// GET /home: each section is { data: [...], meta } (see docs/API.md).
class HomeData {
  HomeData(this.events, this.clubs, this.announcements);
  final List<Event> events;
  final List<Club> clubs;
  final List<Announcement> announcements;

  factory HomeData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (((j[k] as Map?)?['data'] ?? []) as List)
            .cast<Map<String, dynamic>>()
            .map(f)
            .toList();
    return HomeData(
      list('upcomingEvents', Event.fromJson),
      list('featuredClubs', Club.fromJson),
      list('announcements',
          (m) => Announcement('${m['title']}', '${m['body'] ?? ''}')),
    );
  }

  /// The event to feature: open for registration and the fullest ("presque complet").
  Event? get hero {
    final open = events.where((e) => e.canRegister).toList();
    if (open.isEmpty) return events.isEmpty ? null : events.first;
    open.sort((a, b) => (b.fillRatio ?? 0).compareTo(a.fillRatio ?? 0));
    return open.first;
  }
}

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) {
  final dio = ref.watch(dioProvider);
  return guarded(() async {
    // Soonest first (the API default is newest first).
    final r = await dio
        .get('/home', queryParameters: {'sortOrder': 'asc', 'limit': 20});
    return HomeData.fromJson(
        ((r.data['data'] ?? r.data) as Map).cast<String, dynamic>());
  });
});

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
String _short(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});
  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  String? _cat; // label of the selected theme chip, null = all

  Widget _sectionLabel(String text, {String? trailing, VoidCallback? onTrailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              child: Text(text.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF444651)))),
          if (trailing != null)
            GestureDetector(
                onTap: onTrailing,
                child: Text(trailing,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00236F)))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final async = ref.watch(homeProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '$e',
          onRetry: () => ref.invalidate(homeProvider)),
      data: (h) {
        final hero = h.hero;
        final catValue = _cat == null ? null : eventCategories[_cat];
        var rest = h.events
            .where((e) => e.id != hero?.id)
            .where((e) => catValue == null || e.category == catValue)
            .toList();
        final now = DateTime.now().toUtc();
        final week = rest
            .where((e) => e.startAt.isBefore(now.add(const Duration(days: 7))))
            .toList();
        final thisWeek = week.length >= 2;
        final list = (thisWeek ? week : rest).take(8).toList();
        final from = now.toLocal(), to = now.add(const Duration(days: 7)).toLocal();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Row(children: [
              Expanded(
                  child: Text('Bonjour ${user?.firstName ?? ''} 👋',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFDBCA), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department, size: 14, color: Color(0xFF341100)),
                  Text(' Saison ${DateTime.now().year}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF341100))),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: const [
              Icon(Icons.school_outlined, size: 16, color: Color(0xFF00236F)),
              SizedBox(width: 6),
              Text('École Supérieure de Technologie',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00236F))),
            ]),
            const SizedBox(height: 16),
            if (h.clubs.isNotEmpty) ...[
              _sectionLabel('Clubs en direct', trailing: '${h.clubs.length} actifs'),
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
            if (hero != null) ...[
              HeroEventCard(event: hero, onTap: () => context.push('/events/${hero.id}')),
              const SizedBox(height: 20),
            ],
            _sectionLabel('Filtrer par thématique',
                trailing: _cat == null ? null : 'Réinitialiser',
                onTrailing: () => setState(() => _cat = null)),
            FilterChipsRow(
                padding: EdgeInsets.zero,
                options: eventCategories.keys.toList(),
                selected: _cat,
                onChanged: (v) => setState(() => _cat = v)),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(thisWeek ? "Cette semaine à l'EST" : 'Prochains événements',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (thisWeek)
                    Text('${_short(from)} - ${_short(to)} ${to.year}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF444651))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) const EmptyState(message: 'Aucun événement pour cette thématique'),
            for (final e in list) ...[
              EventCard(event: e, onTap: () => context.push('/events/${e.id}')),
              const SizedBox(height: 12),
            ],
            if (h.announcements.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionLabel('Annonces'),
              for (final a in h.announcements.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.campaign_outlined, color: Color(0xFFF97316)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (a.body.isNotEmpty)
                              Text(a.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF444651))),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          ]),
        );
      },
    );
  }
}
