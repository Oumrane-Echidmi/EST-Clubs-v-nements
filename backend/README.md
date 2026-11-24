# Backend installation

Requires Node.js 24 LTS, npm 11, Docker Desktop with Compose, and PostgreSQL 17 (provided by Compose).

From backend/:

1. Copy .env.example to .env. Set a random JWT_SECRET (at least 32 characters), strong POSTGRES_PASSWORD, matching DATABASE_URL and TEST_DATABASE_URL credentials, and a strong SEED_PASSWORD. Keep these local. Choose allowed CORS_ORIGINS and a PUBLIC_BASE_URL reachable by the mobile device.
2. Run `npm ci --ignore-scripts`. Dependency lifecycle scripts are deliberately disabled by .npmrc. Prisma generation explicitly downloads its matching engine. bcrypt and sharp use packaged platform binaries; no blanket lifecycle-script approval is needed.
3. From the repository root run `docker compose --env-file backend/.env --profile test up -d --wait`.
4. From backend/ run `npm run prisma:generate`, `npm run db:migrate`, and `npm run db:seed`.
5. Run `npm run build` then `npm start`.

API: http://localhost:3000/api. Swagger: http://localhost:3000/api/docs. Runtime OpenAPI JSON: http://localhost:3000/api/docs/openapi.json. Run `npm run openapi` to update docs/openapi.json.

Commands call Node entry points directly because Windows cmd shims fail on the ampersand in this workspace path. These scripts also work on Unix. To watch runtime changes run `npm run start:dev`; rebuild TypeScript after source edits or run `node node_modules/typescript/bin/tsc -p tsconfig.build.json --watch` in a second terminal.

For a new migration: `node node_modules/prisma/build/index.js migrate dev --name descriptive_name`. Production applies checked-in migrations with `npm run db:migrate`. Never edit an applied migration. Database CHECK constraints are included in the initial SQL migration and must be preserved.

## Development accounts

The idempotent seed creates these accounts. All use the password supplied through SEED_PASSWORD; there is no password in source code.

| Role                | Email                                                         |
| ------------------- | ------------------------------------------------------------- |
| Super administrator | superadmin@est.example.edu                                    |
| Club administrators | clubadmin1@est.example.edu through clubadmin3@est.example.edu |
| Students            | student1@est.example.edu through student8@est.example.edu     |

The seed creates 6 approved clubs, 1 pending club, 15 events covering approval, rejection, cancellation, completed, ongoing, full, closed and personal registration states, plus follows, announcements and notifications. Rerunning does not duplicate records or reset event dates. It updates seed account password hashes from SEED_PASSWORD. Development seed refuses NODE_ENV=production.

## Verification

Run `npm run lint`, `npm run build`, `npm test`, and `npm run test:e2e`.

Integration tests require TEST_DATABASE_URL whose database name ends in `_test`. They never fall back to the development URL, apply migrations to that isolated database and clean only fixture records. They use real PostgreSQL, real JWT guards and supertest. Email/push/storage boundaries are replaced only inside tests. The capacity race sends 20 requests from distinct signed-in students and requires 5 successes and 15 EVENT_FULL failures with 5 active database rows.

Production must use HTTPS, explicit CORS origins, SMTP, externally managed secrets and a durable uploads volume. The default throttler is process-local: run a single API instance until a shared throttler store is configured. Local image URLs are public random names; profile and event records hold the returned URL. Set PUBLIC_BASE_URL to the host reachable from Android (commonly http://10.0.2.2:3000 for the emulator) or the device network address.

Firebase is optional. Set all three Firebase variables together; the private key supports escaped newlines. Without Firebase, the no-op push implementation is used and in-app notifications still work. Console mail intentionally prints recovery links in development only; production requires SMTP.

See docs/VERIFICATION.md for executed results and limitations.
