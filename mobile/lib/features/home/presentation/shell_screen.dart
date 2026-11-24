import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';

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

/// Student bottom-nav shell. Tabs are stubs until their features land.
class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key});
  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _i = 0;
  static const _tabs = [
    'Accueil',
    'Clubs',
    'Événements',
    'Mes inscriptions',
    'Profil'
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_tabs[_i])),
        body: Center(child: Text('${_tabs[_i]} — à implémenter')),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Accueil'),
            NavigationDestination(
                icon: Icon(Icons.groups_outlined), label: 'Clubs'),
            NavigationDestination(
                icon: Icon(Icons.event_outlined), label: 'Événements'),
            NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                label: 'Inscriptions'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profil'),
          ],
        ),
      );
}
