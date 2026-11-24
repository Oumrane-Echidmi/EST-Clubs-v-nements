import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/paged.dart';
import '../../core/widgets/paged_list.dart';
import '../auth/presentation/auth_providers.dart';

class AppNotification {
  AppNotification(this.id, this.title, this.body, this.isRead, this.eventId);
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String? eventId; // used to open the related event

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        '${j['id']}',
        '${j['title'] ?? ''}',
        '${j['body'] ?? j['message'] ?? ''}',
        j['isRead'] as bool? ?? j['readAt'] != null,
        j['eventId'] == null ? null : '${j['eventId']}',
      );
}

/// ASSUMED endpoints, taken from the project prompt (verify with openapi).
class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<Paged<AppNotification>> list(int page) =>
      fetchPaged(_dio, '/me/notifications', AppNotification.fromJson, page: page);

  Future<int> unreadCount() => guarded(() async {
        final r = await _dio.get('/me/notifications/unread-count');
        final d = r.data['data'] ?? r.data;
        return (d is Map ? d['count'] : d) as int;
      });

  Future<void> markRead(String id) =>
      guarded(() => _dio.patch('/notifications/$id/read'));

  Future<void> markAllRead() =>
      guarded(() => _dio.patch('/me/notifications/read-all'));
}

final notificationsRepositoryProvider =
    Provider((ref) => NotificationsRepository(ref.watch(dioProvider)));

/// Unread badge number. `ref.invalidate(unreadCountProvider)` to refresh.
final unreadCountProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.watch(notificationsRepositoryProvider).unreadCount());

/// Bell icon with unread badge; place it in an AppBar.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await context.push('/notifications');
        ref.invalidate(unreadCountProvider);
      },
      icon: Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          child: const Icon(Icons.notifications_outlined)),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(notificationsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(
            onPressed: () async {
              await repo.markAllRead();
              if (mounted) setState(() => _reload++);
            },
            child: const Text('Tout lire')),
      ]),
      body: PagedListView<AppNotification>(
        key: ValueKey(_reload),
        fetch: repo.list,
        emptyMessage: 'Aucune notification',
        itemBuilder: (c, n) => Card(
          child: ListTile(
            leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active),
            title: Text(n.title,
                style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text(n.body),
            onTap: () async {
              await repo.markRead(n.id);
              if (n.eventId != null && c.mounted) c.push('/events/${n.eventId}');
            },
          ),
        ),
      ),
    );
  }
}
