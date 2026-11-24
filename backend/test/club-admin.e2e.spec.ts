import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { configureApp, createOpenApi } from '../src/bootstrap';
import { CONFIG, Configuration } from '../src/config/environment';
import { PrismaService } from '../src/prisma/prisma.service';

describe('club administrator discovery and dashboard', () => {
  let app: INestApplication, db: PrismaService;
  const suffix = randomUUID();
  const accounts: Record<string, { id: string; token: string }> = {};
  let clubId: string, pendingId: string, foreignId: string, eventId: string;
  const clubs: string[] = [];
  const api = () => request(app.getHttpServer());
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = module.createNestApplication();
    const config = app.get<Configuration>(CONFIG);
    configureApp(app, config);
    await app.init();
    db = app.get(PrismaService);
    const jwt = app.get(JwtService);
    for (const [key, role] of [
      ['owner', 'CLUB_ADMIN'],
      ['foreign', 'CLUB_ADMIN'],
      ['super', 'SUPER_ADMIN'],
      ['student', 'STUDENT'],
    ] as const) {
      const user = await db.user.create({
        data: {
          email: `${key}-${suffix}@example.edu`,
          passwordHash: 'unused-in-fixture',
          firstName: 'Integration',
          lastName: key,
          role,
        },
      });
      accounts[key] = {
        id: user.id,
        token: await jwt.signAsync(
          { sub: user.id },
          {
            secret: config.secret,
            issuer: 'est-clubs',
            audience: 'est-mobile',
            expiresIn: 900,
          },
        ),
      };
    }
    for (const [key, name, status] of [
      ['approved', `Alpha-${suffix}`, 'APPROVED'],
      ['pending', `Beta-${suffix}`, 'PENDING'],
      ['foreign', `Gamma-${suffix}`, 'APPROVED'],
    ] as const) {
      const club = await db.club.create({
        data: {
          name,
          description: 'Administrator dashboard integration club',
          category: key === 'pending' ? 'SCIENCE' : 'TECHNOLOGY',
          status,
        },
      });
      clubs.push(club.id);
      if (key === 'approved') clubId = club.id;
      else if (key === 'pending') pendingId = club.id;
      else foreignId = club.id;
      await db.clubMember.create({
        data: {
          clubId: club.id,
          userId: accounts[key === 'foreign' ? 'foreign' : 'owner'].id,
          role: 'ADMIN',
        },
      });
    }
    await db.clubMember.createMany({
      data: [
        { clubId, userId: accounts.student.id, role: 'MEMBER' },
        { clubId: foreignId, userId: accounts.owner.id, role: 'MEMBER' },
      ],
    });
    await db.clubFollow.create({
      data: { clubId, userId: accounts.student.id },
    });
    const dates = {
      startsAt: new Date(Date.now() + 48 * 3600000),
      endsAt: new Date(Date.now() + 50 * 3600000),
      registrationDeadline: new Date(Date.now() + 47 * 3600000),
    };
    for (const status of [
      'PUBLISHED',
      'PENDING_APPROVAL',
      'CANCELLED',
    ] as const) {
      const event = await db.event.create({
        data: {
          ...dates,
          clubId,
          createdById: accounts.owner.id,
          title: `Dashboard ${status}`,
          description: 'A dashboard integration test event.',
          category: 'TECHNOLOGY',
          location: 'EST Auditorium',
          capacity: 5,
          status,
        },
      });
      if (status === 'PUBLISHED') eventId = event.id;
    }
    await db.registration.createMany({
      data: [
        { eventId, userId: accounts.student.id, status: 'CONFIRMED' },
        { eventId, userId: accounts.owner.id, status: 'ATTENDED' },
        { eventId, userId: accounts.foreign.id, status: 'CANCELLED' },
      ],
    });
  });
  afterAll(async () => {
    if (db) {
      await db.club.deleteMany({ where: { id: { in: clubs } } });
      await db.user.deleteMany({ where: { email: { contains: suffix } } });
    }
    if (app) await app.close();
  });

  it('discovers only ADMIN memberships, including pending clubs, with pagination', async () => {
    const first = await api()
      .get('/api/me/clubs?page=1&limit=1&sortBy=name&sortOrder=asc')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(first.body.meta).toEqual({
      page: 1,
      limit: 1,
      total: 2,
      totalPages: 2,
    });
    expect(first.body.data.map((club: { id: string }) => club.id)).toEqual([
      clubId,
    ]);
    const second = await api()
      .get('/api/me/clubs?page=2&limit=1&sortBy=name&sortOrder=asc')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(second.body.data[0]).toMatchObject({
      id: pendingId,
      status: 'PENDING',
    });
    expect(second.body.data[0]).toHaveProperty('isFollowed');
    const filtered = await api()
      .get('/api/me/clubs?category=SCIENCE&status=PENDING&search=Beta')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(filtered.body.meta.total).toBe(1);
    expect(filtered.body.data[0].id).toBe(pendingId);
  });
  it('preserves student compatibility, requires authentication and validates sort and limit', async () => {
    await api().get('/api/me/clubs').expect(401);
    const student = await api()
      .get('/api/me/clubs')
      .auth(accounts.student.token, { type: 'bearer' })
      .expect(200);
    expect(student.body.data).toEqual([]);
    expect(student.body.meta.total).toBe(0);
    await api()
      .get('/api/me/clubs?limit=51')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(400);
    await api()
      .get('/api/me/clubs?sortBy=email')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(400);
  });
  it('preserves approved-first compatibility across default pages and supports explicit sorting', async () => {
    await db.club.update({
      where: { id: pendingId },
      data: { name: `Aardvark-${suffix}` },
    });
    try {
      const first = await api()
        .get('/api/me/clubs?limit=1')
        .auth(accounts.owner.token, { type: 'bearer' })
        .expect(200);
      const second = await api()
        .get('/api/me/clubs?limit=1&page=2')
        .auth(accounts.owner.token, { type: 'bearer' })
        .expect(200);
      expect(first.body.data[0].id).toBe(clubId);
      expect(second.body.data[0].id).toBe(pendingId);
      const all = await api()
        .get('/api/me/clubs?limit=2')
        .auth(accounts.owner.token, { type: 'bearer' })
        .expect(200);
      expect(all.body.data.map((club: { id: string }) => club.id)).toEqual([
        clubId,
        pendingId,
      ]);
      const sorted = await api()
        .get('/api/me/clubs?sortBy=name&sortOrder=asc')
        .auth(accounts.owner.token, { type: 'bearer' })
        .expect(200);
      expect(sorted.body.data.map((club: { id: string }) => club.id)).toEqual([
        pendingId,
        clubId,
      ]);
    } finally {
      await db.club.update({
        where: { id: pendingId },
        data: { name: `Beta-${suffix}` },
      });
    }
  });
  it('does not list unassigned clubs for a super administrator', async () => {
    const response = await api()
      .get('/api/me/clubs')
      .auth(accounts.super.token, { type: 'bearer' })
      .expect(200);
    expect(response.body.data).toEqual([]);
    expect(response.body.meta.total).toBe(0);
  });
  it('returns accurate scoped dashboard counts and fill rates excluding cancellations', async () => {
    const response = await api()
      .get(`/api/clubs/${clubId}/dashboard`)
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(response.body.data).toMatchObject({
      clubId,
      counts: {
        members: 2,
        followers: 1,
        events: 3,
        publishedEvents: 1,
        pendingEvents: 1,
        activeRegistrations: 2,
      },
    });
    expect(response.body.data.eventFillRates).toEqual([
      expect.objectContaining({
        eventId,
        capacity: 5,
        registeredCount: 2,
        availableSeats: 3,
        fillRate: 0.4,
      }),
    ]);
    await api()
      .get(`/api/clubs/${clubId}/dashboard`)
      .auth(accounts.super.token, { type: 'bearer' })
      .expect(200);
  });
  it('protects foreign and student dashboard access and handles missing IDs', async () => {
    await api()
      .get(`/api/clubs/${clubId}/dashboard`)
      .auth(accounts.foreign.token, { type: 'bearer' })
      .expect(403);
    await api()
      .get(`/api/clubs/${clubId}/dashboard`)
      .auth(accounts.student.token, { type: 'bearer' })
      .expect(403);
    await api()
      .get(`/api/clubs/${randomUUID()}/dashboard`)
      .auth(accounts.super.token, { type: 'bearer' })
      .expect(404);
    await api()
      .get('/api/clubs/invalid/dashboard')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(400);
  });
  it('returns zero aggregates for a club without events', async () => {
    const response = await api()
      .get(`/api/clubs/${pendingId}/dashboard`)
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(response.body.data.counts).toMatchObject({
      events: 0,
      publishedEvents: 0,
      pendingEvents: 0,
      activeRegistrations: 0,
    });
    expect(response.body.data.eventFillRates).toEqual([]);
  });
  it('never advertises student-only registration to administrators', async () => {
    const response = await api()
      .get(`/api/events/${eventId}`)
      .auth(accounts.super.token, { type: 'bearer' })
      .expect(200);
    expect(response.body.data.canRegister).toBe(false);
    const clubAdmin = await api()
      .get(`/api/events/${eventId}`)
      .auth(accounts.foreign.token, { type: 'bearer' })
      .expect(200);
    expect(clubAdmin.body.data.canRegister).toBe(false);
    const list = await api()
      .get(`/api/events?clubId=${clubId}`)
      .auth(accounts.super.token, { type: 'bearer' })
      .expect(200);
    expect(
      list.body.data.every(
        (event: { canRegister: boolean }) => !event.canRegister,
      ),
    ).toBe(true);
  });
  it('documents the paginated discovery and dashboard response contracts', () => {
    const document = createOpenApi(app);
    expect(document.paths['/api/me/clubs']?.get?.description).toContain(
      'Any active authenticated user',
    );
    expect(
      document.paths['/api/clubs/{id}/dashboard']?.get?.responses['200'],
    ).toEqual(
      expect.objectContaining({
        content: {
          'application/json': {
            schema: expect.objectContaining({
              properties: {
                data: { $ref: '#/components/schemas/ClubDashboard' },
              },
            }),
          },
        },
      }),
    );
  });
  it('bounds upcoming fill rates to 20 events in chronological order', async () => {
    const future = Date.now() + 100 * 3600000;
    await db.event.createMany({
      data: Array.from({ length: 22 }, (_, index) => ({
        clubId,
        createdById: accounts.owner.id,
        title: `Bounded dashboard ${index}`,
        description: 'An upcoming event for dashboard pagination boundaries.',
        category: 'TECHNOLOGY' as const,
        location: 'EST Room A',
        capacity: 10,
        status: 'PUBLISHED' as const,
        startsAt: new Date(future + index * 3600000),
        endsAt: new Date(future + (index + 1) * 3600000),
        registrationDeadline: new Date(future - 3600000),
      })),
    });
    const response = await api()
      .get(`/api/clubs/${clubId}/dashboard`)
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(response.body.data.eventFillRates).toHaveLength(20);
    const dates = response.body.data.eventFillRates.map(
      (event: { startsAt: string }) => Date.parse(event.startsAt),
    );
    expect(dates).toEqual([...dates].sort((a: number, b: number) => a - b));
    expect(response.body.data.eventFillRates[0].eventId).toBe(eventId);
    const availableEvent = response.body.data.eventFillRates.at(-1);
    const studentView = await api()
      .get(`/api/events/${availableEvent.eventId}`)
      .auth(accounts.student.token, { type: 'bearer' })
      .expect(200);
    expect(studentView.body.data.canRegister).toBe(true);
    expect(response.body.data.eventFillRates.at(-1)).toMatchObject({
      registeredCount: 0,
      availableSeats: 10,
      fillRate: 0,
    });
  });
  it('removes discovery and access immediately when ADMIN membership or user role is revoked', async () => {
    await db.clubMember.update({
      where: { clubId_userId: { clubId, userId: accounts.owner.id } },
      data: { role: 'MEMBER' },
    });
    const response = await api()
      .get('/api/me/clubs')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(response.body.data.map((club: { id: string }) => club.id)).toEqual([
      pendingId,
    ]);
    await api()
      .get(`/api/clubs/${clubId}/dashboard`)
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(403);
    await db.user.update({
      where: { id: accounts.owner.id },
      data: { role: 'STUDENT' },
    });
    const demoted = await api()
      .get('/api/me/clubs')
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(200);
    expect(demoted.body.data).toEqual([]);
    await api()
      .get(`/api/clubs/${pendingId}/dashboard`)
      .auth(accounts.owner.token, { type: 'bearer' })
      .expect(403);
  });
});
