# Verification results

Executed on Windows, Node 24.22.0, npm 11.20.0, Docker 29.6.2, Docker Compose 5.3.1, PostgreSQL 17.

- Development and separate test PostgreSQL containers started and passed health checks.
- Initial SQL migration applied to development and test databases; subsequent deploy reports no pending migrations.
- Development seed ran twice. Counts remained 12 users, 7 clubs and 15 events.
- Unit tests: 10 passed (configuration, event eligibility, UTC calendar escaping and UTF-8 folding).
- First complete integration run: 24 passed, including the mandatory 20-student race with exactly 5 successes, exactly 15 EVENT_FULL responses and exactly 5 active registration rows.
- Added regression tests for administrator membership protection, post-commit notification failure, invalid input, attendance occupancy and unchanged UTC dates. The unchanged-date test reproduced an unnecessary reapproval bug; comparison was corrected to use timestamps.
- Live curl smoke passed: seed login, club-admin event creation, super-admin approval, follower notification, published detail, registration, decreased seat availability, cancellation and restored availability. The smoke event was deleted afterward.
- OpenAPI JSON exported with request DTOs, response schemas, role descriptions, nullability, pagination and error envelopes.

Initial backend verification: lint passed, strict TypeScript build passed, 10 unit tests passed, and all 28 PostgreSQL integration tests passed (zero skipped). OpenAPI export succeeded.

## Limitations

- Original architecture v2 was not supplied; provisional choices are listed in API.md and require comparison before contract freeze.
- Flutter integration is pending the frontend developer. No mobile code was modified.
- Live SMTP/FCM were not exercised without external credentials. Automated tests cover their boundaries; no-op push and development mail are implemented.
- Registration confirmation/cancellation now use a durable outbox. Push and publication/update/reminder dispatch remain best effort; in-app deduplication and reminder uniqueness are enforced by PostgreSQL.
- Scheduler windows tolerate short delays, not outages lasting more than the window. Default rate limiting is per process. Local uploads require a durable volume and no automatic orphan cleanup is provided.
- Audit reports three high entries for one underlying Effect advisory through Prisma CLI configuration. Reachability, mitigation and review date are documented in SECURITY.md. This is not a clean audit.
- A Windows command used to print seed counts initially failed during disconnect because of shell interpolation after correctly returning the counts; seed itself succeeded. A first curl attempt was blocked by the sandbox; the permitted rerun passed.

## Club administrator continuation

Added paginated managed-club discovery and a scoped club dashboard with counts and grouped event fill rates. Administrator event responses now correctly return canRegister=false. The new tests first failed against the previous backend, including the reproduced administrator eligibility bug, then passed after implementation.

Latest execution: strict build passed, ESLint/Prettier passed, 10 unit tests passed and 39 PostgreSQL integration tests passed across four suites. The original 20-student registration capacity test remains unchanged and passed. The new dashboard boundary test exercises 22 additional upcoming events and verifies the 20-result cap and chronological ordering. OpenAPI was regenerated. Backend Git attributes now enforce LF to prevent Windows checkout formatting failures.

The continuation curl smoke also passed against the running updated API, including managed-club discovery and scoped dashboard data.

The upstream mobile branch independently introduced /me/clubs while this increment was in progress. Its data-array shape, student empty-list behavior, approved-first default ordering and OpenAPI operation ID were preserved while adding pagination and filters. Compatibility tests failed against the unreconciled branch and passed after the merge. Final merged-source results: 39 PostgreSQL integration tests, 10 unit tests, strict build, lint and the updated live curl smoke all passed. Frontend repository-level integration results are preserved from the mobile developer's commits; Flutter was not rerun by this backend stream.

Review also inverted the administrator eligibility condition temporarily. The regression test failed as expected, the original source was restored, and the final suite passed. Local documentation links were checked and none were missing.

## Durable registration notifications

Latest full run: 55 PostgreSQL integration tests across five suites and 10 unit tests passed, including the unchanged mandatory 20-student capacity race. The 16 new outbox tests cover transaction rollback, failed delivery and worker claims, concurrent duplicate-safe processing, expired and replaced leases, retry backoff, preferences, stale-version suppression, 50-job batches, database constraints and retention without deleting notification history.

The crash-recovery test starts a separate process using the compiled application, waits until registration has committed and notification delivery begins, kills the process, verifies the persisted registration and pending intent, then reclaims the expired lease from another process and verifies notification delivery. This is actual process termination against PostgreSQL, not a mocked transaction or exception substitute.

The additive migration was applied to development and test databases. Prisma migrate diff reported no schema difference. Strict build, lint and OpenAPI export passed. The generated OpenAPI document is unchanged, confirming stable HTTP schemas. Live curl smoke passed for confirmation and cancellation notifications as well as seats, approval and follower notifications.

Review temporarily removed lease ownership from acknowledgements; the stale-lease regression test failed as expected. The source was restored before final verification. Push transport and non-registration notification delivery are not made durable by this increment.
