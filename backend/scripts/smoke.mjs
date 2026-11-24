import 'dotenv/config';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
const base =
  process.env.SMOKE_BASE_URL ||
  `http://localhost:${process.env.PORT || 3000}/api`;
function curl(method, path, data, access) {
  // Feed credentials and headers through stdin instead of process arguments or logs.
  const config = [
    `url = ${JSON.stringify(base + path)}`,
    `request = ${JSON.stringify(method)}`,
    'silent',
    'show-error',
    'fail-with-body',
    'header = "Content-Type: application/json"',
  ];
  if (access)
    config.push(
      `header = ${JSON.stringify('Authorization: Bearer ' + access)}`,
    );
  if (data) config.push(`data = ${JSON.stringify(JSON.stringify(data))}`);
  const result = spawnSync(
    process.platform === 'win32' ? 'curl.exe' : 'curl',
    ['--config', '-'],
    { input: config.join('\n'), encoding: 'utf8' },
  );
  if (result.status !== 0)
    throw new Error(
      `HTTP smoke failed: ${method} ${path} (exit ${result.status}): ${result.stderr}`,
    );
  return JSON.parse(result.stdout).data;
}
function main() {
  if (!process.env.SEED_PASSWORD) throw new Error('SEED_PASSWORD is required');
  const login = (email) =>
    curl('POST', '/auth/login', { email, password: process.env.SEED_PASSWORD });
  const student = login('student8@est.example.edu');
  const admin = login('clubadmin1@est.example.edu');
  const superAdmin = login('superadmin@est.example.edu');
  const call = (session, method, path, data) =>
    curl(method, path, data, session.accessToken);
  const clubs = call(admin, 'GET', '/me/clubs?limit=50');
  const club = clubs.find((c) => c.status === 'APPROVED');
  assert.ok(club);
  assert.deepEqual(call(student, 'GET', '/me/clubs'), []);
  call(student, 'POST', `/clubs/${club.id}/follow`);
  const startsAt = new Date(Date.now() + 96 * 3600000).toISOString();
  const event = call(admin, 'POST', '/events', {
    clubId: club.id,
    title: 'Live HTTP smoke test',
    description: 'Verifying the campus API using real curl requests.',
    category: 'TECHNOLOGY',
    location: 'EST Auditorium',
    startsAt,
    endsAt: new Date(Date.now() + 98 * 3600000).toISOString(),
    registrationDeadline: new Date(Date.now() + 94 * 3600000).toISOString(),
    capacity: 5,
  });
  try {
    assert.equal(event.status, 'PENDING_APPROVAL');
    const approved = call(superAdmin, 'PATCH', `/events/${event.id}/approve`);
    assert.equal(approved.status, 'PUBLISHED');
    const dashboard = call(admin, 'GET', '/clubs/' + club.id + '/dashboard');
    assert.equal(dashboard.clubId, club.id);
    assert.ok(dashboard.counts.publishedEvents > 0);
    assert.ok(dashboard.eventFillRates.length <= 20);
    assert.equal(approved.canRegister, false);
    const before = call(student, 'GET', `/events/${event.id}`);
    assert.equal(before.availableSeats, 5);
    const registration = call(student, 'POST', `/events/${event.id}/register`);
    assert.equal(registration.event.availableSeats, 4);
    const after = call(student, 'GET', `/events/${event.id}`);
    assert.equal(after.availableSeats, 4);
    const cancelled = call(
      student,
      'DELETE',
      `/registrations/${registration.id}`,
    );
    assert.equal(cancelled.event.availableSeats, 5);
    const notifications = call(student, 'GET', '/me/notifications?limit=50');
    assert.ok(
      notifications.some(
        (n) => n.eventId === event.id && n.type === 'NEW_EVENT',
      ),
    );
    for (const type of ['REGISTRATION_CONFIRMED', 'REGISTRATION_CANCELLED']) {
      assert.ok(
        notifications.some(
          (notification) =>
            notification.eventId === event.id && notification.type === type,
        ),
      );
    }
    console.log(
      'PASS curl smoke: durable registration notifications, managed clubs, scoped dashboard, login, pending event, approval, follower notification, event detail, registration, decreased seats, cancellation, restored seats.',
    );
  } finally {
    call(superAdmin, 'DELETE', `/events/${event.id}`);
  }
}
try {
  main();
} catch (e) {
  console.error(e.message);
  process.exitCode = 1;
}
