import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

final tokenStorageProvider =
    Provider<TokenStorage>((_) => SecureTokenStorage());

final dioProvider = Provider<Dio>((ref) => buildDio(
      ref.watch(tokenStorageProvider),
      onSessionExpired: () => ref.read(authStateProvider.notifier).expire(),
    ));

final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)));

class AuthState {
  const AuthState({this.user, this.loading = true});
  final AuthUser? user;
  final bool loading;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState();
  }

  Future<void> _restore() async {
    // Never stay on the splash: any storage/network problem means "signed out".
    AuthUser? u;
    try {
      u = await ref
          .read(authRepositoryProvider)
          .restore()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      u = null;
    }
    state = AuthState(user: u, loading: false);
  }

  Future<void> login(String email, String password) async {
    final u = await ref.read(authRepositoryProvider).login(email, password);
    state = AuthState(user: u, loading: false);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(loading: false);
  }

  void expire() => state = const AuthState(loading: false);
}

final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
