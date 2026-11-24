# EST Clubs & Events

Campus clubs and event management application for École Supérieure de Technologie (EST). Students can discover clubs, follow organizers, register for events and manage their registrations. Club administrators manage their own activities, while super administrators moderate clubs, events and users.

The repository contains a Flutter mobile application and a NestJS REST API backed by PostgreSQL and Prisma.

## Project structure

```text
backend/             NestJS API, Prisma schema, migrations, seed and automated tests
mobile/              Flutter application and mobile tests
docs/                API contract, integration notes, verification and design references
docker-compose.yml   Development PostgreSQL and a separate test database
```

## Features

- JWT authentication, rotating refresh tokens, password recovery and profile management.
- Role-based permissions for students, club administrators and super administrators.
- Club discovery, following, membership management and moderation.
- Event creation, approval, search and server-calculated registration eligibility.
- Transactional registrations with PostgreSQL row locks to prevent overbooking.
- In-app notifications, optional Firebase push and scheduled event reminders.
- Durable registration notification delivery with crash recovery and retry backoff.
- Image uploads, calendar exports, announcements and personalized recommendations.
- Administration statistics and a documented REST API.

Backend endpoints are implemented and tested. The mobile app has been reconciled with the API contract and exercised against a running backend by `mobile/test/live_api_test.dart` (see [docs/TASKS.md](docs/TASKS.md) for status and limitations).

**Quick check of the integration:** with the backend running and seeded, run `cd mobile && flutter test test/live_api_test.dart --dart-define=LIVE_API=http://localhost:3000/api --dart-define=SEED_PASSWORD=<your SEED_PASSWORD>`.

## Requirements

- Node.js 24 LTS and npm 11.
- Docker Desktop with Docker Compose, or PostgreSQL 17.
- Flutter SDK for running the mobile application; see [mobile instructions](mobile/README.md).

## Run the backend

From the repository root, copy the environment example:

```powershell
Copy-Item backend/.env.example backend/.env
```

On macOS/Linux, use `cp backend/.env.example backend/.env`.

Edit `backend/.env` before continuing:

- Set a random `JWT_SECRET` of at least 32 characters.
- Set `POSTGRES_PASSWORD` and use the same database credentials in `DATABASE_URL` and `TEST_DATABASE_URL`.
- Use separate database names for development and testing; the test database name must end in `_test`.
- Set `SEED_PASSWORD` to a password containing a letter and number, with at least eight characters.
- Configure `CORS_ORIGINS` and a `PUBLIC_BASE_URL` reachable from the mobile device.

Environment files are ignored by Git. Keep actual passwords, tokens and Firebase credentials out of source control.

Start PostgreSQL from the repository root:

```bash
docker compose --env-file backend/.env --profile test up -d --wait
```

Install and start the API:

```bash
cd backend
npm ci --ignore-scripts
npm run prisma:generate
npm run db:migrate
npm run db:seed
npm run build
npm start
```

| Resource     | Default address                             |
| ------------ | ------------------------------------------- |
| REST API     | http://localhost:3000/api                   |
| Swagger UI   | http://localhost:3000/api/docs              |
| OpenAPI JSON | http://localhost:3000/api/docs/openapi.json |

Firebase is optional. Without Firebase credentials, in-app notifications remain available through the no-op push implementation. Development password recovery uses console mail; production requires SMTP.

See the [backend README](backend/README.md) for configuration, migrations, storage and deployment considerations.

## Development accounts

The idempotent development seed creates the following accounts. Each uses the password you supply through `SEED_PASSWORD`.

| Role                | Accounts                                                          |
| ------------------- | ----------------------------------------------------------------- |
| Super administrator | `superadmin@est.example.edu`                                      |
| Club administrators | `clubadmin1@est.example.edu` through `clubadmin3@est.example.edu` |
| Students            | `student1@est.example.edu` through `student8@est.example.edu`     |

The seed also creates six approved clubs, one pending club, 15 events, registrations, announcements and notifications. It is disabled in production.

## Run the mobile application

With Flutter installed and the API running:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Android emulators reach the host machine at `10.0.2.2`. Use `http://localhost:3000/api` for a desktop client, or the host machine's LAN address for a physical device. Set the backend's `PUBLIC_BASE_URL` to an address the same device can reach for uploaded images.

See [mobile setup](mobile/README.md) and the [integration handoff](docs/INTEGRATION.md) before testing the complete application.

## Verification

From `backend/`:

```bash
npm run lint
npm run build
npm test
npm run test:e2e
npm run openapi
```

With a running API and seeded development database, run `npm run test:smoke` for the curl-based registration and approval flow.

The completed backend verification recorded:

- 10 passing unit tests and 55 passing PostgreSQL integration tests.
- A capacity race with 20 distinct students: exactly five successful registrations, 15 `EVENT_FULL` responses and five active database registrations.
- Successful migrations, two idempotent seed runs, lint, build and OpenAPI export.
- A successful live curl smoke test covering registration, cancellation, seat availability, event approval and follower notifications.

For mobile checks, run `flutter analyze` and `flutter test` from `mobile/`. Mobile verification and remaining work are tracked separately in [TASKS.md](docs/TASKS.md).

## Documentation and current limitations

| Document                                     | Contents                                                              |
| -------------------------------------------- | --------------------------------------------------------------------- |
| [API contract](docs/API.md)                  | Routes, permissions, envelopes, pagination, errors and business rules |
| [OpenAPI specification](docs/openapi.json)   | Machine-readable request and response schemas                         |
| [Integration notes](docs/INTEGRATION.md)     | Mobile connection settings and API differences to reconcile           |
| [Project status](docs/TASKS.md)              | Frontend and backend handoffs and remaining work                      |
| [Verification results](docs/VERIFICATION.md) | Executed checks and operational limitations                           |
| [Security review](docs/SECURITY.md)          | Remaining Prisma CLI dependency advisory and mitigation               |

The referenced original architecture v2 was not supplied; provisional contract choices are identified in the API documentation. Live SMTP/FCM delivery has not been verified, and the Flutter app has been exercised against the API only through repository-level live tests (no emulator run yet). Registration in-app notifications use a durable outbox; push and other notification categories remain best effort. The default rate limiter is process-local, and local uploads need durable storage for deployment. The dependency audit has a documented unresolved advisory through Prisma CLI configuration.
