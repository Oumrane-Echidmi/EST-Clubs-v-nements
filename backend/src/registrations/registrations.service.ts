import { Inject, Injectable } from '@nestjs/common';
import { Event, Prisma, Registration } from '@prisma/client';
import { Actor, ScopeService } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { ApiError } from '../common/http';
import { CONFIG, Configuration } from '../config/environment';
import { EventsService, activeStatuses } from '../events/events.service';
import { eventState } from '../events/event-state';
import { NotificationsService } from '../notifications/notifications.service';
import { page, pagination, PaginationDto } from '../common/pagination';
import { RegistrationQuery } from './registrations.dto';
@Injectable()
export class RegistrationsService {
  constructor(
    private db: PrismaService,
    private scope: ScopeService,
    private events: EventsService,
    private notifications: NotificationsService,
    @Inject(CONFIG) private config: Configuration,
  ) {}
  private async lock(tx: Prisma.TransactionClient, eventId: string) {
    await tx.$queryRaw`SELECT id FROM "Event" WHERE id = ${eventId}::uuid FOR UPDATE`;
    const event = await tx.event.findUnique({
      where: { id: eventId },
      include: { club: { select: { status: true } } },
    });
    if (!event) throw new ApiError('NOT_FOUND', 'Event not found', 404);
    return event;
  }
  private assertOpen(event: Event & { club: { status: string } }) {
    if (
      event.status !== 'PUBLISHED' ||
      event.club.status !== 'APPROVED' ||
      new Date() >= event.registrationDeadline ||
      new Date() >= event.startsAt
    )
      throw new ApiError('REGISTRATION_CLOSED', 'Registration is closed', 409);
  }
  private async assertSeat(tx: Prisma.TransactionClient, event: Event) {
    if (
      (await tx.registration.count({
        where: { eventId: event.id, status: { in: activeStatuses } },
      })) >= event.capacity
    )
      throw new ApiError('EVENT_FULL', 'No available seats', 409);
  }
  async register(actor: Actor, eventId: string) {
    const registration = await this.db.$transaction(
      async (tx) => {
        const event = await this.lock(tx, eventId);
        this.assertOpen(event);
        const previous = await tx.registration.findUnique({
          where: { userId_eventId: { userId: actor.id, eventId } },
        });
        if (previous && previous.status !== 'CANCELLED')
          throw new ApiError('ALREADY_REGISTERED', 'Already registered', 409);
        await this.assertSeat(tx, event);
        return previous
          ? tx.registration.update({
              where: { id: previous.id },
              data: {
                status: 'CONFIRMED',
                cancelledAt: null,
                registeredAt: new Date(),
                version: { increment: 1 },
              },
            })
          : tx.registration.create({ data: { userId: actor.id, eventId } });
      },
      { maxWait: 60000, timeout: 30000 },
    );
    await this.registrationNotification(registration);
    return { ...registration, event: await this.events.detail(actor, eventId) };
  }
  private async registrationNotification(r: Registration) {
    const cancelled = r.status === 'CANCELLED';
    await this.notifications.safe(() =>
      this.notifications.notify(
        r.userId,
        cancelled ? 'REGISTRATION_CANCELLED' : 'REGISTRATION_CONFIRMED',
        r.eventId,
        `${cancelled ? 'registration-cancelled' : 'registration-confirmed'}:${r.id}:${r.version}`,
        cancelled ? 'Registration cancelled' : 'Registration confirmed',
        cancelled ? 'Your seat has been released.' : 'Your seat is reserved.',
      ),
    );
  }
  async change(
    actor: Actor,
    id: string,
    status: 'CONFIRMED' | 'ATTENDED' | 'CANCELLED',
    ownerAllowed = false,
  ) {
    const found = await this.db.registration.findUnique({ where: { id } });
    if (!found) throw new ApiError('NOT_FOUND', 'Registration not found', 404);
    const registration = await this.db.$transaction(
      async (tx) => {
        const event = await this.lock(tx, found.eventId);
        const r = await tx.registration.findUnique({ where: { id } });
        if (!r) throw new ApiError('NOT_FOUND', 'Registration not found', 404);
        if (!(ownerAllowed && r.userId === actor.id))
          await this.scope.assertClub(actor, event.clubId);
        if (r.status === status) return r;
        if (status === 'CANCELLED') {
          const state = eventState(
            event,
            0,
            r,
            new Date(),
            this.config.cancellationMinutes,
          );
          if (!state.canCancel)
            throw new ApiError(
              'CANCELLATION_NOT_ALLOWED',
              'Cancellation is not allowed',
              409,
            );
        } else {
          if (r.status === 'CANCELLED') {
            this.assertOpen(event);
            await this.assertSeat(tx, event);
          }
          if (
            status === 'ATTENDED' &&
            (r.status !== 'CONFIRMED' ||
              new Date() < event.startsAt ||
              event.status !== 'PUBLISHED')
          )
            throw new ApiError(
              'VALIDATION_ERROR',
              'Attendance requires a confirmed registration after event start',
            );
          if (r.status === 'ATTENDED')
            throw new ApiError(
              'VALIDATION_ERROR',
              'Attendance cannot be reverted',
            );
        }
        return tx.registration.update({
          where: { id },
          data: {
            status,
            cancelledAt: status === 'CANCELLED' ? new Date() : null,
            version: { increment: 1 },
            ...(r.status === 'CANCELLED' ? { registeredAt: new Date() } : {}),
          },
        });
      },
      { maxWait: 60000, timeout: 30000 },
    );
    if (registration.status !== 'ATTENDED')
      await this.registrationNotification(registration);
    // Registration remains accessible to its owner even if the event returns to approval.
    const event = await this.db.event.findUniqueOrThrow({
      where: { id: registration.eventId },
    });
    return {
      ...registration,
      event: (await this.events.decorate([event], actor))[0],
    };
  }
  async mine(actor: Actor, q: RegistrationQuery) {
    const now = new Date();
    const where: Prisma.RegistrationWhereInput = {
      userId: actor.id,
      ...(q.tab === 'cancelled'
        ? { status: 'CANCELLED' }
        : q.tab === 'upcoming'
          ? { status: { in: activeStatuses }, event: { endsAt: { gt: now } } }
          : q.tab === 'completed'
            ? {
                status: { in: activeStatuses },
                event: { endsAt: { lte: now } },
              }
            : {}),
    };
    const [rows, total] = await Promise.all([
      this.db.registration.findMany({
        where,
        ...pagination(q, ['registeredAt']),
        include: { event: true },
      }),
      this.db.registration.count({ where }),
    ]);
    const events = new Map(
      (
        await this.events.decorate(
          rows.map((r) => r.event),
          actor,
        )
      ).map((e) => [e.id, e]),
    );
    return page(
      rows.map(({ event, ...r }) => ({ ...r, event: events.get(event.id) })),
      total,
      q,
    );
  }
  async attendees(actor: Actor, eventId: string, q: PaginationDto) {
    const event = await this.db.event.findUnique({ where: { id: eventId } });
    if (!event) throw new ApiError('NOT_FOUND', 'Event not found', 404);
    await this.scope.assertClub(actor, event.clubId);
    const where = { eventId };
    const [data, total] = await Promise.all([
      this.db.registration.findMany({
        where,
        ...pagination(q, ['registeredAt']),
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              studentId: true,
            },
          },
        },
      }),
      this.db.registration.count({ where }),
    ]);
    return page(data, total, q);
  }
}
