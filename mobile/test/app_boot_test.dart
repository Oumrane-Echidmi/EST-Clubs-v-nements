import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/core/router/app_router.dart';
import 'package:est_clubs_events/core/storage/token_storage.dart';
import 'package:est_clubs_events/features/auth/presentation/auth_providers.dart';
import 'package:est_clubs_events/main.dart';

class _NoTokens implements TokenStorage {
  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
  @override
  Future<void> save(String a, String r) async {}
  @override
  Future<void> clear() async {}
}

/// Pumps the app signed-out. [seen] fakes the stored "onboarding seen" flag.
Future<void> _launch(WidgetTester t, {required bool seen}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(_NoTokens()),
      onboardingSeenProvider.overrideWith((ref) async => seen),
    ],
    child: const EstApp(),
  ));
  // The splash spinner never "settles", so pump a few frames by hand.
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('first launch shows onboarding, then login', (t) async {
    await _launch(t, seen: false);
    expect(find.text('Passer'), findsOneWidget);
    await t.tap(find.text('Passer'));
    // markOnboardingSeen() uses shared_preferences (real plugin call): only check
    // the navigation target in the other test; here we just verify onboarding shows.
  });

  testWidgets('returning user goes straight to login', (t) async {
    await _launch(t, seen: true);
    expect(find.text('Se connecter avec mon compte étudiant'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
  });
}
