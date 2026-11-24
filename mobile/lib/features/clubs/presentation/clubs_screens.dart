import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_images.dart';
import '../../../core/widgets/event_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../events/data/events_repository.dart';
import '../../club_admin/data/club_admin_repository.dart' show eventCategories, categoryLabel;
import '../data/clubs_repository.dart';

class ClubCard extends StatelessWidget {
  const ClubCard({super.key, required this.club, this.onTap});
  final Club club;
  final VoidCallback? onTap;
  /// Stitch directory card: gradient banner with category pill, logo tile + name,
  /// description, then a status line and an orange/navy action button.
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 140,
              child: Stack(fit: StackFit.expand, children: [
                photo(url: null, asset: clubBannerAsset(club.name, club.category)),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x66000000), Color(0x00000000), Color(0x99000000)]))),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (club.category != null)
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.verified, size: 13, color: Color(0xFF1E3A8A)),
                            const SizedBox(width: 4),
                            Text(categoryLabel(club.category),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
                          ])),
                    const Spacer(),
                    CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        child: Icon(
                            club.isFollowing ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: club.isFollowing ? const Color(0xFFF97316) : const Color(0xFF444651))),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFDCE1FF),
                    backgroundImage: photoProvider(
                        url: club.logoUrl,
                        asset: clubLogoAsset(club.name, club.category)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(club.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800))),
                ]),
                if (club.memberCount != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.groups_2_outlined, size: 16, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 4),
                        Text('${club.memberCount} membres',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ])),
                if (club.description != null) ...[
                  const SizedBox(height: 10),
                  Text(club.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                if (club.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in club.tags.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(16)),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00236F))),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  if (club.isFollowing) ...[
                    const Icon(Icons.circle, size: 8, color: Colors.green),
                    const SizedBox(width: 6),
                    const Text('Suivi actif',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                        color: club.isFollowing
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(club.isFollowing ? 'Voir' : 'Découvrir',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

/// Round club avatar with the Stitch gradient ring (blue -> orange).
class ClubStory extends StatelessWidget {
  const ClubStory({super.key, required this.club, this.onTap});
  final Club club;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 68,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Color(0xFF1E3A8A), Color(0xFFFD761A)])),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Theme.of(context).colorScheme.surface),
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: photoProvider(
                      url: club.logoUrl,
                      asset: clubLogoAsset(club.name, club.category)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

/// Search box + paged list. Same pattern is used by the events tab.
class ClubsTab extends ConsumerStatefulWidget {
  const ClubsTab({super.key});
  @override
  ConsumerState<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends ConsumerState<ClubsTab> {
  String _q = '';
  String? _cat;
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Rechercher un club'),
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        const SizedBox(height: 8),
        FilterChipsRow(
            options: eventCategories.keys.toList(),
            selected: _cat,
            onChanged: (v) => setState(() => _cat = v)),
        Expanded(
          child: PagedListView<Club>(
            key: ValueKey('$_q|$_cat'), // new key => reload
            fetch: (p) => ref
                .read(clubsRepositoryProvider)
                .list(p, search: _q, category: eventCategories[_cat]),
            emptyMessage: 'Aucun club trouvé',
            itemBuilder: (c, club) => ClubCard(
                club: club, onTap: () => context.push('/clubs/${club.id}')),
          ),
        ),
      ]);
}

class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clubDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Club')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
            message: '$e', onRetry: () => ref.invalidate(clubDetailProvider(id))),
        data: (club) => ListView(padding: const EdgeInsets.all(16), children: [
          Text(club.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(club.description ?? ''),
          const SizedBox(height: 16),
          _FollowButton(club: club),
          const SizedBox(height: 24),
          Text('Événements à venir',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: PagedListView(
              fetch: (p) => ref.read(eventsRepositoryProvider).byClub(id, p),
              emptyMessage: 'Aucun événement',
              itemBuilder: (c, e) =>
                  EventCard(event: e, onTap: () => c.push('/events/${e.id}')),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.club});
  final Club club;
  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  late bool _following = widget.club.isFollowing;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(clubsRepositoryProvider);
    try {
      _following
          ? await repo.unfollow(widget.club.id)
          : await repo.follow(widget.club.id);
      if (mounted) setState(() => _following = !_following);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: _busy ? null : _toggle,
      child: Text(_following ? 'Ne plus suivre' : 'Suivre'));
}
