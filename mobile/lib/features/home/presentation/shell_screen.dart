import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_images.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clubs/presentation/clubs_screens.dart';
import '../../events/presentation/events_screens.dart';
import '../../notifications/notifications.dart';
import 'home_tab.dart';

/// Placeholder for screens that are not built yet (club admin / super admin).
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(title), actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authStateProvider.notifier).logout())
        ]),
        body: Center(child: Text('$title — à implémenter (voir docs/TASKS.md)')),
      );
}

/// Round avatar with the green "online" dot, as in the Stitch header.
class HeaderAvatar extends ConsumerWidget {
  const HeaderAvatar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authStateProvider).user;
    return Stack(clipBehavior: Clip.none, children: [
      CircleAvatar(
          radius: 17,
          backgroundImage:
              photoProvider(url: u?.avatarUrl, asset: profileAvatarAsset)),
      Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5)),
        ),
      ),
    ]);
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authStateProvider).user;
    Widget tile(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: const Color(0xFF1E3A8A)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap);
    final roleLabel = u?.role == 'CLUB_ADMIN'
        ? 'Bureau du club'
        : (u?.role == 'SUPER_ADMIN' ? 'Administrateur' : 'Étudiant EST');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            CircleAvatar(
                radius: 44,
                backgroundImage:
                    photoProvider(url: u?.avatarUrl, asset: profileAvatarAsset)),
            const SizedBox(height: 12),
            Text(u?.fullName ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(u?.email ?? '', style: const TextStyle(color: Color(0xFF444651))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(20)),
              child: Text(roleLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(children: [
          if (u?.role == 'CLUB_ADMIN') ...[
            tile(Icons.shield_outlined, 'Espace bureau du club', () => context.go('/club-admin')),
            const Divider(height: 1),
          ],
          tile(Icons.edit_outlined, 'Modifier le profil', () => context.push('/profile/edit')),
          const Divider(height: 1),
          tile(Icons.lock_outline, 'Changer le mot de passe',
              () => context.push('/profile/password')),
          const Divider(height: 1),
          tile(Icons.notifications_outlined, 'Notifications',
              () => context.push('/notifications')),
        ]),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBA1A1A),
              side: const BorderSide(color: Color(0xFFBA1A1A)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => ref.read(authStateProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter', style: TextStyle(fontWeight: FontWeight.w700))),
    ]);
  }
}

/// Student bottom-nav shell. IndexedStack keeps each tab's state alive.
class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key});
  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _i = 0;
  static const _titles = ['Accueil', 'Clubs', 'Agenda', 'Mes inscriptions', 'Profil'];
  static const _pages = <Widget>[
    HomeTab(),
    ClubsTab(),
    EventsTab(),
    MyRegistrationsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            toolbarHeight: 64,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('EST Clubs'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0x80FFDBCA), borderRadius: BorderRadius.circular(10)),
                  child: const Text('UIZ',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9D4300))),
                ),
              ]),
              Text(_titles[_i],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
            actions: const [NotificationBell(), HeaderAvatar(), SizedBox(width: 12)]),
        body: IndexedStack(index: _i, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Clubs'),
            NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Agenda'),
            NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'Pass'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
          ],
        ),
      );
}
