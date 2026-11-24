import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';
import { PrismaService } from '../src/prisma/prisma.service';
import { MailService } from '../src/auth/mail.service';
import { CONFIG, Configuration } from '../src/config/environment';
import { hashToken } from '../src/auth/auth.service';
import { Role } from '@prisma/client';
import { randomUUID } from 'crypto';
describe('authentication and profile (real PostgreSQL)', () => {
  let app: INestApplication, db: PrismaService;
  const sent: { email: string; token: string }[] = [];
  const suffix = randomUUID();
  const email = `auth-${suffix}@example.edu`;
  const password = 'Integration123';
  let access: string, refresh: string, userId: string;
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailService)
      .useValue({
        sendReset: async (email: string, token: string) => {
          sent.push({ email, token });
        },
      })
      .compile();
    app = module.createNestApplication();
    configureApp(app, app.get<Configuration>(CONFIG));
    await app.init();
    db = app.get(PrismaService);
  });
  afterAll(async () => {
    if (db)
      await db.user.deleteMany({ where: { email: { contains: suffix } } });
    if (app) await app.close();
  });
  it('rejects weak passwords and client-supplied roles', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email, password: 'weak', firstName: 'Test', lastName: 'User' })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        email,
        password,
        firstName: 'Test',
        lastName: 'User',
        role: 'SUPER_ADMIN',
      })
      .expect(400);
  });
  it('registers a student without exposing hashes', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email, password, firstName: 'Test', lastName: 'User' })
      .expect(201);
    expect(res.body.data.user.role).toBe('STUDENT');
    expect(res.body.data.user.passwordHash).toBeUndefined();
    access = res.body.data.accessToken;
    refresh = res.body.data.refreshToken;
    userId = res.body.data.user.id;
    const row = await db.refreshToken.findUniqueOrThrow({
      where: { tokenHash: hashToken(refresh) },
    });
    expect(row.tokenHash).not.toBe(refresh);
  });
  it('requires JWT and uses current database roles and active status', async () => {
    await request(app.getHttpServer()).get('/api/me').expect(401);
    await request(app.getHttpServer())
      .get('/api/me')
      .auth(access, { type: 'bearer' })
      .expect(200);
    await request(app.getHttpServer())
      .get('/api/admin/dashboard')
      .auth(access, { type: 'bearer' })
      .expect(403);
    await db.user.update({
      where: { id: userId },
      data: { role: Role.SUPER_ADMIN },
    });
    await request(app.getHttpServer())
      .get('/api/admin/dashboard')
      .auth(access, { type: 'bearer' })
      .expect(200);
    await db.user.update({
      where: { id: userId },
      data: { role: Role.STUDENT, isActive: false },
    });
    await request(app.getHttpServer())
      .get('/api/me')
      .auth(access, { type: 'bearer' })
      .expect(401);
    await db.user.update({ where: { id: userId }, data: { isActive: true } });
  });
  it('logs in and rejects bad credentials', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: 'Wrong1234' })
      .expect(401);
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password })
      .expect(200);
    expect(res.body.data.accessToken).toBeTruthy();
  });
  it('rotates refresh tokens and persists family revocation after reuse', async () => {
    const rotated = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: refresh })
      .expect(200);
    expect(rotated.body.data.refreshToken).not.toBe(refresh);
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: refresh })
      .expect(401);
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: rotated.body.data.refreshToken })
      .expect(401);
  });
  it('prevents profile privilege escalation', async () => {
    await request(app.getHttpServer())
      .patch('/api/me')
      .auth(access, { type: 'bearer' })
      .send({ role: 'SUPER_ADMIN' })
      .expect(400);
  });
  it('returns identical recovery responses and consumes reset tokens once', async () => {
    const known = await request(app.getHttpServer())
      .post('/api/auth/forgot-password')
      .send({ email })
      .expect(200);
    const unknown = await request(app.getHttpServer())
      .post('/api/auth/forgot-password')
      .send({ email: `missing-${suffix}@example.edu` })
      .expect(200);
    expect(known.body).toEqual(unknown.body);
    const token = sent.find((m) => m.email === email)!.token;
    await request(app.getHttpServer())
      .post('/api/auth/reset-password')
      .send({ token, password: 'Changed1234' })
      .expect(200);
    await request(app.getHttpServer())
      .post('/api/auth/reset-password')
      .send({ token, password })
      .expect(400);
  });
  it('removes the corresponding device on logout', async () => {
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: 'Changed1234' })
      .expect(200);
    const token = `logout-device-${suffix}`;
    await request(app.getHttpServer())
      .post('/api/me/device-tokens')
      .auth(login.body.data.accessToken, { type: 'bearer' })
      .send({ token, platform: 'ANDROID' })
      .expect(201);
    await request(app.getHttpServer())
      .post('/api/auth/logout')
      .send({ refreshToken: login.body.data.refreshToken, deviceToken: token })
      .expect(200);
    expect(await db.deviceToken.count({ where: { userId, token } })).toBe(0);
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: login.body.data.refreshToken })
      .expect(401);
  });
});
