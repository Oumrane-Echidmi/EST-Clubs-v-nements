import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from './push.service';
@Injectable()
export class NotificationsService {
  private logger = new Logger(NotificationsService.name);
  constructor(
    private db: PrismaService,
    private push: PushService,
  ) {}
  async notify(
    userId: string,
    type: NotificationType,
    eventId: string,
    dedupeKey: string,
    title: string,
    body: string,
  ) {
    const user = await this.db.user.findUnique({ where: { id: userId } });
    if (!user?.isActive) return;
    const enabled =
      type === 'NEW_EVENT'
        ? user.notifyNewEvents
        : type.startsWith('REGISTRATION_')
          ? user.notifyRegistrations
          : type.startsWith('REMINDER_')
            ? user.notifyReminders
            : user.notifyEventUpdates;
    if (!enabled) return;
    let notification;
    try {
      notification = await this.db.notification.create({
        data: { userId, eventId, type, dedupeKey, title, body },
      });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      )
        return;
      throw e;
    }
    if (user.pushEnabled) {
      const devices = await this.db.deviceToken.findMany({
        where: { userId },
        select: { token: true },
      });
      try {
        await this.push.send(
          devices.map((d) => d.token),
          title,
          body,
          eventId,
        );
      } catch {
        this.logger.error('Push delivery failed; in-app notification retained');
      }
    }
    return notification;
  }
  async safe(task: () => Promise<unknown>) {
    try {
      await task();
    } catch {
      this.logger.error(
        'Notification delivery failed after committed operation',
      );
    }
  }
  async published(eventId: string) {
    const event = await this.db.event.findUniqueOrThrow({
      where: { id: eventId },
    });
    const followers = await this.db.clubFollow.findMany({
      where: { clubId: event.clubId },
      select: { userId: true },
    });
    for (const follower of followers)
      await this.notify(
        follower.userId,
        'NEW_EVENT',
        eventId,
        `new-event:${eventId}`,
        event.title,
        'A new event is available.',
      );
  }
  async updated(eventId: string) {
    const event = await this.db.event.findUniqueOrThrow({
      where: { id: eventId },
    });
    const registrations = await this.db.registration.findMany({
      where: { eventId, status: { in: ['CONFIRMED', 'ATTENDED'] } },
      select: { userId: true },
    });
    for (const r of registrations)
      await this.notify(
        r.userId,
        'EVENT_UPDATED',
        eventId,
        `event-updated:${eventId}:${event.revision}`,
        event.title,
        'Event details have changed.',
      );
  }
  @Cron('*/5 * * * *')
  async reminders(now = new Date()) {
    // Overlapping ten-minute windows tolerate a delayed scheduler; uniqueness prevents duplicates across workers.
    for (const [hours, type, prefix] of [
      [24, 'REMINDER_24H', 'reminder-24h'],
      [1, 'REMINDER_1H', 'reminder-1h'],
    ] as const) {
      const target = now.getTime() + hours * 3600000;
      const events = await this.db.event.findMany({
        where: {
          status: 'PUBLISHED',
          startsAt: {
            gte: new Date(target - 300000),
            lt: new Date(target + 300000),
          },
        },
        select: { id: true, title: true },
      });
      for (const event of events) {
        const recipients = await this.db.registration.findMany({
          where: { eventId: event.id, status: 'CONFIRMED' },
          select: { userId: true },
        });
        for (const r of recipients)
          await this.safe(() =>
            this.notify(
              r.userId,
              type,
              event.id,
              `${prefix}:${event.id}`,
              event.title,
              `Your event starts in approximately ${hours} hour(s).`,
            ),
          );
      }
    }
  }
}
