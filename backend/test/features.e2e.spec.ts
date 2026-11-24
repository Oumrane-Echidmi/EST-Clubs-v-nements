import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import sharp from 'sharp';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';
import { CONFIG, Configuration } from '../src/config/environment';
import { PrismaService } from '../src/prisma/prisma.service';
import { StorageService } from '../src/uploads/uploads.module';
describe('uploads, calendar, home and announcements', () => {
  let app: INestApplication,
    db: PrismaService,
    student: string,
    admin: string,
    superAdmin: string,
    userId: string,
    clubId: string,
    foreignClubId: string,
    eventId: string,
    pendingId: string;
  const suffix = randomUUID();
  const uploaded: { name: string; data: Buffer }[] = [];
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(StorageService)
      .useValue({
        put: async (name: string, data: Buffer) => {
          uploaded.push({ name, data });
          return `http://localhost:3000/api/uploads/files/${name}`;
        },
      })
      .compile();
    app = module.createNestApplication();
    const config = app.get<Configuration>(CONFIG);
    configureApp(app, config);
    await app.init();
    db = app.get(PrismaService);
    const jwt = app.get(JwtService);
    for (const role of ['STUDENT', 'CLUB_ADMIN', 'SUPER_ADMIN'] as const) {
      const user = await db.user.create({
        data: {
          email: `${role}-${suffix}@example.edu`,
          passwordHash: 'unused-in-fixture',
          role,
          firstName: 'Test',
          lastName: 'User',
        },
      });
      const token = await jwt.signAsync(
        { sub: user.id },
        {
          secret: config.secret,
          issuer: 'est-clubs',
          audience: 'est-mobile',
          expiresIn: 900,
        },
      );
      if (role === 'STUDENT') {
        student = token;
        userId = user.id;
      } else if (role === 'CLUB_ADMIN') admin = token;
      else superAdmin = token;
    }
    const club = await db.club.create({
      data: {
        name: `Features-${suffix}`,
        description: 'Feature integration tests',
        category: 'TECHNOLOGY',
        status: 'APPROVED',
        isFeatured: true,
      },
    });
    clubId = club.id;
    foreignClubId = (
      await db.club.create({
        data: {
          name: `Other-${suffix}`,
          description: 'Other club',
          category: 'SPORTS',
          status: 'APPROVED',
        },
      })
    ).id;
    const clubAdmin = await db.user.findUniqueOrThrow({
      where: { email: `CLUB_ADMIN-${suffix}@example.edu` },
    });
    await db.clubMember.create({
      data: { clubId, userId: clubAdmin.id, role: 'ADMIN' },
    });
    const event = {
      clubId,
      title: 'Calendar event',
      description: 'A detailed calendar event',
      location: 'Auditorium',
      category: 'TECHNOLOGY' as const,
      capacity: 10,
      createdById: clubAdmin.id,
      startsAt: new Date(Date.now() + 48 * 3600000),
      endsAt: new Date(Date.now() + 50 * 3600000),
      registrationDeadline: new Date(Date.now() + 47 * 3600000),
    };
    eventId = (
      await db.event.create({ data: { ...event, status: 'PUBLISHED' } })
    ).id;
    pendingId = (
      await db.event.create({ data: { ...event, status: 'PENDING_APPROVAL' } })
    ).id;
  });
  afterAll(async () => {
    if (db) {
      await db.club.deleteMany({
        where: { id: { in: [clubId, foreignClubId] } },
      });
      await db.user.deleteMany({ where: { email: { contains: suffix } } });
    }
    if (app) await app.close();
  });
  it('validates image content and permissions before storing sanitized WebP', async () => {
    await request(app.getHttpServer())
      .post('/api/uploads/image?kind=avatar')
      .auth(student, { type: 'bearer' })
      .attach('file', Buffer.from('not an image'), {
        filename: 'fake.png',
        contentType: 'image/png',
      })
      .expect(400);
    const png = await sharp({
      create: { width: 2, height: 2, channels: 3, background: '#2563EB' },
    })
      .png()
      .toBuffer();
    await request(app.getHttpServer())
      .post(`/api/uploads/image?kind=poster&clubId=${clubId}`)
      .auth(student, { type: 'bearer' })
      .attach('file', png, { filename: 'poster.png', contentType: 'image/png' })
      .expect(403);
    await request(app.getHttpServer())
      .post(`/api/uploads/image?kind=logo&clubId=${foreignClubId}`)
      .auth(admin, { type: 'bearer' })
      .attach('file', png, { filename: 'logo.png', contentType: 'image/png' })
      .expect(403);
    const result = await request(app.getHttpServer())
      .post('/api/uploads/image?kind=avatar')
      .auth(student, { type: 'bearer' })
      .attach('file', png, {
        filename: '../../avatar.png',
        contentType: 'image/png',
      })
      .expect(201);
    expect(result.body.data.mimeType).toBe('image/webp');
    expect(uploaded).toHaveLength(1);
    expect(uploaded[0].name).toMatch(/^[a-f0-9-]+\.webp$/);
    expect((await sharp(uploaded[0].data).metadata()).format).toBe('webp');
    await request(app.getHttpServer())
      .post('/api/uploads/image?kind=avatar')
      .auth(student, { type: 'bearer' })
      .attach('file', Buffer.alloc(5 * 1024 * 1024 + 1), {
        filename: 'huge.png',
        contentType: 'image/png',
      })
      .expect(413);
  });
  it('exports visible calendar files with UTC dates and blocks unpublished events', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/events/${eventId}/calendar.ics`)
      .auth(student, { type: 'bearer' })
      .expect(200);
    expect(res.headers['content-type']).toContain('text/calendar');
    expect(res.text).toContain('BEGIN:VCALENDAR');
    expect(res.text).toContain(`UID:${eventId}@est-clubs`);
    await request(app.getHttpServer())
      .get(`/api/events/${pendingId}/calendar.ics`)
      .auth(student, { type: 'bearer' })
      .expect(404);
  });
  it('enforces announcement scopes and returns personalized home sections', async () => {
    await request(app.getHttpServer())
      .post('/api/announcements')
      .auth(admin, { type: 'bearer' })
      .send({ title: 'Campus', body: 'Campus wide announcement' })
      .expect(403);
    await request(app.getHttpServer())
      .post('/api/announcements')
      .auth(admin, { type: 'bearer' })
      .send({
        clubId: foreignClubId,
        title: 'Other club',
        body: 'Forbidden announcement',
      })
      .expect(403);
    const result = await request(app.getHttpServer())
      .post('/api/announcements')
      .auth(admin, { type: 'bearer' })
      .send({ clubId, title: 'Club news', body: 'Our campus club news' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/clubs/${clubId}/follow`)
      .auth(student, { type: 'bearer' })
      .expect(201);
    const home = await request(app.getHttpServer())
      .get('/api/home?limit=2')
      .auth(student, { type: 'bearer' })
      .expect(200);
    for (const key of [
      'upcomingEvents',
      'featuredClubs',
      'announcements',
      'recommendedEvents',
    ]) {
      expect(home.body.data[key].meta.limit).toBe(2);
      expect(Array.isArray(home.body.data[key].data)).toBe(true);
    }
    await request(app.getHttpServer())
      .delete(`/api/announcements/${result.body.data.id}`)
      .auth(superAdmin, { type: 'bearer' })
      .expect(200);
  });
  it('handles notification ownership, reads and logout device cleanup', async () => {
    const n = await db.notification.create({
      data: {
        userId,
        eventId,
        type: 'NEW_EVENT',
        title: 'Test',
        body: 'Test body',
        dedupeKey: `read:${suffix}`,
      },
    });
    await request(app.getHttpServer())
      .patch(`/api/notifications/${n.id}/read`)
      .auth(admin, { type: 'bearer' })
      .expect(404);
    await request(app.getHttpServer())
      .patch(`/api/notifications/${n.id}/read`)
      .auth(student, { type: 'bearer' })
      .expect(200);
    const count = await request(app.getHttpServer())
      .get('/api/me/notifications/unread-count')
      .auth(student, { type: 'bearer' })
      .expect(200);
    expect(count.body.data.count).toBe(0);
    await request(app.getHttpServer())
      .post('/api/me/device-tokens')
      .auth(student, { type: 'bearer' })
      .send({ token: `device-${suffix}`, platform: 'ANDROID' })
      .expect(201);
    await request(app.getHttpServer())
      .delete(`/api/me/device-tokens/device-${suffix}`)
      .auth(student, { type: 'bearer' })
      .expect(200);
    expect(await db.deviceToken.count({ where: { userId } })).toBe(0);
  });
});
