import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clubs/presentation/clubs_screens.dart';
import '../../events/presentation/events_screens.dart';
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

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authStateProvider).user;
    return ListView(padding: const EdgeInsets.all(16), children: [
      ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(u?.fullName ?? u?.email ?? ''),
          subtitle: Text(u?.email ?? '')),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: () => ref.read(authStateProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter')),
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
  static const _titles = ['Accueil', 'Clubs', 'Événements', 'Mes inscriptions', 'Profil'];
  static const _pages = <Widget>[
    HomeTab(),
    ClubsTab(),
    EventsTab(),
    MyRegistrationsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_titles[_i])),
        body: IndexedStack(index: _i, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Clubs'),
            NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Événements'),
            NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'Inscriptions'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
          ],
        ),
      );
}
