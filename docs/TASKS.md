# Mobile (Flutter) — status & handoff

Scope of this stream: **frontend only** (`mobile/`). Backend status is recorded in the section below.

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
Fonts: Inter + Plus Jakarta Sans bundled in mobile/assets/fonts (variable TTFs, OFL licence).

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
- l10n scaffolding: fr (default) + en ARB, Arabic stub, gen-l10n wired in main; only the login screen uses it so far (other screens still have hardcoded French strings -> migrate gradually)
- One-time onboarding (3 pages, shared_preferences) + first-launch redirect
- Club info editor (description + logo upload) for club admins
- Stitch styling pass 2 (compared against the real Stitch screenshots): hero event card (orange countdown, seats box, orange CTA), compact event cards with seats bar + status chip + action pill, directory-style club cards (banner, category pill, CTA), branded header "EST Clubs UIZ", nav labels Accueil/Clubs/Agenda/Pass/Profil. Pass 3 done: login form card (labels above filled fields, navy CTA), club admin dashboard header (Espace bureau card, orange live-ticketing alert from the fullest event, navy create button). NOT yet styled: category filter chips, club tags/members meta (need backend fields), dashboard stats/QR check-in/scan pass/export (no backend), event detail page. Visual check on a device/emulator still pending.
- 30 tests passing

## Next (priority order)

1. Splash/onboarding polish to match login-onboarding.html; AppButton; category/club/date filters on lists
2. Club admin: Stitch dashboard stats UI (club-admin-dashboard.html); event list/CRUD already done
3. P1 remaining: .ics fallback (needs url_launcher or download), notification preferences, super admin club management + role assignment + assign club admins
4. P2: firebase_messaging (optional, must work without config), l10n ARB fr/en/ar, Plus Jakarta Sans + Inter fonts
5. When backend publishes docs/openapi.json: verify ALL assumed field names/endpoints (auth_repository, event.dart, clubs_repository, home_tab HomeData, registrations status values), consider freezed models

- Pass 4: bundled fonts, category filter chips on Clubs (Tech/Sport/Art/Impact/Social) and Events (Tech & IA/Ateliers/Compétitions) sent as ?category= (ASSUMED param + values), club member count + tags on cards (ASSUMED memberCount, tags[]), .ics fallback (downloads /events/:id/calendar.ics with auth, opens with open_filex)
- Deliberately NOT done (per owner): Firebase push, super admin club management/role assignment

## Mobile <-> backend contract reconciliation (done against docs/API.md + openapi.json)

- Fixed: startsAt/endsAt, registrationId, canRegister/canCancel used directly, firstName/lastName (register, profile, auth), password key on reset/change, PATCH approve/reject with rejectionReason, upload clubId for poster/logo, home sections {data,meta}, dashboard data.counts, /me/registrations?tab=, club isFollowed + _count.members, category enums, required category + registrationDeadline on event create
- Club admin club selection now uses the new backend route GET /me/clubs (added to backend/src/clubs, docs/API.md and openapi.json; verified by the live test).
- Club tags (shown on cards) do not exist in the API: the UI only renders them if a tags field appears.
- Not verified against the live API (no emulator/server run yet). Line endings: mobile Dart files normalised to LF.

## LIVE integration (executed 2026-11-24)

Backend run locally (docker postgres + migrate + seed + npm start), then `mobile/test/live_api_test.dart` ran the app's real repositories and models against it: 6/6 passed (student login/restore/lists/detail/category filter/register/cancel/my registrations/notifications/home; wrong password; club admin own clubs + events + create/edit/delete event; super admin dashboard/pending/users; .ics download).

Run it yourself: start the backend (backend/README.md), then
`flutter test test/live_api_test.dart --dart-define=LIVE_API=http://localhost:3000/api --dart-define=SEED_PASSWORD=<value from backend/.env>`

Notes: auth endpoints are throttled to 10 per 15 min per IP (restart the API to reset while testing). On Windows kill the API by port 3000.

## Build & boot checks (executed)

- `flutter build apk --debug` succeeds (Android SDK 36, manifest has INTERNET + debug-only cleartext for 10.0.2.2); `flutter build web` succeeds and the login screen was rendered in headless Chrome (Stitch look + bundled fonts confirmed visually).
- App boot widget tests: first launch -> onboarding, returning user -> login. Fixed a race where the first-launch onboarding was skipped because the router did not wait for the stored flag.
- NOT done: no Android emulator/device available here, so authenticated screens were not visually inspected; Firebase push and super-admin club management intentionally excluded.

## Blockers / notes

- Backend contract is now available (see below); repository-level live API integration passed in the frontend stream; device/emulator verification remains pending.
- 10 lint infos remain (parameter names in interceptor, underscores in router) — cosmetic.
- No emulator smoke test run.

---

# Backend status and frontend handoff

Backend P0, P1 and P2 are implemented in backend/. API contract: API.md and openapi.json. Installation: backend/README.md. No mobile source was changed by this stream.

## Verified

- Strict TypeScript build and ESLint/Prettier checks passed.
- 10 unit tests passed in the completed unit run; final repetition after review is recorded in VERIFICATION.md.
- Latest PostgreSQL integration run: 55 passed, zero skipped or weakened tests.
- Mandatory capacity race: 20 distinct students, 5 successes, 15 EVENT_FULL failures, exactly 5 active database registrations.
- SQL migrations applied to isolated development/test databases.
- Idempotent seed ran twice: 12 accounts, 7 clubs, 15 events.
- Live curl smoke passed: login, published detail, register/cancel and seat counts, club-admin event creation, super-admin approval and follower notification.
- Swagger and exportable OpenAPI include response models, nullability, envelopes and pagination.

## Integration status

Backend endpoints are ready for the frontend developer to integrate against the published contract. The frontend stream reports six passing repository-level live API tests; device/emulator verification remains pending. The initial contract differences, their upstream reconciliation and the dashboard handoff are documented in INTEGRATION.md.

Original architecture v2 was not supplied. Provisional choices are recorded in API.md. External SMTP/FCM delivery remains unverified without credentials. Prisma CLI's remaining Effect advisory and review deadline are documented in SECURITY.md. Additional operational limitations are in VERIFICATION.md.

## Club administrator backend increment

- Added GET /api/me/clubs for paginated discovery of the caller's ADMIN club memberships, including pending/rejected clubs and normal category/status/search filters.
- Added GET /api/clubs/{id}/dashboard with scoped membership/follower/event/registration totals and up to 20 chronological upcoming event fill rates. Counts use a consistent database snapshot and grouped registrations.
- Corrected event canRegister to remain false for administrators, matching the student-only registration route.
- Added 11 PostgreSQL integration tests covering discovery, role restrictions, membership revocation, accurate occupancy counts, empty dashboards, bounded results and OpenAPI response contracts.
- Build, lint, 10 unit tests and all 39 integration tests passed. No mobile source changed by this stream; upstream mobile code already consumes /me/clubs, whose data-array and approved-first behavior are preserved.

## Registration notification reliability

- Added an additive NotificationOutbox migration and transactionally recorded confirmation/cancellation intents. HTTP response schemas remain unchanged.
- Added immediate post-commit delivery and a once-per-minute worker with 50-job batches, 60-second leases, lease-owner fencing, exponential backoff capped at one hour and 30-day processed-record cleanup.
- Superseded registration versions are skipped; preferences and notification uniqueness still control in-app delivery and push. Push and event publication/update/reminder dispatch remain best effort.
- Added 16 real PostgreSQL integration tests, including a killed child application process, restart recovery, rollback, concurrent workers, stale leases, batch limits and failure isolation. Full suite: 55 integration tests and 10 unit tests passed; the original capacity race remains unchanged.
- Migration applied to development and test databases; Prisma drift check reported no difference. Build, lint, OpenAPI export and the updated live curl confirmation/cancellation smoke passed.
- Apply migrations before restarting the updated API to activate durable delivery. No mobile code changed.
