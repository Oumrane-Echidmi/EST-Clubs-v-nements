import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: EstApp()));

class EstApp extends ConsumerWidget {
  const EstApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'EST Clubs & Événements',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // French is the default; English and an Arabic stub live in lib/l10n.
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: ref.watch(routerProvider),
      );
}
