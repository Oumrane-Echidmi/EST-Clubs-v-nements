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
- Event model, EventCard (poster-first), StatusChip, CountdownChip, shared 1s tickerProvider + tests (11 tests total, passing)

## Done (student flow)
- Reusable PagedListView (loading/error+retry/empty/pull-to-refresh/infinite scroll), Paged + fetchPaged helpers
- Clubs tab + club detail (follow/unfollow, club events), Events tab + search, event detail with backend registrationState, countdown, register/cancel confirm dialogs (no double submit, reload after), My registrations (3 tabs), Home (/home), Profile + logout
- Club admin: own-club event list (status + rejection reason), create/edit/delete event with client validation (assumed endpoints: GET /clubs/:id/events, POST /events, PATCH+DELETE /events/:id; AuthUser.clubId from /auth/me)
- Notifications center + unread badge (student app bar); Super admin: stats tiles, pending-event approve/reject (reason), user search + activate/deactivate. Assumed endpoints incl. POST /events/:id/approve|reject (NOT in prompt: ask backend dev)
- Profile edit (name, student ID), change password, avatar upload with image validation + progress (ProfileRepository.uploadImage reusable for poster/logo; poster/logo UI not wired yet)
- Add-to-calendar button (add_2_calendar, shown when REGISTERED; .ics fallback is a TODO) and poster upload in event form
- Club admin registrants screen (mark ATTENDED, cancel registration)
- Event detail widget tests (OPEN confirm/decline, FULL, REGISTERED cancel with backend canCancel)
- 29 tests passing

## Next (priority order)
1. Splash/onboarding polish to match login-onboarding.html; AppButton; category/club/date filters on lists
2. Club admin: Stitch dashboard stats UI (club-admin-dashboard.html); event list/CRUD already done
3. P1 remaining: club info editor + logo upload, .ics fallback (needs url_launcher or download), notification preferences, super admin club management + role assignment + assign club admins
4. P2: firebase_messaging (optional, must work without config), l10n ARB fr/en/ar, Plus Jakarta Sans + Inter fonts
5. When backend publishes docs/openapi.json: verify ALL assumed field names/endpoints (auth_repository, event.dart, clubs_repository, home_tab HomeData, registrations status values), consider freezed models

## Blockers / notes
- No backend / openapi.json in repo yet; nothing was tested against a real API.
- 10 lint infos remain (parameter names in interceptor, underscores in router) — cosmetic.
- No emulator smoke test run.
