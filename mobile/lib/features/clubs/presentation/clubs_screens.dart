import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/event_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../events/data/events_repository.dart';
import '../data/clubs_repository.dart';

class ClubCard extends StatelessWidget {
  const ClubCard({super.key, required this.club, this.onTap});
  final Club club;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundImage: club.logoUrl == null
                ? null
                : CachedNetworkImageProvider(club.logoUrl!),
            child: club.logoUrl == null ? Text(club.name[0]) : null,
          ),
          title: Text(club.name),
          subtitle: Text(club.category ?? club.description ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
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
                  backgroundImage: club.logoUrl == null
                      ? null
                      : CachedNetworkImageProvider(club.logoUrl!),
                  child: club.logoUrl == null ? Text(club.name[0]) : null,
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
        Expanded(
          child: PagedListView<Club>(
            key: ValueKey(_q), // new key => reload
            fetch: (p) =>
                ref.read(clubsRepositoryProvider).list(p, search: _q),
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
