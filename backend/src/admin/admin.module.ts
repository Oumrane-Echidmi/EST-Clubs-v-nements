import {
  Body,
  Controller,
  Get,
  Module,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiProperty,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsOptional, IsUUID } from 'class-validator';
import { Prisma, Role } from '@prisma/client';
import {
  Actor,
  CurrentUser,
  publicUserSelect,
  Roles,
} from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { ApiError } from '../common/http';
import { page, pagination, PaginationDto } from '../common/pagination';
import { ClubsModule } from '../clubs/clubs.module';
import { ClubsService } from '../clubs/clubs.service';
import { ClubQuery } from '../clubs/clubs.dto';
import { EventsModule } from '../events/events.module';
import { EventsService } from '../events/events.service';
import { EventQuery } from '../events/events.dto';
export class AdminUserDto {
  @ApiPropertyOptional({ enum: Role }) @IsOptional() @IsEnum(Role) role?: Role;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isActive?: boolean;
}
export class AssignAdminDto {
  @ApiProperty() @IsUUID() userId!: string;
}
@ApiTags('Administration')
@ApiBearerAuth()
@Roles('SUPER_ADMIN')
@Controller('admin')
export class AdminController {
  constructor(
    private db: PrismaService,
    private clubs: ClubsService,
    private events: EventsService,
  ) {}
  @Get('dashboard') async dashboard() {
    const since = new Date(Date.now() - 30 * 86400000);
    const [
      users,
      clubs,
      events,
      registrations,
      pendingClubs,
      pendingEvents,
      dailyRegistrations,
      topClubs,
      fillRates,
    ] = await Promise.all([
      this.db.user.count(),
      this.db.club.count(),
      this.db.event.count(),
      this.db.registration.count({
        where: { status: { in: ['CONFIRMED', 'ATTENDED'] } },
      }),
      this.db.club.count({ where: { status: 'PENDING' } }),
      this.db.event.count({ where: { status: 'PENDING_APPROVAL' } }),
      this.db.$queryRaw<
        { date: string; count: number }[]
      >`SELECT to_char("registeredAt" AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS date, COUNT(*)::integer AS count FROM "Registration" WHERE "registeredAt" >= ${since} GROUP BY date ORDER BY date`,
      this.db.$queryRaw<
        { id: string; name: string; registrations: number }[]
      >`SELECT c.id, c.name, COUNT(r.id)::integer AS registrations FROM "Club" c LEFT JOIN "Event" e ON e."clubId" = c.id LEFT JOIN "Registration" r ON r."eventId" = e.id AND r.status IN ('CONFIRMED', 'ATTENDED') GROUP BY c.id ORDER BY registrations DESC, c.id LIMIT 5`,
      this.db.$queryRaw<
        {
          eventId: string;
          title: string;
          capacity: number;
          registeredCount: number;
          fillRate: number;
        }[]
      >`SELECT e.id AS "eventId", e.title, e.capacity, COUNT(r.id)::integer AS "registeredCount", (COUNT(r.id)::float / e.capacity) AS "fillRate" FROM "Event" e LEFT JOIN "Registration" r ON r."eventId" = e.id AND r.status IN ('CONFIRMED', 'ATTENDED') WHERE e.status = 'PUBLISHED' GROUP BY e.id ORDER BY e."startsAt" DESC LIMIT 20`,
    ]);
    return {
      counts: {
        users,
        clubs,
        events,
        registrations,
        pendingClubs,
        pendingEvents,
      },
      dailyRegistrations,
      topClubs,
      fillRates,
    };
  }
  @Get('users') async users(@Query() q: PaginationDto) {
    const where: Prisma.UserWhereInput = q.search
      ? {
          OR: [
            { email: { contains: q.search, mode: 'insensitive' } },
            { firstName: { contains: q.search, mode: 'insensitive' } },
            { lastName: { contains: q.search, mode: 'insensitive' } },
          ],
        }
      : {};
    const [data, total] = await Promise.all([
      this.db.user.findMany({
        where,
        ...pagination(q, ['createdAt', 'email']),
        select: publicUserSelect,
      }),
      this.db.user.count({ where }),
    ]);
    return page(data, total, q);
  }
  @Patch('users/:id') async update(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() input: AdminUserDto,
  ) {
    if (
      id === actor.id &&
      (input.isActive === false || (input.role && input.role !== 'SUPER_ADMIN'))
    )
      throw new ApiError(
        'FORBIDDEN',
        'Cannot deactivate or demote yourself',
        403,
      );
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${id}::uuid FOR UPDATE`;
      const user = await tx.user.update({
        where: { id },
        data: input,
        select: publicUserSelect,
      });
      if (input.isActive === false || input.role)
        await tx.refreshToken.updateMany({
          where: { userId: id },
          data: { revokedAt: new Date() },
        });
      return user;
    });
  }
  @Post('clubs/:id/admins') async assign(
    @Param('id', ParseUUIDPipe) clubId: string,
    @Body() input: AssignAdminDto,
  ) {
    return this.db.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: input.userId } });
      if (!user?.isActive)
        throw new ApiError('VALIDATION_ERROR', 'Active user required');
      if (user.role === 'STUDENT')
        await tx.user.update({
          where: { id: user.id },
          data: { role: 'CLUB_ADMIN' },
        });
      return tx.clubMember.upsert({
        where: { clubId_userId: { clubId, userId: user.id } },
        create: { clubId, userId: user.id, role: 'ADMIN' },
        update: { role: 'ADMIN' },
      });
    });
  }
  @Get('clubs') listClubs(@CurrentUser() actor: Actor, @Query() q: ClubQuery) {
    return this.clubs.list(actor, q, true);
  }
  @Get('events') listEvents(
    @CurrentUser() actor: Actor,
    @Query() q: EventQuery,
  ) {
    return this.events.list(actor, q);
  }
}
@Module({
  imports: [ClubsModule, EventsModule],
  controllers: [AdminController],
})
export class AdminModule {}
