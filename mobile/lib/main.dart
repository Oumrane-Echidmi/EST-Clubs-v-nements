import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: EstApp()));

class EstApp extends ConsumerWidget {
  const EstApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'EST Clubs & Événements',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('fr'),
        routerConfig: ref.watch(routerProvider),
      );
}
