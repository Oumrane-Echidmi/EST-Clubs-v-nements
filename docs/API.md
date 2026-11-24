# API contract v1

All JSON routes begin `/api`. Authentication is Bearer JWT; only register, login, refresh, logout, forgot-password, reset-password and generated image files are public. Access tokens default to 900 seconds; refresh tokens default to 30 days. Dates are ISO-8601 UTC. Swagger is `/api/docs`, JSON is `/api/docs/openapi.json`. The checked-in openapi.json defines request validation and response schemas, including nullable fields.

Success: `{"data":{...}}`. Paginated lists: `{"data":[...],"meta":{"page":1,"limit":20,"total":100,"totalPages":5}}`. Errors: `{"error":{"code":"EVENT_FULL","message":"No available seats"}}`. Empty collections return arrays and zero totals. Successful deletion returns a boolean result inside data rather than 204.

Lists accept page (default 1), limit (default 20, maximum 50), sortBy and sortOrder (`asc`/`desc`, default desc). Unknown body or query fields are rejected. Optional request fields are omitted when unused. Nullable response fields are present as null. UUID route parameters are required. Dates in requests must include a timezone. Strings and capacity limits are specified in OpenAPI.

## Roles and routes

S = STUDENT; C = CLUB_ADMIN scoped through ClubMember.role=ADMIN; A = SUPER_ADMIN; Any = any active authenticated user.

| Method      | Path                             | Roles      | Input and behavior                                                                                                                                                             |
| ----------- | -------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| POST        | /auth/register                   | Public     | email, password, firstName, lastName, optional studentId; always STUDENT; returns AuthSession                                                                                  |
| POST        | /auth/login                      | Public     | email, password; returns AuthSession                                                                                                                                           |
| POST        | /auth/refresh                    | Public     | refreshToken; rotates atomically; reuse revokes its entire family                                                                                                              |
| POST        | /auth/logout                     | Public     | refreshToken, optional deviceToken; revokes family and removes matching user device                                                                                            |
| POST        | /auth/forgot-password            | Public     | email; identical generic response whether account exists                                                                                                                       |
| POST        | /auth/reset-password             | Public     | token, password; expiring single-use reset; revokes refresh sessions                                                                                                           |
| GET         | /auth/me                         | Any        | Current public user                                                                                                                                                            |
| GET/PATCH   | /me                              | Any        | Profile: firstName, lastName, studentId, avatarUrl; no role/email changes                                                                                                      |
| PATCH       | /me/password                     | Any        | currentPassword, password; revokes refresh sessions                                                                                                                            |
| PATCH       | /me/notification-preferences     | Any        | notifyNewEvents, notifyRegistrations, notifyEventUpdates, notifyReminders, pushEnabled booleans                                                                                |
| GET         | /clubs                           | Any        | search, category, status; sorts createdAt/name; students see approved clubs only; club admins also see their own pending/rejected clubs                                        |
| POST        | /clubs                           | C/A        | name, description, category, optional logoUrl/contactEmail/websiteUrl/socialUrl; C creates PENDING and is assigned ADMIN membership, A creates APPROVED                        |
| GET         | /clubs/{id}                      | Any        | Visibility enforced; includes isFollowed and counts                                                                                                                            |
| PATCH       | /clubs/{id}                      | C/A        | Partial club fields; C must own club                                                                                                                                           |
| DELETE      | /clubs/{id}                      | A          | Deletes club and dependent content                                                                                                                                             |
| PATCH       | /clubs/{id}/status               | A          | status PENDING/APPROVED/REJECTED, optional rejectionReason/isFeatured; rejection requires reason                                                                               |
| POST/DELETE | /clubs/{id}/follow               | Any        | Idempotent follow/unfollow; following requires approved club                                                                                                                   |
| GET         | /clubs/{id}/events               | Any        | Event list filters and visibility                                                                                                                                              |
| GET         | /clubs/{clubId}/members          | C/A        | Protected paginated members; sort joinedAt                                                                                                                                     |
| POST        | /clubs/{clubId}/members          | C/A        | userId, role MEMBER/ADMIN; only A assigns ADMIN                                                                                                                                |
| DELETE      | /clubs/{clubId}/members/{userId} | C/A        | Only A can remove ADMIN membership                                                                                                                                             |
| GET         | /events                          | Any        | search, category, clubId, status, from, to; sorts startsAt/createdAt/title; only published approved-club events visible to S, own unpublished content visible to C             |
| POST        | /events                          | C/A        | clubId, title, description, category, location, startsAt, endsAt, registrationDeadline, capacity, optional posterUrl; C creates PENDING_APPROVAL, A creates PUBLISHED          |
| GET         | /events/{id}                     | Any        | Event with derived eligibility                                                                                                                                                 |
| PATCH       | /events/{id}                     | C/A        | Partial create fields; capacity changes lock event; major edits by C require approval again                                                                                    |
| DELETE      | /events/{id}                     | C/A        | C must own event club; locks event                                                                                                                                             |
| PATCH       | /events/{id}/approve             | A          | Approves pending/rejected event; notifies followers                                                                                                                            |
| PATCH       | /events/{id}/reject              | A          | rejectionReason required                                                                                                                                                       |
| POST        | /events/{id}/register            | S          | No body; locks event, rejects duplicate/full/closed, reactivates CANCELLED row                                                                                                 |
| DELETE      | /registrations/{id}              | Owner/C/A  | Own registration or scoped club administration; cancellation cutoff applies to all                                                                                             |
| GET         | /me/registrations                | Any        | tab upcoming/completed/cancelled; sort registeredAt; includes event eligibility even when event is pending again                                                               |
| GET         | /events/{id}/registrations       | C/A        | Scoped paginated attendee list; sort registeredAt                                                                                                                              |
| PATCH       | /registrations/{id}              | C/A        | status CONFIRMED/ATTENDED/CANCELLED; attendance requires event started; reactivation checks deadline/capacity                                                                  |
| GET         | /me/notifications                | Any        | Paginated owned notifications; sort createdAt                                                                                                                                  |
| GET         | /me/notifications/unread-count   | Any        | data.count                                                                                                                                                                     |
| PATCH       | /notifications/{id}/read         | Owner      | Marks read; other user's notification returns 404                                                                                                                              |
| PATCH       | /me/notifications/read-all       | Any        | Marks owned unread rows; data.updated                                                                                                                                          |
| POST        | /me/device-tokens                | Any        | token and platform ANDROID/IOS/WEB; device can move between signed-in accounts                                                                                                 |
| DELETE      | /me/device-tokens/{token}        | Any        | URL-encode token; removes only own token                                                                                                                                       |
| POST        | /uploads/image                   | Any/scoped | Multipart file, query kind=poster/logo/avatar; logo/poster additionally require clubId and C/A scope                                                                           |
| GET         | /uploads/files/{filename}        | Public     | Random sanitized WebP file; raw image response                                                                                                                                 |
| GET         | /events/{id}/calendar.ics        | Any        | Same event visibility; raw text/calendar, UTC, RFC escaping/folding                                                                                                            |
| GET         | /admin/dashboard                 | A          | Counts, 30-day daily registrations, top 5 clubs, latest 20 published event fill rates                                                                                          |
| GET         | /admin/users                     | A          | Search email/firstName/lastName; sorts createdAt/email                                                                                                                         |
| PATCH       | /admin/users/{id}                | A          | role and isActive; cannot demote/deactivate oneself                                                                                                                            |
| POST        | /admin/clubs/{id}/admins         | A          | userId; assigns membership and promotes student to CLUB_ADMIN                                                                                                                  |
| GET         | /admin/clubs                     | A          | Club list including moderation states                                                                                                                                          |
| GET         | /admin/events                    | A          | Event list including moderation states                                                                                                                                         |
| GET         | /announcements                   | Any        | clubId, search; sorts createdAt/title; campus and approved-club announcements                                                                                                  |
| POST        | /announcements                   | C/A        | title, body, optional clubId; campus-wide requires A                                                                                                                           |
| DELETE      | /announcements/{id}              | C/A        | Owning club or campus super administration                                                                                                                                     |
| GET         | /home                            | Any        | Paginated upcomingEvents, featuredClubs, announcements, recommendedEvents; common page/limit, sort startsAt; recommendations use categories of follows and prior registrations |

## Event eligibility

Every event JSON response includes registeredCount (CONFIRMED plus ATTENDED), availableSeats, phase, registrationState, serverTime, registrationId (nullable), canCancel and canRegister. Availability is derived, never stored. Counts for lists use one grouped query, with one additional batched query for current-user registrations.

phase is UPCOMING, ONGOING or ENDED. registrationState is REGISTERED for active registration, otherwise NOT_PUBLISHED, ENDED, DEADLINE_PASSED, FULL, CANCELLED_BY_ME or OPEN according to the server's current clock. A CANCELLED_BY_ME event can be registered again when canRegister=true. Flutter should use canRegister/canCancel directly and serverTime for countdown correction. registrationId can refer to a cancelled historical row.

Cancellation is allowed only for CONFIRMED registrations on PUBLISHED events strictly before startsAt minus CANCELLATION_CUTOFF_MINUTES (default 60). ATTENDED cannot be cancelled. Administrators must own the club; they use the same cutoff. Reactivating a cancellation retains the registration ID and increments version. Major fields are clubId, title, description, category, location, dates and capacity; changing these as C on a published event returns it to PENDING_APPROVAL. Poster-only edits retain publication. End must follow start, registration deadline cannot follow start, and capacity must be positive. Both application checks and SQL CHECK constraints enforce these rules.

A registration transaction locks the event row using SELECT FOR UPDATE before checking publication/deadline, duplicate registration, active count and capacity. Cancellation, attendance/reactivation, capacity edits, moderation and event deletion take the same lock. Notifications run after commit; delivery errors do not roll back successful registration.

## Authentication and errors

Passwords require 8-72 characters with a letter and digit, at most 72 UTF-8 bytes because bcrypt truncates longer input. bcrypt uses cost 12. Public registration rejects role fields. Database roles and isActive are reloaded for every authenticated request. Logout/password change/reset revoke refresh sessions; already-issued access JWTs remain usable until their short expiry unless the account is deactivated. Refresh tokens are 48 random bytes, represented as 96 hex characters; only SHA-256 hashes are stored. Rotation and reuse detection serialize on the user row, and family revocation commits before returning 401. Use single-flight refresh on mobile; racing the same refresh token revokes the family by design.

| HTTP | Stable error codes                                                                                                                          |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 400  | VALIDATION_ERROR, INVALID_RESET_TOKEN                                                                                                       |
| 401  | UNAUTHORIZED, INVALID_CREDENTIALS, INVALID_REFRESH_TOKEN                                                                                    |
| 403  | FORBIDDEN                                                                                                                                   |
| 404  | NOT_FOUND                                                                                                                                   |
| 409  | EVENT_FULL, ALREADY_REGISTERED, REGISTRATION_CLOSED, CANCELLATION_NOT_ALLOWED, CAPACITY_BELOW_REGISTRATIONS, INVALID_EVENT_STATUS, CONFLICT |
| 413  | FILE_TOO_LARGE                                                                                                                              |
| 429  | RATE_LIMITED                                                                                                                                |
| 500  | INTERNAL_ERROR (generic public message)                                                                                                     |

Auth endpoints are limited to 10 requests per 15 minutes per IP and route; other endpoints to 120 per minute. Default throttler is local to one process. Do not configure trust proxy indiscriminately.

State-changing requests do not accept generic idempotency keys. Follow/unfollow, read-all, logout, device registration/removal and repeated same-status cancellation are idempotent. Registration retries receive ALREADY_REGISTERED. Refresh and reset are single-use: do not retry automatically after an unknown outcome. Creation requests can duplicate on blind retry; refetch before retrying.

## Upload format

`POST /api/uploads/image?kind=poster&clubId={uuid}` with Authorization and multipart `file`. Maximum 5 MiB; JPEG/PNG/WebP only; declared MIME must match actual magic bytes. The decoder limits image pixels, strips metadata and reencodes to WebP under a random UUID filename. Returns `{"data":{"url":"http://host:3000/api/uploads/files/{uuid}.webp","mimeType":"image/webp","size":12345}}`. Avatar uploads require any active user; poster/logo uploads require club administration. Stored images are public; don't upload sensitive documents. Local uploads require a persistent volume for deployment.

## Notifications and provisional v2 choices

Preferences gate in-app rows and push delivery. Database uniqueness is `(userId,dedupeKey)`. Only a newly inserted row triggers push. Dedupe keys: `new-event:{eventId}`, `registration-confirmed:{registrationId}:{version}`, `registration-cancelled:{registrationId}:{version}`, `event-updated:{eventId}:{revision}`, and mandated `reminder-24h:{eventId}` / `reminder-1h:{eventId}`. Reminders run every five minutes with an overlapping ten-minute window. In-app delivery works without Firebase. Push failures are logged without tokens.

The full architecture v2 was absent. Category enum (TECHNOLOGY, SCIENCE, CULTURE, SPORTS, SOCIAL, ENTREPRENEURSHIP), ClubStatus (PENDING, APPROVED, REJECTED), MemberRole (ADMIN, MEMBER), profile fields, moderation/member route names, cancellation default and non-reminder dedupe keys are provisional integration choices. All models, constraints, relationships, cascading deletes and indexes are visible in prisma/schema.prisma. Compare these choices with v2 before freezing a production contract.

## Examples

Registration response, abbreviated:

```json
{
  "data": {
    "id": "registration-uuid",
    "status": "CONFIRMED",
    "event": {
      "id": "event-uuid",
      "capacity": 5,
      "registeredCount": 1,
      "availableSeats": 4,
      "phase": "UPCOMING",
      "registrationState": "REGISTERED",
      "serverTime": "2026-11-24T10:00:00.000Z",
      "registrationId": "registration-uuid",
      "canCancel": true,
      "canRegister": false
    }
  }
}
```

Full-event response:

```json
{ "error": { "code": "EVENT_FULL", "message": "No available seats" } }
```

## Club administrator discovery and dashboard (additive contract)

The next backend increment adds two routes without renaming existing fields:

- `GET /api/me/clubs`: CLUB_ADMIN or SUPER_ADMIN; returns only clubs where the current user has an ADMIN ClubMember row, including pending/rejected clubs. Uses the normal Club list schema and pagination; supports category/status/search and sorts createdAt/name. A super administrator's unassigned campus clubs remain available through /api/admin/clubs. A user with no ADMIN memberships receives an empty page.
- `GET /api/clubs/{id}/dashboard`: owning CLUB_ADMIN or SUPER_ADMIN. Returns `clubId`, counts (`members`, `followers`, `events`, `publishedEvents`, `pendingEvents`, `activeRegistrations`) and up to 20 upcoming published `eventFillRates`, each containing `eventId`, `title`, `startsAt`, `capacity`, `registeredCount`, `availableSeats` and `fillRate` (0-1). Registrations count CONFIRMED and ATTENDED; cancelled registrations are excluded. Event fill rates are grouped, without per-event count queries. Students cannot access this resource; foreign club administrators receive FORBIDDEN.

The dashboard is a bounded aggregate rather than a general event list; use /clubs/{id}/events for paginated events. Authorization is checked against current database roles and ADMIN memberships. Membership removal/demotion immediately removes discovery and protected club access. Event `canRegister` is false for administrators because the register route is student-only.
