import {
  Body,
  Controller,
  Delete,
  Get,
  Injectable,
  Module,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiProperty,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Prisma } from '@prisma/client';
import { Actor, CurrentUser, Roles, ScopeService } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { ApiError } from '../common/http';
import { page, pagination, PaginationDto } from '../common/pagination';
export class AnnouncementQuery extends PaginationDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() clubId?: string;
}
export class AnnouncementDto {
  @ApiProperty() @IsString() @MinLength(2) @MaxLength(200) title!: string;
  @ApiProperty() @IsString() @MinLength(2) @MaxLength(10000) body!: string;
  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsUUID()
  clubId?: string;
}
@Injectable()
export class AnnouncementsService {
  constructor(
    private db: PrismaService,
    private scope: ScopeService,
  ) {}
  async list(q: AnnouncementQuery) {
    const where: Prisma.AnnouncementWhereInput = {
      AND: [
        { OR: [{ clubId: null }, { club: { status: 'APPROVED' } }] },
        {
          clubId: q.clubId,
          ...(q.search
            ? { title: { contains: q.search, mode: 'insensitive' } }
            : {}),
        },
      ],
    };
    const [data, total] = await Promise.all([
      this.db.announcement.findMany({
        where,
        ...pagination(q, ['createdAt', 'title']),
      }),
      this.db.announcement.count({ where }),
    ]);
    return page(data, total, q);
  }
  async create(actor: Actor, input: AnnouncementDto) {
    if (!input.clubId && actor.role !== 'SUPER_ADMIN')
      throw new ApiError(
        'FORBIDDEN',
        'Campus announcements require super administrator',
        403,
      );
    if (input.clubId) {
      await this.scope.assertClub(actor, input.clubId);
      const club = await this.db.club.findUnique({
        where: { id: input.clubId },
      });
      if (club?.status !== 'APPROVED')
        throw new ApiError('VALIDATION_ERROR', 'Club must be approved');
    }
    return this.db.announcement.create({
      data: { ...input, authorId: actor.id },
    });
  }
  async remove(actor: Actor, id: string) {
    const item = await this.db.announcement.findUnique({ where: { id } });
    if (!item) throw new ApiError('NOT_FOUND', 'Announcement not found', 404);
    if (item.clubId) await this.scope.assertClub(actor, item.clubId);
    else if (actor.role !== 'SUPER_ADMIN')
      throw new ApiError('FORBIDDEN', 'Campus scope required', 403);
    await this.db.announcement.delete({ where: { id } });
    return { deleted: true };
  }
}
@ApiTags('Announcements')
@ApiBearerAuth()
@Controller('announcements')
export class AnnouncementsController {
  constructor(private announcements: AnnouncementsService) {}
  @Get() list(@Query() q: AnnouncementQuery) {
    return this.announcements.list(q);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Post() create(
    @CurrentUser() actor: Actor,
    @Body() input: AnnouncementDto,
  ) {
    return this.announcements.create(actor, input);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Delete(':id') remove(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.announcements.remove(actor, id);
  }
}
@Module({
  controllers: [AnnouncementsController],
  providers: [AnnouncementsService],
  exports: [AnnouncementsService],
})
export class AnnouncementsModule {}
