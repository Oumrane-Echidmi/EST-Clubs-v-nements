import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Actor, ScopeService } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { ApiError } from '../common/http';
import { page, pagination } from '../common/pagination';
import {
  ClubQuery,
  ClubStatusDto,
  CreateClubDto,
  UpdateClubDto,
} from './clubs.dto';
@Injectable()
export class ClubsService {
  constructor(
    private db: PrismaService,
    private scope: ScopeService,
  ) {}
  async list(actor: Actor, q: ClubQuery, admin = false) {
    const ownIds =
      actor.role === 'CLUB_ADMIN' ? await this.scope.clubIds(actor) : [];
    const visible: Prisma.ClubWhereInput =
      actor.role === 'SUPER_ADMIN' && admin
        ? {}
        : {
            OR: [
              { status: 'APPROVED' },
              ...(ownIds.length ? [{ id: { in: ownIds } }] : []),
            ],
          };
    return this.listVisible(actor, q, visible);
  }
  async mine(actor: Actor, q: ClubQuery) {
    pagination(q, ['createdAt', 'name']);
    if (actor.role === 'STUDENT') return page([], 0, q);
    return this.listVisible(
      actor,
      q,
      {
        members: { some: { userId: actor.id, role: 'ADMIN' } },
      },
      q.sortBy === undefined,
    );
  }
  private listInclude(userId: string) {
    return {
      _count: { select: { followers: true, members: true, events: true } },
      followers: { where: { userId }, select: { id: true } },
    } satisfies Prisma.ClubInclude;
  }
  private async approvedFirstPage(
    actor: Actor,
    q: ClubQuery,
    where: Prisma.ClubWhereInput,
  ) {
    // Page across the approved/non-approved boundary without loading unbounded memberships.
    return this.db.$transaction(
      async (tx) => {
        const approvedWhere: Prisma.ClubWhereInput = {
          AND: [where, { status: 'APPROVED' }],
        };
        const [total, approvedTotal] = await Promise.all([
          tx.club.count({ where }),
          tx.club.count({ where: approvedWhere }),
        ]);
        const offset = (q.page - 1) * q.limit;
        const approvedTake = Math.min(
          q.limit,
          Math.max(0, approvedTotal - offset),
        );
        const otherTake = q.limit - approvedTake;
        const orderBy: Prisma.ClubOrderByWithRelationInput[] = [
          { name: 'asc' },
          { id: 'asc' },
        ];
        const include = this.listInclude(actor.id);
        const [approved, others] = await Promise.all([
          approvedTake
            ? tx.club.findMany({
                where: approvedWhere,
                skip: offset,
                take: approvedTake,
                orderBy,
                include,
              })
            : Promise.resolve([]),
          otherTake
            ? tx.club.findMany({
                where: { AND: [where, { status: { not: 'APPROVED' } }] },
                skip: Math.max(0, offset - approvedTotal),
                take: otherTake,
                orderBy,
                include,
              })
            : Promise.resolve([]),
        ]);
        return [[...approved, ...others], total] as const;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
  private async listVisible(
    actor: Actor,
    q: ClubQuery,
    visible: Prisma.ClubWhereInput,
    approvedFirst = false,
  ) {
    const where: Prisma.ClubWhereInput = {
      AND: [
        visible,
        {
          status: q.status,
          category: q.category,
          ...(q.search
            ? {
                OR: [
                  { name: { contains: q.search, mode: 'insensitive' } },
                  { description: { contains: q.search, mode: 'insensitive' } },
                ],
              }
            : {}),
        },
      ],
    };
    const options = pagination(q, ['createdAt', 'name']);
    const [data, total] = approvedFirst
      ? await this.approvedFirstPage(actor, q, where)
      : await Promise.all([
          this.db.club.findMany({
            where,
            ...options,
            include: this.listInclude(actor.id),
          }),
          this.db.club.count({ where }),
        ]);
    return page(
      data.map(({ followers, ...club }) => ({
        ...club,
        isFollowed: followers.length > 0,
      })),
      total,
      q,
    );
  }
  async dashboard(actor: Actor, id: string) {
    await this.scope.assertClub(actor, id);
    return this.db.$transaction(
      async (tx) => {
        const club = await tx.club.findUnique({
          where: { id },
          include: {
            _count: {
              select: { members: true, followers: true, events: true },
            },
          },
        });
        if (!club) throw new ApiError('NOT_FOUND', 'Club not found', 404);
        const active: Prisma.RegistrationWhereInput = {
          status: { in: ['CONFIRMED', 'ATTENDED'] },
        };
        const [statuses, activeRegistrations, events] = await Promise.all([
          tx.event.groupBy({
            by: ['status'],
            where: { clubId: id },
            _count: { _all: true },
          }),
          tx.registration.count({
            where: { ...active, event: { clubId: id } },
          }),
          tx.event.findMany({
            where: {
              clubId: id,
              status: 'PUBLISHED',
              startsAt: { gt: new Date() },
            },
            select: { id: true, title: true, startsAt: true, capacity: true },
            orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
            take: 20,
          }),
        ]);
        const counts = events.length
          ? await tx.registration.groupBy({
              by: ['eventId'],
              where: {
                ...active,
                eventId: { in: events.map((event) => event.id) },
              },
              _count: { _all: true },
            })
          : [];
        const countMap = new Map(
          counts.map((count) => [count.eventId, count._count._all]),
        );
        return {
          clubId: id,
          counts: {
            members: club._count.members,
            followers: club._count.followers,
            events: club._count.events,
            publishedEvents:
              statuses.find((group) => group.status === 'PUBLISHED')?._count
                ._all ?? 0,
            pendingEvents:
              statuses.find((group) => group.status === 'PENDING_APPROVAL')
                ?._count._all ?? 0,
            activeRegistrations,
          },
          eventFillRates: events.map((event) => {
            const registeredCount = countMap.get(event.id) ?? 0;
            return {
              eventId: event.id,
              title: event.title,
              startsAt: event.startsAt,
              capacity: event.capacity,
              registeredCount,
              availableSeats: event.capacity - registeredCount,
              fillRate: registeredCount / event.capacity,
            };
          }),
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
  async detail(actor: Actor, id: string) {
    const club = await this.db.club.findUnique({
      where: { id },
      include: {
        _count: { select: { members: true, followers: true, events: true } },
        followers: { where: { userId: actor.id }, select: { id: true } },
      },
    });
    if (!club) throw new ApiError('NOT_FOUND', 'Club not found', 404);
    if (club.status !== 'APPROVED' && actor.role !== 'SUPER_ADMIN') {
      if (actor.role === 'STUDENT')
        throw new ApiError('NOT_FOUND', 'Club not found', 404);
      await this.scope.assertClub(actor, id);
    }
    const { followers, ...result } = club;
    return { ...result, isFollowed: followers.length > 0 };
  }
  async create(actor: Actor, input: CreateClubDto) {
    return this.db.$transaction(async (tx) => {
      const club = await tx.club.create({
        data: {
          ...input,
          status: actor.role === 'SUPER_ADMIN' ? 'APPROVED' : 'PENDING',
        },
      });
      if (actor.role === 'CLUB_ADMIN')
        await tx.clubMember.create({
          data: { clubId: club.id, userId: actor.id, role: 'ADMIN' },
        });
      return club;
    });
  }
  async update(actor: Actor, id: string, input: UpdateClubDto) {
    await this.scope.assertClub(actor, id);
    return this.db.club.update({ where: { id }, data: input });
  }
  async remove(actor: Actor, id: string) {
    await this.scope.assertClub(actor, id);
    await this.db.club.delete({ where: { id } });
    return { deleted: true };
  }
  async status(id: string, input: ClubStatusDto) {
    if (input.status === 'REJECTED' && !input.rejectionReason?.trim())
      throw new ApiError('VALIDATION_ERROR', 'Rejection reason required');
    return this.db.club.update({
      where: { id },
      data: {
        ...input,
        rejectionReason:
          input.status === 'REJECTED' ? input.rejectionReason : null,
      },
    });
  }
  async follow(actor: Actor, id: string, follow: boolean) {
    const club = await this.detail(actor, id);
    if (follow && club.status !== 'APPROVED')
      throw new ApiError(
        'FORBIDDEN',
        'Only approved clubs can be followed',
        403,
      );
    if (follow)
      await this.db.clubFollow.upsert({
        where: { clubId_userId: { clubId: id, userId: actor.id } },
        create: { clubId: id, userId: actor.id },
        update: {},
      });
    else
      await this.db.clubFollow.deleteMany({
        where: { clubId: id, userId: actor.id },
      });
    return { isFollowed: follow };
  }
}
