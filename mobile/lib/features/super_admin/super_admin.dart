import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/paged.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/state_views.dart';
import '../auth/presentation/auth_providers.dart';
import '../events/domain/event.dart';

class AdminUser {
  AdminUser(this.id, this.name, this.email, this.role, this.isActive);
  final String id, name, email, role;
  final bool isActive;
  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        '${j['id']}',
        '${j['fullName'] ?? j['name'] ?? ''}',
        '${j['email']}',
        '${j['role']}',
        j['isActive'] as bool? ?? true,
      );
}

/// ASSUMED endpoints: /admin/dashboard, /admin/events, /admin/users (from the
/// prompt) plus POST /events/:id/approve|reject (NOT in the prompt: confirm).
class SuperAdminRepository {
  SuperAdminRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> dashboard() => guarded(() async {
        final r = await _dio.get('/admin/dashboard');
        return ((r.data['data'] ?? r.data) as Map).cast<String, dynamic>();
      });

  Future<Paged<Event>> pendingEvents(int page) => fetchPaged(
      _dio, '/admin/events', Event.fromJson,
      page: page, query: {'status': 'PENDING_APPROVAL'});

  Future<void> approve(String id) =>
      guarded(() => _dio.post('/events/$id/approve'));
  Future<void> reject(String id, String reason) =>
      guarded(() => _dio.post('/events/$id/reject', data: {'reason': reason}));

  Future<Paged<AdminUser>> users(int page, {String? search}) => fetchPaged(
      _dio, '/admin/users', AdminUser.fromJson,
      page: page, query: {if (search != null && search.isNotEmpty) 'search': search});

  Future<void> setActive(String id, bool active) =>
      guarded(() => _dio.patch('/admin/users/$id', data: {'isActive': active}));
}

final superAdminRepositoryProvider =
    Provider((ref) => SuperAdminRepository(ref.watch(dioProvider)));

final _dashboardProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(superAdminRepositoryProvider).dashboard());

void _snack(BuildContext c, Object e) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e')));

class SuperAdminHome extends ConsumerStatefulWidget {
  const SuperAdminHome({super.key});
  @override
  ConsumerState<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends ConsumerState<SuperAdminHome> {
  int _i = 0;
  static const _titles = ['Tableau de bord', 'Validation', 'Utilisateurs'];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_titles[_i]), actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authStateProvider.notifier).logout()),
        ]),
        body: IndexedStack(index: _i, children: const [
          _DashboardTab(),
          _PendingEventsTab(),
          _UsersTab(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Stats'),
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Validation'),
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'Utilisateurs'),
          ],
        ),
      );
}

/// Shows every numeric value of /admin/dashboard as a tile, so it keeps
/// working if the backend adds counters. Lists/maps are ignored for now.
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(_dashboardProvider).when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
                message: '$e', onRetry: () => ref.invalidate(_dashboardProvider)),
            data: (d) {
              final nums = d.entries.where((e) => e.value is num).toList();
              return GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final e in nums)
                    Card(
                        child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${e.value}',
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(e.key),
                    ]))),
                ],
              );
            },
          );
}

class _PendingEventsTab extends ConsumerStatefulWidget {
  const _PendingEventsTab();
  @override
  ConsumerState<_PendingEventsTab> createState() => _PendingState();
}

class _PendingState extends ConsumerState<_PendingEventsTab> {
  int _reload = 0;

  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
      if (mounted) setState(() => _reload++);
    } catch (e) {
      if (mounted) _snack(context, e);
    }
  }

  Future<String?> _askReason() {
    final c = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('Motif du refus'),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
                FilledButton(
                    onPressed: () => Navigator.pop(d, c.text.trim()),
                    child: const Text('Refuser')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(superAdminRepositoryProvider);
    return PagedListView<Event>(
      key: ValueKey(_reload),
      fetch: repo.pendingEvents,
      emptyMessage: 'Aucun événement en attente',
      itemBuilder: (c, e) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: Theme.of(c).textTheme.titleMedium),
            Text(e.location ?? ''),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () async {
                    final r = await _askReason();
                    if (r != null && r.isNotEmpty) await _act(() => repo.reject(e.id, r));
                  },
                  child: const Text('Refuser')),
              FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
                  onPressed: () => _act(() => repo.approve(e.id)),
                  child: const Text('Approuver')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersState();
}

class _UsersState extends ConsumerState<_UsersTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(superAdminRepositoryProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Rechercher un utilisateur'),
          onSubmitted: (v) => setState(() => _q = v.trim()),
        ),
      ),
      Expanded(
        child: PagedListView<AdminUser>(
          key: ValueKey(_q),
          fetch: (p) => repo.users(p, search: _q),
          emptyMessage: 'Aucun utilisateur',
          itemBuilder: (c, u) => _UserTile(user: u),
        ),
      ),
    ]);
  }
}

class _UserTile extends ConsumerStatefulWidget {
  const _UserTile({required this.user});
  final AdminUser user;
  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  late bool _active = widget.user.isActive;
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Card(
        child: SwitchListTile(
          title: Text(widget.user.name.isEmpty ? widget.user.email : widget.user.name),
          subtitle: Text('${widget.user.email} · ${widget.user.role}'),
          value: _active,
          onChanged: _busy
              ? null
              : (v) async {
                  setState(() => _busy = true);
                  try {
                    await ref.read(superAdminRepositoryProvider).setActive(widget.user.id, v);
                    if (mounted) setState(() => _active = v);
                  } catch (e) {
                    if (mounted) _snack(context, e);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      );
}
