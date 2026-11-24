# Mobile (Flutter) — status & handoff

Scope of this stream: **frontend only** (`mobile/`). Backend is not started in this repo.

## Toolchain
- Flutter at `C:\Users\PC\flutter` (3.47.9 / Dart 3.13.7); add `flutter/bin` to PATH.
- Run: `cd mobile && flutter pub get && flutter analyze && flutter test`
- API: `--dart-define=API_BASE_URL=...` (defaults 10.0.2.2:3000/api on Android, localhost elsewhere).

## UI source of truth: Stitch
Project "EST Clubs & Événements App" (id 16966480898115530928). Exported HTML in `docs/design/`:
`login-onboarding.html`, `home.html`, `clubs-directory.html`, `club-admin-dashboard.html`
(PNG screenshots could not be downloaded; re-fetch via Stitch MCP `list_screens` with an API key, never commit the key).
Tokens (already in `mobile/lib/core/theme/app_theme.dart`): primary #00236F / container #1E3A8A,
secondary #9D4300 / container #FD761A, surface #F8F9FF, radius 8–16, fonts Plus Jakarta Sans (headlines) + Inter (body).
TODO: bundle the fonts (google_fonts or assets) — not done.

## Done (branch feature/mobile-foundation)
- Scaffold, deps, Material 3 theme from Stitch tokens
- ApiConfig, Dio client, secure token storage, bearer + single-flight 401 refresh (retry once, logout on failure)
- AppException error-code mapping, auth repository (login/me/logout), Riverpod auth state
- GoRouter role-based redirects, login screen (validated), student bottom-nav shell (stub tabs)
- Tests (executed, passing): validators, role redirects, error mapping, concurrent-401 single refresh, refresh failure logout
- Shared LoadingView/EmptyState/ErrorView, RegistrationState enum (7 backend states), server-offset countdown formatter + tests (8 tests total, passing)
- Register, forgot-password, reset-password screens + repository methods; mobile/README.md for juniors (endpoint field names are assumptions until openapi.json)

## Next (priority order, P0 first)
1. Splash + onboarding screens (register, forgot, reset password are DONE; match login-onboarding.html styling still to polish)
2. Remaining widgets: AppButton, EventCard, ClubCard, StatusChip, CountdownChip (use formatCountdown + one shared 1s ticker provider)
3. Home (`home.html`), Clubs (`clubs-directory.html`), Events list/detail with registrationState + countdown (serverTime offset, one shared ticker)
4. Registrations (register/cancel dialogs, 3 tabs)
5. Club admin dashboard (`club-admin-dashboard.html`) + event CRUD
6. P1: notifications, uploads, calendar, profile, super admin. P2: firebase_messaging (NOT added yet; must work without config), l10n ARB fr/en/ar (not set up yet)
7. Typed models: freezed/json_serializable once `docs/openapi.json` exists (backend owner). Auth field names in `auth_repository.dart` are assumptions (`accessToken`, `refreshToken`, `user`) — verify.

## Blockers / notes
- No backend / openapi.json in repo yet; nothing was tested against a real API.
- 10 lint infos remain (parameter names in interceptor, underscores in router) — cosmetic.
- No emulator smoke test run.
