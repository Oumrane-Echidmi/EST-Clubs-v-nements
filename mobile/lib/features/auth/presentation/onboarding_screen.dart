import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'onboarding_seen';

/// Has the user already seen the welcome pages?
Future<bool> onboardingSeen() async {
  try {
    final p = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
    return p.getBool(_seenKey) ?? false;
  } catch (_) {
    return true; // cannot read: do not block the app on onboarding
  }
}

Future<void> markOnboardingSeen() async =>
    (await SharedPreferences.getInstance()).setBool(_seenKey, true);

/// Three welcome pages shown once, before the first login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  final _c = PageController();
  int _i = 0;
  static const _pages = [
    (Icons.groups, 'Découvrez les clubs', "Trouvez les clubs de l'EST qui vous ressemblent."),
    (Icons.event, 'Suivez les événements', 'Ne manquez aucun événement du campus.'),
    (Icons.confirmation_number, 'Inscrivez-vous en un geste', 'Réservez votre place et recevez des rappels.'),
  ];

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: _finish, child: const Text('Passer'))),
          Expanded(
            child: PageView(
              controller: _c,
              onPageChanged: (v) => setState(() => _i = v),
              children: [
                for (final p in _pages)
                  Padding(
                    padding: const EdgeInsetsDirectional.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(p.$1, size: 96, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 24),
                      Text(p.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(p.$3, textAlign: TextAlign.center),
                    ]),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: FilledButton(
              onPressed: last
                  ? _finish
                  : () => _c.nextPage(
                      duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              child: Text(last ? 'Commencer' : 'Suivant'),
            ),
          ),
        ]),
      ),
    );
  }
}
