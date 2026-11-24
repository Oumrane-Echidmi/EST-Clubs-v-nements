# Integration handoff

The backend contract is [API.md](API.md) and [openapi.json](openapi.json). Swagger runs at `/api/docs`. See [TASKS.md](TASKS.md) for verified readiness and limitations.

Mobile API_BASE_URL includes `/api`: Android emulator `http://10.0.2.2:3000/api`; desktop `http://localhost:3000/api`; physical device uses the development machine's LAN address. Configure backend PUBLIC_BASE_URL separately to the reachable origin for images, and CORS_ORIGINS for Flutter web. Native mobile does not use browser CORS.

Use seed account emails from backend/README.md and the local SEED_PASSWORD. Never embed that password in the Flutter app. Login/register/refresh return data.user, data.accessToken, data.refreshToken and data.expiresIn. All requests use the shared success/error envelope, except calendar and image bytes. Keep access/refresh tokens in secure storage. Serialize refresh calls and do not blindly retry refresh after an unknown result.

Flutter can now target the routes in OpenAPI. Events include registrationId, canRegister, canCancel, registrationState, phase, serverTime and derived counts. Nullable output fields must be handled. Refetch event details and registration lists after state changes. Upload multipart field is `file`, query kind=avatar/poster/logo; poster/logo also require clubId. The returned URL is an absolute public WebP URL.

The missing original architecture v2 must be compared with the provisional choices documented in API.md. API contract changes should be agreed here before implementation. No mobile source or screens were changed by the backend implementation, and no end-to-end Flutter integration has been claimed.

## Initial mobile assumptions and upstream reconciliation

The following list records the initial differences found before the first backend merge. Newer mobile commits now reconcile these names/routes, consume /me/clubs and report six passing repository-level live API tests. Those results belong to the frontend stream; no Flutter tests were rerun by this backend increment. The new scoped dashboard is available for the next UI integration pass:

- Event.fromJson and EventInput currently use startAt/endAt; the API uses startsAt/endsAt. Current registration field is registrationId rather than myRegistrationId.
- Auth register/profile code assumes fullName. API requests use firstName/lastName; responses expose those fields. Reset and change-password use password rather than newPassword.
- Club-admin event creation must include category and registrationDeadline. The backend requires both. Admin ownership is ClubMember-based; AuthUser.clubId is not a backend field. The frontend should use GET /api/me/clubs to select its ADMIN memberships instead of assuming a single club ID.
- Mobile moderation assumes POST approve/reject; backend routes are PATCH /events/{id}/approve and PATCH /events/{id}/reject.
- Poster/logo uploads must supply clubId query in addition to kind; avatars only require kind.
- Home returns paginated section objects. Adapt HomeData to upcomingEvents, featuredClubs, announcements and recommendedEvents, each with data/meta.
- Dashboard counters are nested under data.counts. Review the other user/club fields against OpenAPI.

These initial differences remain documented for reference. No mobile files were changed by this backend stream.

## Backend club administrator increment

Ready backend routes: `GET /api/me/clubs` discovers the caller's ADMIN memberships and supports normal club filters/pagination; `GET /api/clubs/{id}/dashboard` supplies scoped counts and up to 20 chronological event fill rates. The discovery response uses the existing paginated Club schema. This provides a real route for club selection instead of the mobile assumption that AuthUser has one clubId. Other field/route mismatches above still require the frontend integration pass.

Upstream compatibility is preserved: /me/clubs keeps data as an array, returns an empty page for students and places approved clubs first by default. Pagination metadata and query parameters are additive. Mobile currently reads the first page; a user managing more than 20 clubs should paginate (up to 50 per request).
