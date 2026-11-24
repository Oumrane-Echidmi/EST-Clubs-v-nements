import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';
import { CONFIG, Configuration } from '../src/config/environment';
import { PrismaService } from '../src/prisma/prisma.service';
import { NotificationsService } from '../src/notifications/notifications.service';
import { PushService } from '../src/notifications/push.service';
import { Role } from '@prisma/client';
describe('clubs, events and registration invariants (real PostgreSQL)', () => {
  let app: INestApplication,
    db: PrismaService,
    notifications: NotificationsService;
  const suffix = randomUUID();
  let clubId: string, foreignClubId: string, admin: string, superAdmin: string;
  const students: { id: string; token: string }[] = [];
  const pushed: string[] = [];
  const createdClubs: string[] = [];
  const eventInput = (extra: object = {}) => ({
    clubId,
    title: 'Integration event',
    description: 'A real campus integration test event.',
    category: 'TECHNOLOGY',
    location: 'EST auditorium',
    startsAt: new Date(Date.now() + 72 * 3600000).toISOString(),
    endsAt: new Date(Date.now() + 74 * 3600000).toISOString(),
    registrationDeadline: new Date(Date.now() + 70 * 3600000).toISOString(),
    capacity: 5,
    ...extra,
  });
  const api = () => request(app.getHttpServer());
  async function createEvent(extra: object = {}) {
    const response = await api()
      .post('/api/events')
      .auth(superAdmin, { type: 'bearer' })
      .send(eventInput(extra))
      .expect(201);
    return response.body.data.id as string;
  }
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PushService)
      .useValue({
        send: async (_tokens: string[], title: string) => {
          pushed.push(title);
        },
      })
      .compile();
    app = module.createNestApplication();
    const config = app.get<Configuration>(CONFIG);
    configureApp(app, config);
    await app.init();
    db = app.get(PrismaService);
    notifications = app.get(NotificationsService);
    const hash = await bcrypt.hash('Integration123', 12),
      jwt = app.get(JwtService);
    for (let i = 0; i < 22; i++) {
      const user = await db.user.create({
        data: {
          email: `fixture-${i}-${suffix}@example.edu`,
          passwordHash: hash,
          firstName: 'Test',
          lastName: `User${i}`,
          role:
            i === 20
              ? Role.CLUB_ADMIN
              : i === 21
                ? Role.SUPER_ADMIN
                : Role.STUDENT,
        },
      });
      const token = await jwt.signAsync(
        { sub: user.id },
        {
          secret: config.secret,
          expiresIn: 900,
          issuer: 'est-clubs',
          audience: 'est-mobile',
        },
      );
      if (i < 20) students.push({ id: user.id, token });
      else if (i === 20) admin = token;
      else superAdmin = token;
    }
    const club = await db.club.create({
      data: {
        name: `Main-${suffix}`,
        description: 'Test club description',
        category: 'TECHNOLOGY',
        status: 'APPROVED',
      },
    });
    clubId = club.id;
    createdClubs.push(clubId);
    const foreign = await db.club.create({
      data: {
        name: `Foreign-${suffix}`,
        description: 'Another club description',
        category: 'SPORTS',
        status: 'APPROVED',
      },
    });
    foreignClubId = foreign.id;
    createdClubs.push(foreignClubId);
    const adminUser = await db.user.findUniqueOrThrow({
      where: { email: `fixture-20-${suffix}@example.edu` },
    });
    await db.clubMember.create({
      data: { clubId, userId: adminUser.id, role: 'ADMIN' },
    });
  });
  afterAll(async () => {
    if (db) {
      await db.club.deleteMany({ where: { id: { in: createdClubs } } });
      await db.user.deleteMany({ where: { email: { contains: suffix } } });
    }
    if (app) await app.close();
  });
  it('enforces student, scoped administrator and super administrator permissions', async () => {
    await api()
      .post('/api/clubs')
      .auth(students[0].token, { type: 'bearer' })
      .send({
        name: 'Denied',
        description: 'Denied student creation',
        category: 'SCIENCE',
      })
      .expect(403);
    await api()
      .patch(`/api/clubs/${foreignClubId}`)
      .auth(admin, { type: 'bearer' })
      .send({ name: 'Denied change' })
      .expect(403);
    await api()
      .get(`/api/clubs/${foreignClubId}/members`)
      .auth(admin, { type: 'bearer' })
      .expect(403);
    for (const token of [students[0].token, admin]) {
      for (const path of ['dashboard', 'users', 'clubs', 'events'])
        await api()
          .get(`/api/admin/${path}`)
          .auth(token, { type: 'bearer' })
          .expect(403);
    }
  });
  it('creates, filters, updates and deletes clubs with moderation', async () => {
    const created = await api()
      .post('/api/clubs')
      .auth(admin, { type: 'bearer' })
      .send({
        name: `Pending-${suffix}`,
        description: 'A pending club for moderation',
        category: 'SCIENCE',
      })
      .expect(201);
    const id = created.body.data.id;
    createdClubs.push(id);
    expect(created.body.data.status).toBe('PENDING');
    await api()
      .get(`/api/clubs/${id}`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(404);
    await api()
      .patch(`/api/clubs/${id}`)
      .auth(admin, { type: 'bearer' })
      .send({ description: 'An updated pending club description' })
      .expect(200);
    await api()
      .patch(`/api/clubs/${id}/status`)
      .auth(superAdmin, { type: 'bearer' })
      .send({ status: 'APPROVED' })
      .expect(200);
    const listed = await api()
      .get(`/api/clubs?category=SCIENCE&search=Pending-${suffix}&limit=1`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(200);
    expect(listed.body.meta.total).toBe(1);
    expect(listed.body.data).toHaveLength(1);
    await api()
      .delete(`/api/clubs/${id}`)
      .auth(superAdmin, { type: 'bearer' })
      .expect(200);
  });
  it('requires event approval, denies foreign scope and reapproves major edits', async () => {
    await api()
      .post('/api/events')
      .auth(admin, { type: 'bearer' })
      .send(eventInput({ clubId: foreignClubId }))
      .expect(403);
    const created = await api()
      .post('/api/events')
      .auth(admin, { type: 'bearer' })
      .send(eventInput())
      .expect(201);
    const id = created.body.data.id;
    expect(created.body.data.status).toBe('PENDING_APPROVAL');
    await api()
      .get(`/api/events/${id}`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(404);
    await api()
      .patch(`/api/events/${id}/approve`)
      .auth(admin, { type: 'bearer' })
      .expect(403);
    await api()
      .patch(`/api/events/${id}/reject`)
      .auth(superAdmin, { type: 'bearer' })
      .send({ rejectionReason: 'Please add details' })
      .expect(200);
    await api()
      .patch(`/api/events/${id}`)
      .auth(admin, { type: 'bearer' })
      .send({ title: 'Updated event title' })
      .expect(200);
    await api()
      .patch(`/api/events/${id}/approve`)
      .auth(superAdmin, { type: 'bearer' })
      .expect(200);
    const updated = await api()
      .patch(`/api/events/${id}`)
      .auth(admin, { type: 'bearer' })
      .send({ capacity: 8 })
      .expect(200);
    expect(updated.body.data.status).toBe('PENDING_APPROVAL');
    await api()
      .delete(`/api/events/${id}`)
      .auth(admin, { type: 'bearer' })
      .expect(200);
  });
  it('registers, rejects duplicates, cancels and reactivates the same registration', async () => {
    const id = await createEvent();
    const token = students[0].token;
    const registered = await api()
      .post(`/api/events/${id}/register`)
      .auth(token, { type: 'bearer' })
      .expect(201);
    const r = registered.body.data;
    expect(r.event.availableSeats).toBe(4);
    expect(r.event.registrationId).toBe(r.id);
    expect(r.event.canCancel).toBe(true);
    const duplicate = await api()
      .post(`/api/events/${id}/register`)
      .auth(token, { type: 'bearer' })
      .expect(409);
    expect(duplicate.body.error.code).toBe('ALREADY_REGISTERED');
    await api()
      .delete(`/api/registrations/${r.id}`)
      .auth(students[1].token, { type: 'bearer' })
      .expect(403);
    const cancelled = await api()
      .delete(`/api/registrations/${r.id}`)
      .auth(token, { type: 'bearer' })
      .expect(200);
    expect(cancelled.body.data.event.availableSeats).toBe(5);
    const again = await api()
      .post(`/api/events/${id}/register`)
      .auth(token, { type: 'bearer' })
      .expect(201);
    expect(again.body.data.id).toBe(r.id);
    expect(again.body.data.version).toBe(3);
    const lower = await api()
      .patch(`/api/events/${id}`)
      .auth(superAdmin, { type: 'bearer' })
      .send({ capacity: 1 })
      .expect(200);
    expect(lower.body.data.availableSeats).toBe(0);
    await api()
      .post(`/api/events/${id}/register`)
      .auth(students[1].token, { type: 'bearer' })
      .expect(409)
      .expect((res) => expect(res.body.error.code).toBe('EVENT_FULL'));
  });
  it('rejects expired deadlines and unpublished events', async () => {
    const closed = await createEvent({
      registrationDeadline: new Date(Date.now() - 1000).toISOString(),
    });
    await api()
      .post(`/api/events/${closed}/register`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(409)
      .expect((res) => expect(res.body.error.code).toBe('REGISTRATION_CLOSED'));
    const pending = await api()
      .post('/api/events')
      .auth(admin, { type: 'bearer' })
      .send(eventInput())
      .expect(201);
    await api()
      .post(`/api/events/${pending.body.data.id}/register`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(409)
      .expect((res) => expect(res.body.error.code).toBe('REGISTRATION_CLOSED'));
  });
  it('respects cutoff and prevents reducing capacity below occupancy', async () => {
    const id = await createEvent();
    const responses = await Promise.all(
      students
        .slice(0, 2)
        .map((s) =>
          api()
            .post(`/api/events/${id}/register`)
            .auth(s.token, { type: 'bearer' })
            .expect(201),
        ),
    );
    await api()
      .patch(`/api/events/${id}`)
      .auth(superAdmin, { type: 'bearer' })
      .send({ capacity: 1 })
      .expect(409);
    await db.event.update({
      where: { id },
      data: {
        startsAt: new Date(Date.now() + 1800000),
        registrationDeadline: new Date(Date.now() + 900000),
      },
    });
    await api()
      .delete(`/api/registrations/${responses[0].body.data.id}`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(409)
      .expect((res) =>
        expect(res.body.error.code).toBe('CANCELLATION_NOT_ALLOWED'),
      );
  });
  it('never overbooks: exactly 5 of 20 concurrent requests succeed', async () => {
    const id = await createEvent({ capacity: 5 });
    const results = await Promise.all(
      students.map((s) =>
        api()
          .post(`/api/events/${id}/register`)
          .auth(s.token, { type: 'bearer' }),
      ),
    );
    expect(results.filter((r) => r.status === 201)).toHaveLength(5);
    const failures = results.filter((r) => r.status !== 201);
    expect(failures).toHaveLength(15);
    for (const failure of failures) {
      expect(failure.status).toBe(409);
      expect(failure.body.error.code).toBe('EVENT_FULL');
    }
    expect(
      await db.registration.count({
        where: { eventId: id, status: { in: ['CONFIRMED', 'ATTENDED'] } },
      }),
    ).toBe(5);
  });
  it('deduplicates notifications, respects preferences and sends push only once', async () => {
    const id = await createEvent();
    const before = pushed.length;
    await Promise.all(
      Array.from({ length: 5 }, () =>
        notifications.notify(
          students[0].id,
          'NEW_EVENT',
          id,
          `dedupe:${id}`,
          'Test',
          'Body',
        ),
      ),
    );
    expect(
      await db.notification.count({
        where: { userId: students[0].id, dedupeKey: `dedupe:${id}` },
      }),
    ).toBe(1);
    expect(pushed.length - before).toBe(1);
    await db.user.update({
      where: { id: students[1].id },
      data: { notifyNewEvents: false },
    });
    await notifications.notify(
      students[1].id,
      'NEW_EVENT',
      id,
      `disabled:${id}`,
      'Test',
      'Body',
    );
    expect(
      await db.notification.count({
        where: { userId: students[1].id, dedupeKey: `disabled:${id}` },
      }),
    ).toBe(0);
  });
  it('runs reminder jobs idempotently for 24h and 1h windows', async () => {
    for (const hours of [24, 1]) {
      const now = new Date();
      const id = await createEvent({
        startsAt: new Date(now.getTime() + hours * 3600000).toISOString(),
        endsAt: new Date(now.getTime() + (hours + 2) * 3600000).toISOString(),
        registrationDeadline: now.toISOString(),
      });
      await db.registration.create({
        data: { eventId: id, userId: students[0].id },
      });
      await Promise.all([
        notifications.reminders(now),
        notifications.reminders(now),
      ]);
      expect(
        await db.notification.count({
          where: {
            userId: students[0].id,
            dedupeKey: `reminder-${hours}h:${id}`,
          },
        }),
      ).toBe(1);
    }
  });
  it('delivers follower notifications after approval', async () => {
    await api()
      .post(`/api/clubs/${clubId}/follow`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(201);
    const pending = await api()
      .post('/api/events')
      .auth(admin, { type: 'bearer' })
      .send(eventInput())
      .expect(201);
    const id = pending.body.data.id;
    await api()
      .patch(`/api/events/${id}/approve`)
      .auth(superAdmin, { type: 'bearer' })
      .expect(200);
    expect(
      await db.notification.count({
        where: { userId: students[0].id, dedupeKey: `new-event:${id}` },
      }),
    ).toBe(1);
  });
  it('enforces database capacity and date checks', async () => {
    const id = await createEvent();
    await expect(
      db.$executeRaw`UPDATE "Event" SET capacity = 0 WHERE id = ${id}::uuid`,
    ).rejects.toThrow();
    await expect(
      db.$executeRaw`UPDATE "Event" SET "endsAt" = "startsAt" WHERE id = ${id}::uuid`,
    ).rejects.toThrow();
  });
  it('validates pagination limits and sort allowlists', async () => {
    await api()
      .get('/api/events?limit=51')
      .auth(students[0].token, { type: 'bearer' })
      .expect(400);
    await api()
      .get('/api/events?sortBy=email')
      .auth(students[0].token, { type: 'bearer' })
      .expect(400);
    const list = await api()
      .get('/api/events?limit=2')
      .auth(students[0].token, { type: 'bearer' })
      .expect(200);
    expect(list.body.data.length).toBeLessThanOrEqual(2);
    expect(list.body.meta.limit).toBe(2);
    for (const event of list.body.data)
      expect(event).toEqual(
        expect.objectContaining({
          registeredCount: expect.any(Number),
          availableSeats: expect.any(Number),
          phase: expect.any(String),
          registrationState: expect.any(String),
          serverTime: expect.any(String),
        }),
      );
  });
  it('prevents club administrators from demoting ADMIN memberships', async () => {
    const member = await db.clubMember.findFirstOrThrow({
      where: { clubId, role: 'ADMIN' },
    });
    await api()
      .post(`/api/clubs/${clubId}/members`)
      .auth(admin, { type: 'bearer' })
      .send({ userId: member.userId, role: 'MEMBER' })
      .expect(403);
    expect(
      (await db.clubMember.findUniqueOrThrow({ where: { id: member.id } }))
        .role,
    ).toBe('ADMIN');
  });
  it('keeps successful registration when notification delivery fails', async () => {
    const id = await createEvent();
    const delivery = jest
      .spyOn(notifications, 'notify')
      .mockRejectedValueOnce(new Error('delivery unavailable'));
    try {
      await api()
        .post(`/api/events/${id}/register`)
        .auth(students[0].token, { type: 'bearer' })
        .expect(201);
      expect(
        await db.registration.count({
          where: { eventId: id, status: 'CONFIRMED' },
        }),
      ).toBe(1);
    } finally {
      delivery.mockRestore();
    }
  });
  it('counts attendance as occupied and rejects invalid null, date and UUID input', async () => {
    const id = await createEvent();
    const result = await api()
      .post(`/api/events/${id}/register`)
      .auth(students[0].token, { type: 'bearer' })
      .expect(201);
    await db.event.update({
      where: { id },
      data: {
        startsAt: new Date(Date.now() - 60000),
        registrationDeadline: new Date(Date.now() - 120000),
      },
    });
    const attended = await api()
      .patch(`/api/registrations/${result.body.data.id}`)
      .auth(admin, { type: 'bearer' })
      .send({ status: 'ATTENDED' })
      .expect(200);
    expect(attended.body.data.event.registeredCount).toBe(1);
    expect(attended.body.data.event.availableSeats).toBe(4);
    await api()
      .patch(`/api/events/${id}`)
      .auth(admin, { type: 'bearer' })
      .send({ capacity: null })
      .expect(400);
    await api()
      .post('/api/events')
      .auth(admin, { type: 'bearer' })
      .send(eventInput({ startsAt: '2030-01-01' }))
      .expect(400);
    await api()
      .get('/api/clubs/not-a-uuid/members')
      .auth(admin, { type: 'bearer' })
      .expect(400);
  });
  it('preserves publication when the same UTC dates are resubmitted', async () => {
    const id = await createEvent();
    const original = await db.event.findUniqueOrThrow({ where: { id } });
    const response = await api()
      .patch(`/api/events/${id}`)
      .auth(admin, { type: 'bearer' })
      .send({
        startsAt: original.startsAt.toISOString(),
        endsAt: original.endsAt.toISOString(),
        registrationDeadline: original.registrationDeadline.toISOString(),
      })
      .expect(200);
    expect(response.body.data.status).toBe('PUBLISHED');
  });
});
