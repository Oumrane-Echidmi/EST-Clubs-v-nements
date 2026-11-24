# Integration handoff

The backend contract is [API.md](API.md) and [openapi.json](openapi.json). Swagger runs at `/api/docs`. See [TASKS.md](TASKS.md) for verified readiness and limitations.

Mobile API_BASE_URL includes `/api`: Android emulator `http://10.0.2.2:3000/api`; desktop `http://localhost:3000/api`; physical device uses the development machine's LAN address. Configure backend PUBLIC_BASE_URL separately to the reachable origin for images, and CORS_ORIGINS for Flutter web. Native mobile does not use browser CORS.

Use seed account emails from backend/README.md and the local SEED_PASSWORD. Never embed that password in the Flutter app. Login/register/refresh return data.user, data.accessToken, data.refreshToken and data.expiresIn. All requests use the shared success/error envelope, except calendar and image bytes. Keep access/refresh tokens in secure storage. Serialize refresh calls and do not blindly retry refresh after an unknown result.

Flutter can now target the routes in OpenAPI. Events include registrationId, canRegister, canCancel, registrationState, phase, serverTime and derived counts. Nullable output fields must be handled. Refetch event details and registration lists after state changes. Upload multipart field is `file`, query kind=avatar/poster/logo; poster/logo also require clubId. The returned URL is an absolute public WebP URL.

The missing original architecture v2 must be compared with the provisional choices documented in API.md. API contract changes should be agreed here before implementation. No mobile source or screens were changed by the backend implementation, and no end-to-end Flutter integration has been claimed.

## Mobile assumptions to reconcile after merge

The mobile commits on GitHub main were inspected before backend merge. They were developed before the API contract existed. Frontend ownership is preserved; the following changes belong to the mobile integration pass:

- Event.fromJson and EventInput currently use startAt/endAt; the API uses startsAt/endsAt. Current registration field is registrationId rather than myRegistrationId.
- Auth register/profile code assumes fullName. API requests use firstName/lastName; responses expose those fields. Reset and change-password use password rather than newPassword.
- Club-admin event creation must include category and registrationDeadline. The backend requires both. Admin ownership is ClubMember-based; AuthUser.clubId is not a backend field. The frontend needs to select its ADMIN memberships instead of assuming a single club ID.
- Mobile moderation assumes POST approve/reject; backend routes are PATCH /events/{id}/approve and PATCH /events/{id}/reject.
- Poster/logo uploads must supply clubId query in addition to kind; avatars only require kind.
- Home returns paginated section objects. Adapt HomeData to upcomingEvents, featuredClubs, announcements and recommendedEvents, each with data/meta.
- Dashboard counters are nested under data.counts. Review the other user/club fields against OpenAPI.

These differences are documented before any compatibility changes. No live Flutter/API integration was executed and no mobile files were changed by this backend stream.
