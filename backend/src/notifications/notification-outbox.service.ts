import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationOutbox, Prisma, Registration } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from './notifications.service';

@Injectable()
export class NotificationOutboxService {
  private readonly logger = new Logger(NotificationOutboxService.name);
  constructor(
    private db: PrismaService,
    private notifications: NotificationsService,
  ) {}

  private registrationKey(
    registration: Pick<Registration, 'id' | 'status' | 'version'>,
  ) {
    if (registration.status === 'ATTENDED') return null;
    return `${registration.status === 'CANCELLED' ? 'registration-cancelled' : 'registration-confirmed'}:${registration.id}:${registration.version}`;
  }

  async enqueueRegistration(
    tx: Prisma.TransactionClient,
    registration: Registration,
  ) {
    const dedupeKey = this.registrationKey(registration);
    if (!dedupeKey) return null;
    const cancelled = registration.status === 'CANCELLED';
    return tx.notificationOutbox.upsert({
      where: { userId_dedupeKey: { userId: registration.userId, dedupeKey } },
      create: {
        userId: registration.userId,
        eventId: registration.eventId,
        registrationId: registration.id,
        type: cancelled ? 'REGISTRATION_CANCELLED' : 'REGISTRATION_CONFIRMED',
        dedupeKey,
        title: cancelled ? 'Registration cancelled' : 'Registration confirmed',
        body: cancelled
          ? 'Your seat has been released.'
          : 'Your seat is reserved.',
      },
      update: {},
    });
  }

  @Cron('* * * * *')
  async tryDispatch(id?: string) {
    try {
      await this.dispatch(id);
    } catch {
      this.logger.error(
        'Notification outbox unavailable; committed intents remain queued',
      );
    }
  }

  async dispatch(id?: string, now = new Date()) {
    const leaseId = randomUUID(),
      lockedUntil = new Date(now.getTime() + 60000);
    // One atomic claim; concurrent workers skip locked rows and stale owners cannot acknowledge a replacement lease.
    const intents = await this.db.$queryRaw<NotificationOutbox[]>(Prisma.sql`
      WITH due AS (
        SELECT id FROM "NotificationOutbox"
        WHERE "processedAt" IS NULL AND "availableAt" <= ${now}
          AND ("lockedUntil" IS NULL OR "lockedUntil" <= ${now})
          ${id ? Prisma.sql`AND id = ${id}::uuid` : Prisma.empty}
        ORDER BY "createdAt", id LIMIT 50 FOR UPDATE SKIP LOCKED
      )
      UPDATE "NotificationOutbox" AS job
      SET "leaseId" = ${leaseId}::uuid, "lockedUntil" = ${lockedUntil},
          attempts = job.attempts + 1, "updatedAt" = ${now}
      FROM due WHERE job.id = due.id RETURNING job.*
    `);
    const registrations = intents.length
      ? await this.db.registration.findMany({
          where: { id: { in: intents.map((intent) => intent.registrationId) } },
          select: { id: true, status: true, version: true },
        })
      : [];
    const currentKeys = new Map(
      registrations.map((registration) => [
        registration.id,
        this.registrationKey(registration),
      ]),
    );
    const result = { processed: 0, failed: 0 };
    for (const intent of intents) {
      try {
        const superseded =
          currentKeys.get(intent.registrationId) !== intent.dedupeKey;
        if (!superseded)
          await this.notifications.notify(
            intent.userId,
            intent.type,
            intent.eventId,
            intent.dedupeKey,
            intent.title,
            intent.body,
          );
        const acknowledged = await this.db.notificationOutbox.updateMany({
          where: { id: intent.id, leaseId },
          data: {
            processedAt: now,
            leaseId: null,
            lockedUntil: null,
            lastError: superseded ? 'SUPERSEDED' : null,
          },
        });
        result.processed += acknowledged.count;
      } catch {
        const delay = Math.min(
          3600000,
          5000 * 2 ** Math.min(intent.attempts - 1, 10),
        );
        const deferred = await this.db.notificationOutbox.updateMany({
          where: { id: intent.id, leaseId },
          data: {
            availableAt: new Date(now.getTime() + delay),
            leaseId: null,
            lockedUntil: null,
            lastError: 'NOTIFICATION_DELIVERY_FAILED',
          },
        });
        result.failed += deferred.count;
        this.logger.warn('Registration notification deferred for retry');
      }
    }
    return result;
  }

  @Cron('0 3 * * *', { timeZone: 'UTC' })
  async cleanup(now = new Date()) {
    return this.db.notificationOutbox.deleteMany({
      where: { processedAt: { lt: new Date(now.getTime() - 30 * 86400000) } },
    });
  }
}
