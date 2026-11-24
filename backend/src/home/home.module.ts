import { Controller, Get, Module, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Prisma } from '@prisma/client';
import { Actor, CurrentUser } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { page, pagination, PaginationDto } from '../common/pagination';
import { EventsModule } from '../events/events.module';
import { EventsService } from '../events/events.service';
import {
  AnnouncementsModule,
  AnnouncementsService,
} from '../announcements/announcements.module';
@ApiTags('Home')
@ApiBearerAuth()
@Controller('home')
export class HomeController {
  constructor(
    private db: PrismaService,
    private events: EventsService,
    private announcements: AnnouncementsService,
  ) {}
  @Get() async home(@CurrentUser() actor: Actor, @Query() q: PaginationDto) {
    const options = pagination(q, ['startsAt']);
    const [followed, past] = await Promise.all([
      this.db.clubFollow.findMany({
        where: { userId: actor.id },
        select: { club: { select: { category: true } } },
      }),
      this.db.registration.findMany({
        where: { userId: actor.id, status: { in: ['CONFIRMED', 'ATTENDED'] } },
        distinct: ['eventId'],
        select: { event: { select: { category: true } } },
        take: 100,
        orderBy: { registeredAt: 'desc' },
      }),
    ]);
    const categories = [
      ...new Set([
        ...followed.map((f) => f.club.category),
        ...past.map((r) => r.event.category),
      ]),
    ];
    const where: Prisma.EventWhereInput = {
      status: 'PUBLISHED',
      startsAt: { gt: new Date() },
      club: { status: 'APPROVED' },
    };
    const recommended: Prisma.EventWhereInput = {
      ...where,
      ...(categories.length ? { category: { in: categories } } : {}),
      registrations: {
        none: { userId: actor.id, status: { in: ['CONFIRMED', 'ATTENDED'] } },
      },
    };
    const clubWhere = { status: 'APPROVED' as const, isFeatured: true };
    const [
      upcoming,
      upcomingCount,
      suggestions,
      suggestionCount,
      clubs,
      clubCount,
      announcements,
    ] = await Promise.all([
      this.db.event.findMany({ where, ...options }),
      this.db.event.count({ where }),
      this.db.event.findMany({ where: recommended, ...options }),
      this.db.event.count({ where: recommended }),
      this.db.club.findMany({
        where: clubWhere,
        skip: options.skip,
        take: options.take,
        orderBy: { name: 'asc' },
      }),
      this.db.club.count({ where: clubWhere }),
      this.announcements.list(
        Object.assign(new PaginationDto(), {
          page: q.page,
          limit: q.limit,
          sortOrder: 'desc',
        }),
      ),
    ]);
    const decorated = new Map(
      (await this.events.decorate([...upcoming, ...suggestions], actor)).map(
        (e) => [e.id, e],
      ),
    );
    return {
      upcomingEvents: page(
        upcoming.map((e) => decorated.get(e.id)),
        upcomingCount,
        q,
      ),
      featuredClubs: page(clubs, clubCount, q),
      announcements,
      recommendedEvents: page(
        suggestions.map((e) => decorated.get(e.id)),
        suggestionCount,
        q,
      ),
    };
  }
}
@Module({
  imports: [EventsModule, AnnouncementsModule],
  controllers: [HomeController],
})
export class HomeModule {}
