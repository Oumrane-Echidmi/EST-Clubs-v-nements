import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/auth_forms.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/shell_screen.dart';

String _homeFor(String role) => role == 'STUDENT'
    ? '/student'
    : role == 'CLUB_ADMIN'
        ? '/club-admin'
        : '/super-admin';

/// Pure redirect logic, unit-testable. The server stays the authority on authz.
String? redirectFor(
    {required bool loading, required String? role, required String location}) {
  if (loading) return location == '/splash' ? null : '/splash';
  if (role == null) {
    // Pages a signed-out user may open.
    const publicPaths = ['/login', '/register', '/forgot-password', '/reset-password'];
    return publicPaths.contains(location) ? null : '/login';
  }
  if (location == '/login' || location == '/splash') return _homeFor(role);
  if (location.startsWith('/club-admin') && role == 'STUDENT') {
    return '/student';
  }
  if (location.startsWith('/super-admin') && role != 'SUPER_ADMIN') {
    return _homeFor(role);
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (_, s) {
      final a = ref.read(authStateProvider);
      return redirectFor(
          loading: a.loading, role: a.user?.role, location: s.matchedLocation);
    },
    routes: [
      GoRoute(
          path: '/splash',
          builder: (_, __) => const Scaffold(
              body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/student', builder: (_, __) => const StudentShell()),
      GoRoute(
          path: '/club-admin',
          builder: (_, __) => const PlaceholderScreen('Espace club')),
      GoRoute(
          path: '/super-admin',
          builder: (_, __) => const PlaceholderScreen('Administration')),
    ],
  );
});
