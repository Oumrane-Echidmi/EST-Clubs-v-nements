import { Inject, Injectable } from '@nestjs/common';
import { Event, Prisma, RegistrationStatus } from '@prisma/client';
import { Actor, ScopeService } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { CONFIG, Configuration } from '../config/environment';
import { ApiError } from '../common/http';
import { page, pagination } from '../common/pagination';
import { NotificationsService } from '../notifications/notifications.service';
import { eventState } from './event-state';
import { CreateEventDto, EventQuery, UpdateEventDto } from './events.dto';
export const activeStatuses: RegistrationStatus[] = ['CONFIRMED', 'ATTENDED'];
@Injectable()
export class EventsService {
  constructor(
    private db: PrismaService,
    private scope: ScopeService,
    @Inject(CONFIG) private config: Configuration,
    private notifications: NotificationsService,
  ) {}
  async visibility(actor: Actor): Promise<Prisma.EventWhereInput> {
    if (actor.role === 'SUPER_ADMIN') return {};
    const published = {
      status: 'PUBLISHED' as const,
      club: { status: 'APPROVED' as const },
    };
    if (actor.role === 'STUDENT') return published;
    return {
      OR: [published, { clubId: { in: await this.scope.clubIds(actor) } }],
    };
  }
  async decorate(events: Event[], actor: Actor) {
    const ids = events.map((e) => e.id);
    if (!ids.length) return [];
    const [counts, registrations] = await Promise.all([
      this.db.registration.groupBy({
        by: ['eventId'],
        where: { eventId: { in: ids }, status: { in: activeStatuses } },
        _count: { _all: true },
      }),
      this.db.registration.findMany({
        where: { userId: actor.id, eventId: { in: ids } },
        select: { eventId: true, id: true, status: true },
      }),
    ]);
    const countMap = new Map(counts.map((c) => [c.eventId, c._count._all]));
    const registrationMap = new Map(registrations.map((r) => [r.eventId, r]));
    const now = new Date();
    return events.map((event) => {
      const state = eventState(
        event,
        countMap.get(event.id) ?? 0,
        registrationMap.get(event.id) ?? null,
        now,
        this.config.cancellationMinutes,
      );
      return {
        ...event,
        ...state,
        canRegister: actor.role === 'STUDENT' && state.canRegister,
      };
    });
  }
  async list(actor: Actor, q: EventQuery) {
    const where: Prisma.EventWhereInput = {
      AND: [
        await this.visibility(actor),
        {
          category: q.category,
          clubId: q.clubId,
          status: q.status,
          ...(q.from || q.to
            ? {
                startsAt: {
                  gte: q.from ? new Date(q.from) : undefined,
                  lte: q.to ? new Date(q.to) : undefined,
                },
              }
            : {}),
          ...(q.search
            ? {
                OR: [
                  { title: { contains: q.search, mode: 'insensitive' } },
                  { description: { contains: q.search, mode: 'insensitive' } },
                ],
              }
            : {}),
        },
      ],
    };
    const [events, total] = await Promise.all([
      this.db.event.findMany({
        where,
        ...pagination(q, ['startsAt', 'createdAt', 'title']),
        include: { club: { select: { id: true, name: true, logoUrl: true } } },
      }),
      this.db.event.count({ where }),
    ]);
    return page(await this.decorate(events, actor), total, q);
  }
  async visibleEvent(actor: Actor, id: string) {
    const event = await this.db.event.findUnique({
      where: { id },
      include: {
        club: { select: { id: true, name: true, status: true, logoUrl: true } },
      },
    });
    if (!event) throw new ApiError('NOT_FOUND', 'Event not found', 404);
    if (
      actor.role !== 'SUPER_ADMIN' &&
      !(event.status === 'PUBLISHED' && event.club.status === 'APPROVED')
    ) {
      if (actor.role === 'STUDENT')
        throw new ApiError('NOT_FOUND', 'Event not found', 404);
      await this.scope.assertClub(actor, event.clubId);
    }
    return event;
  }
  async detail(actor: Actor, id: string) {
    const event = await this.visibleEvent(actor, id);
    return (await this.decorate([event], actor))[0];
  }
  private dates(input: {
    startsAt: string | Date;
    endsAt: string | Date;
    registrationDeadline: string | Date;
  }) {
    const startsAt = new Date(input.startsAt),
      endsAt = new Date(input.endsAt),
      registrationDeadline = new Date(input.registrationDeadline);
    if (endsAt <= startsAt || registrationDeadline > startsAt)
      throw new ApiError(
        'VALIDATION_ERROR',
        'End must follow start; registration deadline must not follow start',
      );
    return { startsAt, endsAt, registrationDeadline };
  }
  async create(actor: Actor, input: CreateEventDto) {
    await this.scope.assertClub(actor, input.clubId);
    const club = await this.db.club.findUnique({ where: { id: input.clubId } });
    if (!club) throw new ApiError('NOT_FOUND', 'Club not found', 404);
    if (club.status !== 'APPROVED')
      throw new ApiError('FORBIDDEN', 'Club must be approved', 403);
    const event = await this.db.event.create({
      data: {
        ...input,
        ...this.dates(input),
        createdById: actor.id,
        status: actor.role === 'SUPER_ADMIN' ? 'PUBLISHED' : 'PENDING_APPROVAL',
      },
    });
    if (event.status === 'PUBLISHED')
      await this.notifications.safe(() =>
        this.notifications.published(event.id),
      );
    return this.detail(actor, event.id);
  }
  async update(actor: Actor, id: string, input: UpdateEventDto) {
    const result = await this.db.$transaction(
      async (tx) => {
        await tx.$queryRaw`SELECT id FROM "Event" WHERE id = ${id}::uuid FOR UPDATE`;
        const event = await tx.event.findUnique({ where: { id } });
        if (!event) throw new ApiError('NOT_FOUND', 'Event not found', 404);
        await this.scope.assertClub(actor, event.clubId);
        if (input.clubId && input.clubId !== event.clubId) {
          await this.scope.assertClub(actor, input.clubId);
          const club = await tx.club.findUnique({
            where: { id: input.clubId },
          });
          if (club?.status !== 'APPROVED')
            throw new ApiError(
              'VALIDATION_ERROR',
              'Destination club must be approved',
            );
        }
        if (input.capacity !== undefined) {
          const count = await tx.registration.count({
            where: { eventId: id, status: { in: activeStatuses } },
          });
          if (input.capacity < count)
            throw new ApiError(
              'CAPACITY_BELOW_REGISTRATIONS',
              'Capacity cannot be below active registrations',
              409,
            );
        }
        const majorKeys: (keyof UpdateEventDto)[] = [
          'clubId',
          'title',
          'description',
          'category',
          'location',
          'startsAt',
          'endsAt',
          'registrationDeadline',
          'capacity',
        ];
        const major = majorKeys.some((key) => {
          const next = input[key];
          if (next === undefined) return false;
          const previous = event[key];
          return previous instanceof Date
            ? new Date(next).getTime() !== previous.getTime()
            : next !== previous;
        });
        const needsApproval =
          actor.role === 'CLUB_ADMIN' &&
          (event.status === 'PUBLISHED' || event.status === 'REJECTED') &&
          major;
        return tx.event.update({
          where: { id },
          data: {
            ...input,
            ...this.dates({ ...event, ...input }),
            revision: { increment: 1 },
            ...(needsApproval
              ? { status: 'PENDING_APPROVAL', rejectionReason: null }
              : {}),
          },
        });
      },
      { maxWait: 30000, timeout: 30000 },
    );
    await this.notifications.safe(() => this.notifications.updated(result.id));
    return this.detail(actor, id);
  }
  async remove(actor: Actor, id: string) {
    await this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "Event" WHERE id = ${id}::uuid FOR UPDATE`;
      const event = await tx.event.findUnique({ where: { id } });
      if (!event) throw new ApiError('NOT_FOUND', 'Event not found', 404);
      await this.scope.assertClub(actor, event.clubId);
      await tx.event.delete({ where: { id } });
    });
    return { deleted: true };
  }
  async approve(actor: Actor, id: string, reject: boolean, reason?: string) {
    if (reject && !reason?.trim())
      throw new ApiError('VALIDATION_ERROR', 'Rejection reason required');
    const result = await this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "Event" WHERE id = ${id}::uuid FOR UPDATE`;
      const event = await tx.event.findUnique({
        where: { id },
        include: { club: true },
      });
      if (!event) throw new ApiError('NOT_FOUND', 'Event not found', 404);
      if (!reject && event.club.status !== 'APPROVED')
        throw new ApiError('VALIDATION_ERROR', 'Club must be approved');
      if (!['PENDING_APPROVAL', 'REJECTED'].includes(event.status))
        throw new ApiError(
          'INVALID_EVENT_STATUS',
          'Event is not awaiting approval',
          409,
        );
      return tx.event.update({
        where: { id },
        data: {
          status: reject ? 'REJECTED' : 'PUBLISHED',
          rejectionReason: reject ? reason : null,
        },
      });
    });
    if (!reject)
      await this.notifications.safe(() =>
        this.notifications.published(result.id),
      );
    return this.detail(actor, id);
  }
}
