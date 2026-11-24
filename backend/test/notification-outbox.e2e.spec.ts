import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { SchedulerRegistry } from '@nestjs/schedule';
import { JwtService } from '@nestjs/jwt';
import { spawn, ChildProcess } from 'child_process';
import { once } from 'events';
import { resolve } from 'path';
import { randomUUID } from 'crypto';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';
import { CONFIG, Configuration } from '../src/config/environment';
import { PrismaService } from '../src/prisma/prisma.service';
import { NotificationsService } from '../src/notifications/notifications.service';
import { NotificationOutboxService } from '../src/notifications/notification-outbox.service';
import { PushService } from '../src/notifications/push.service';

describe('durable registration notification outbox (real PostgreSQL)', () => {
  let app: INestApplication,
    db: PrismaService,
    outbox: NotificationOutboxService,
    notifications: NotificationsService;
  let userId: string, token: string, clubId: string;
  const suffix = randomUUID();
  const pushes: string[] = [];
  const api = () => request(app.getHttpServer());
  async function event() {
    return db.event.create({
      data: {
        clubId,
        createdById: userId,
        title: 'Durable notification event',
        description: 'An event for reliable notification delivery tests.',
        category: 'TECHNOLOGY',
        location: 'EST Auditorium',
        capacity: 5,
        status: 'PUBLISHED',
        startsAt: new Date(Date.now() + 72 * 3600000),
        endsAt: new Date(Date.now() + 74 * 3600000),
        registrationDeadline: new Date(Date.now() + 70 * 3600000),
      },
    });
  }
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PushService)
      .useValue({
        send: async (_tokens: string[], title: string) => {
          pushes.push(title);
        },
      })
      .compile();
    app = module.createNestApplication();
    const config = app.get<Configuration>(CONFIG);
    configureApp(app, config);
    await app.init();
    for (const job of app.get(SchedulerRegistry).getCronJobs().values())
      job.stop();
    db = app.get(PrismaService);
    outbox = app.get(NotificationOutboxService);
    notifications = app.get(NotificationsService);
    const user = await db.user.create({
      data: {
        email: `outbox-${suffix}@example.edu`,
        passwordHash: 'unused-in-fixture',
        firstName: 'Outbox',
        lastName: 'Student',
      },
    });
    userId = user.id;
    token = await app.get(JwtService).signAsync(
      { sub: userId },
      {
        secret: config.secret,
        issuer: 'est-clubs',
        audience: 'est-mobile',
        expiresIn: 900,
      },
    );
    clubId = (
      await db.club.create({
        data: {
          name: `Outbox-${suffix}`,
          description: 'A club for outbox integration tests.',
          category: 'TECHNOLOGY',
          status: 'APPROVED',
        },
      })
    ).id;
  });
  afterAll(async () => {
    jest.restoreAllMocks();
    if (db) {
      await db.club.deleteMany({ where: { id: clubId } });
      await db.user.deleteMany({ where: { id: userId } });
    }
    if (app) await app.close();
  });
  it('commits an intent alongside registration, then delivers it after commit', async () => {
    const e = await event();
    const response = await api()
      .post(`/api/events/${e.id}/register`)
      .auth(token, { type: 'bearer' })
      .expect(201);
    const intent = await db.notificationOutbox.findUniqueOrThrow({
      where: {
        userId_dedupeKey: {
          userId,
          dedupeKey: `registration-confirmed:${response.body.data.id}:1`,
        },
      },
    });
    expect(intent.registrationId).toBe(response.body.data.id);
    expect(response.body.data).not.toHaveProperty('notificationId');
    expect(response.body.data).not.toHaveProperty('notificationOutbox');
    expect(intent.processedAt).not.toBeNull();
    expect(intent.attempts).toBe(1);
    expect(
      await db.notification.count({
        where: { userId, dedupeKey: intent.dedupeKey },
      }),
    ).toBe(1);
  });
  it('keeps registration successful when delivery fails, and retries the durable intent', async () => {
    const e = await event();
    const delivery = jest
      .spyOn(notifications, 'notify')
      .mockRejectedValueOnce(new Error('delivery unavailable'));
    let registrationId: string;
    try {
      const response = await api()
        .post(`/api/events/${e.id}/register`)
        .auth(token, { type: 'bearer' })
        .expect(201);
      registrationId = response.body.data.id;
    } finally {
      delivery.mockRestore();
    }
    const intent = await db.notificationOutbox.findFirstOrThrow({
      where: { registrationId },
    });
    expect(intent.processedAt).toBeNull();
    expect(intent.lastError).toBe('NOTIFICATION_DELIVERY_FAILED');
    expect(intent.availableAt.getTime()).toBeGreaterThan(
      intent.createdAt.getTime(),
    );
    expect(
      await db.registration.count({
        where: { id: registrationId, status: 'CONFIRMED' },
      }),
    ).toBe(1);
    await outbox.dispatch(
      intent.id,
      new Date(intent.availableAt.getTime() + 1),
    );
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent.id },
        })
      ).processedAt,
    ).not.toBeNull();
    expect(
      await db.notification.count({
        where: { userId, dedupeKey: intent.dedupeKey },
      }),
    ).toBe(1);
  });
  it('rolls back the intent when the business transaction rolls back', async () => {
    const e = await event();
    await expect(
      db.$transaction(async (tx) => {
        const r = await tx.registration.create({
          data: { userId, eventId: e.id },
        });
        await outbox.enqueueRegistration(tx, r);
        throw new Error('business rollback');
      }),
    ).rejects.toThrow('business rollback');
    expect(await db.registration.count({ where: { eventId: e.id } })).toBe(0);
    expect(
      await db.notificationOutbox.count({ where: { eventId: e.id } }),
    ).toBe(0);
    expect(await db.notification.count({ where: { eventId: e.id } })).toBe(0);
  });
  it('recovers committed registration notifications after a real process crash', async () => {
    const e = await event();
    const child: ChildProcess = spawn(
      process.execPath,
      [resolve(__dirname, 'fixtures/registration-crash.mjs')],
      {
        env: {
          ...process.env,
          OUTBOX_TEST_USER_ID: userId,
          OUTBOX_TEST_EVENT_ID: e.id,
        },
        stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
      },
    );
    try {
      await new Promise<void>((resolveMessage, reject) => {
        const timeout = setTimeout(
          () =>
            reject(
              new Error('Crash fixture did not reach notification boundary'),
            ),
          25000,
        );
        child.once('error', (error) => {
          clearTimeout(timeout);
          reject(error);
        });
        child.once('exit', () => {
          clearTimeout(timeout);
          reject(
            new Error('Crash fixture exited before notification boundary'),
          );
        });
        child.on('message', (message) => {
          if (
            (message as { phase?: string }).phase === 'notification-attempt'
          ) {
            clearTimeout(timeout);
            resolveMessage();
          }
        });
      });
      const exited = once(child, 'exit');
      child.kill('SIGKILL');
      await exited;
      const registration = await db.registration.findUniqueOrThrow({
        where: { userId_eventId: { userId, eventId: e.id } },
      });
      expect(registration.status).toBe('CONFIRMED');
      const intent = await db.notificationOutbox.findFirstOrThrow({
        where: { registrationId: registration.id },
      });
      expect(intent.processedAt).toBeNull();
      expect(intent.lockedUntil).not.toBeNull();
      await outbox.dispatch(
        intent.id,
        new Date(intent.lockedUntil!.getTime() + 1),
      );
      expect(
        await db.notification.count({
          where: { userId, dedupeKey: intent.dedupeKey },
        }),
      ).toBe(1);
    } finally {
      if (child.exitCode === null && child.signalCode === null) {
        const exited = once(child, 'exit');
        child.kill('SIGKILL');
        await exited;
      }
    }
  });
  it('deduplicates repeated enqueue and concurrent worker delivery', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const first = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    const second = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    expect(first!.id).toBe(second!.id);
    const before = pushes.length;
    await Promise.all(
      Array.from({ length: 5 }, () => outbox.dispatch(first!.id)),
    );
    expect(
      await db.notification.count({
        where: { userId, dedupeKey: first!.dedupeKey },
      }),
    ).toBe(1);
    expect(pushes.length - before).toBe(1);
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: first!.id },
        })
      ).attempts,
    ).toBe(1);
  });
  it('reclaims an expired lease without sending push twice for an existing notification', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    await notifications.notify(
      userId,
      intent!.type,
      e.id,
      intent!.dedupeKey,
      intent!.title,
      intent!.body,
    );
    await db.notificationOutbox.update({
      where: { id: intent!.id },
      data: {
        leaseId: randomUUID(),
        lockedUntil: new Date(Date.now() - 1000),
        attempts: 1,
      },
    });
    const before = pushes.length;
    await outbox.dispatch(intent!.id);
    expect(pushes.length).toBe(before);
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent!.id },
        })
      ).processedAt,
    ).not.toBeNull();
  });
  it('leaves delayed jobs and live leases unclaimed until they expire', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    const now = new Date(),
      later = new Date(now.getTime() + 60000);
    await db.notificationOutbox.update({
      where: { id: intent!.id },
      data: { availableAt: later },
    });
    await outbox.dispatch(intent!.id, now);
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent!.id },
        })
      ).attempts,
    ).toBe(0);
    await db.notificationOutbox.update({
      where: { id: intent!.id },
      data: { availableAt: now, leaseId: randomUUID(), lockedUntil: later },
    });
    await outbox.dispatch(intent!.id, now);
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent!.id },
        })
      ).attempts,
    ).toBe(0);
    await outbox.dispatch(intent!.id, new Date(later.getTime() + 1));
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent!.id },
        })
      ).processedAt,
    ).not.toBeNull();
  });
  it('uses exponential retry delays capped at one hour without storing exception text', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    const delivery = jest
      .spyOn(notifications, 'notify')
      .mockRejectedValue(new Error('sensitive transport detail'));
    try {
      const now = new Date();
      await outbox.dispatch(intent!.id, now);
      const first = await db.notificationOutbox.findUniqueOrThrow({
        where: { id: intent!.id },
      });
      expect(first.availableAt.getTime() - now.getTime()).toBe(5000);
      const retryAt = new Date(first.availableAt.getTime() + 1);
      await outbox.dispatch(intent!.id, retryAt);
      const second = await db.notificationOutbox.findUniqueOrThrow({
        where: { id: intent!.id },
      });
      expect(second.attempts).toBe(2);
      expect(second.availableAt.getTime() - retryAt.getTime()).toBe(10000);
      expect(second.lastError).toBe('NOTIFICATION_DELIVERY_FAILED');
      await db.notificationOutbox.update({
        where: { id: intent!.id },
        data: { attempts: 20, availableAt: now },
      });
      await outbox.dispatch(intent!.id, now);
      expect(
        (
          await db.notificationOutbox.findUniqueOrThrow({
            where: { id: intent!.id },
          })
        ).availableAt.getTime() - now.getTime(),
      ).toBe(3600000);
    } finally {
      delivery.mockRestore();
      await db.notificationOutbox.deleteMany({ where: { id: intent!.id } });
    }
  });
  it('does not acknowledge a lease that another worker has replaced', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    const replacementLease = randomUUID(),
      later = new Date(Date.now() + 60000);
    const originalNotify = notifications.notify.bind(notifications);
    const delivery = jest
      .spyOn(notifications, 'notify')
      .mockImplementationOnce(async (...args) => {
        await db.notificationOutbox.update({
          where: { id: intent!.id },
          data: { leaseId: replacementLease, lockedUntil: later },
        });
        return originalNotify(...args);
      });
    try {
      await outbox.dispatch(intent!.id);
    } finally {
      delivery.mockRestore();
    }
    const pending = await db.notificationOutbox.findUniqueOrThrow({
      where: { id: intent!.id },
    });
    expect(pending.processedAt).toBeNull();
    expect(pending.leaseId).toBe(replacementLease);
    await outbox.dispatch(intent!.id, new Date(later.getTime() + 1));
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent!.id },
        })
      ).processedAt,
    ).not.toBeNull();
  });
  it('queues cancellation versions once and supports re-registration notifications', async () => {
    const e = await event();
    const registered = await api()
      .post(`/api/events/${e.id}/register`)
      .auth(token, { type: 'bearer' })
      .expect(201);
    const id = registered.body.data.id;
    await api()
      .delete(`/api/registrations/${id}`)
      .auth(token, { type: 'bearer' })
      .expect(200);
    await api()
      .delete(`/api/registrations/${id}`)
      .auth(token, { type: 'bearer' })
      .expect(200);
    await api()
      .post(`/api/events/${e.id}/register`)
      .auth(token, { type: 'bearer' })
      .expect(201);
    const intents = await db.notificationOutbox.findMany({
      where: { registrationId: id },
      orderBy: { createdAt: 'asc' },
    });
    expect(intents).toHaveLength(3);
    expect(new Set(intents.map((intent) => intent.dedupeKey))).toEqual(
      new Set([
        `registration-confirmed:${id}:1`,
        `registration-cancelled:${id}:2`,
        `registration-confirmed:${id}:3`,
      ]),
    );
  });
  it('honors current notification preferences when delayed delivery resumes', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    await db.user.update({
      where: { id: userId },
      data: { notifyRegistrations: false },
    });
    try {
      await outbox.dispatch(intent!.id);
      expect(
        await db.notification.count({
          where: { userId, dedupeKey: intent!.dedupeKey },
        }),
      ).toBe(0);
      expect(
        (
          await db.notificationOutbox.findUniqueOrThrow({
            where: { id: intent!.id },
          })
        ).processedAt,
      ).not.toBeNull();
    } finally {
      await db.user.update({
        where: { id: userId },
        data: { notifyRegistrations: true },
      });
    }
  });
  it('suppresses a superseded confirmation when cancellation committed before delivery', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const confirmation = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    const cancelled = await db.registration.update({
      where: { id: r.id },
      data: {
        status: 'CANCELLED',
        version: { increment: 1 },
        cancelledAt: new Date(),
      },
    });
    const cancellation = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, cancelled),
    );
    await outbox.dispatch(confirmation!.id);
    await outbox.dispatch(cancellation!.id);
    expect(
      await db.notification.count({
        where: { userId, dedupeKey: confirmation!.dedupeKey },
      }),
    ).toBe(0);
    expect(
      await db.notification.count({
        where: { userId, dedupeKey: cancellation!.dedupeKey },
      }),
    ).toBe(1);
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: confirmation!.id },
        })
      ).lastError,
    ).toBe('SUPERSEDED');
  });
  it('keeps the committed intent when an immediate worker claim fails', async () => {
    const e = await event();
    const worker = jest
      .spyOn(outbox, 'dispatch')
      .mockRejectedValueOnce(new Error('claim unavailable'));
    let id: string;
    try {
      const response = await api()
        .post(`/api/events/${e.id}/register`)
        .auth(token, { type: 'bearer' })
        .expect(201);
      id = response.body.data.id;
    } finally {
      worker.mockRestore();
    }
    const intent = await db.notificationOutbox.findFirstOrThrow({
      where: { registrationId: id },
    });
    expect(intent.processedAt).toBeNull();
    expect(intent.attempts).toBe(0);
    await outbox.dispatch(intent.id);
    expect(
      (
        await db.notificationOutbox.findUniqueOrThrow({
          where: { id: intent.id },
        })
      ).processedAt,
    ).not.toBeNull();
  });
  it('enforces paired leases and nonnegative attempts in PostgreSQL', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    await expect(
      db.notificationOutbox.update({
        where: { id: intent!.id },
        data: { attempts: -1 },
      }),
    ).rejects.toThrow();
    await expect(
      db.notificationOutbox.update({
        where: { id: intent!.id },
        data: { leaseId: randomUUID() },
      }),
    ).rejects.toThrow();
    await outbox.dispatch(intent!.id);
  });
  it('processes at most 50 queued intents in one worker batch', async () => {
    const template = await event();
    const events = Array.from({ length: 51 }, () => ({
      ...template,
      id: randomUUID(),
    }));
    await db.event.createMany({ data: events });
    const registrations = events.map((e) => ({
      id: randomUUID(),
      userId,
      eventId: e.id,
    }));
    await db.registration.createMany({ data: registrations });
    await db.notificationOutbox.createMany({
      data: registrations.map((r) => ({
        registrationId: r.id,
        eventId: r.eventId,
        userId,
        type: 'REGISTRATION_CONFIRMED' as const,
        dedupeKey: `registration-confirmed:${r.id}:1`,
        title: 'Registration confirmed',
        body: 'Your seat is reserved.',
      })),
    });
    expect((await outbox.dispatch()).processed).toBe(50);
    expect(
      await db.notificationOutbox.count({
        where: { eventId: { in: events.map((e) => e.id) }, processedAt: null },
      }),
    ).toBe(1);
    expect((await outbox.dispatch()).processed).toBe(1);
  });
  it('removes old processed intents without deleting in-app notification history', async () => {
    const e = await event();
    const r = await db.registration.create({ data: { userId, eventId: e.id } });
    const intent = await db.$transaction((tx) =>
      outbox.enqueueRegistration(tx, r),
    );
    await outbox.dispatch(intent!.id);
    await db.notificationOutbox.update({
      where: { id: intent!.id },
      data: { processedAt: new Date(Date.now() - 31 * 86400000) },
    });
    await outbox.cleanup();
    expect(
      await db.notificationOutbox.count({ where: { id: intent!.id } }),
    ).toBe(0);
    expect(
      await db.notification.count({
        where: { userId, dedupeKey: intent!.dedupeKey },
      }),
    ).toBe(1);
  });
});
