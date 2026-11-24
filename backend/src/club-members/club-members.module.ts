import {
  Body,
  Controller,
  Delete,
  Get,
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
import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { MemberRole } from '@prisma/client';
import { Actor, ClubScope, CurrentUser, Roles } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { page, pagination, PaginationDto } from '../common/pagination';
export class MemberDto {
  @ApiProperty() @IsUUID() userId!: string;
  @ApiPropertyOptional({ enum: MemberRole, default: 'MEMBER' })
  @IsOptional()
  @IsEnum(MemberRole)
  role: MemberRole = 'MEMBER';
}
@ApiTags('Club members')
@ApiBearerAuth()
@Roles('CLUB_ADMIN', 'SUPER_ADMIN')
@ClubScope('clubId')
@Controller('clubs/:clubId/members')
export class ClubMembersController {
  constructor(private db: PrismaService) {}
  @Get() async list(
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Query() q: PaginationDto,
  ) {
    const [data, total] = await Promise.all([
      this.db.clubMember.findMany({
        where: { clubId },
        ...pagination(q, ['joinedAt']),
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
              email: true,
            },
          },
        },
      }),
      this.db.clubMember.count({ where: { clubId } }),
    ]);
    return page(data, total, q);
  }
  @Post() async add(
    @CurrentUser() actor: Actor,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Body() input: MemberDto,
  ) {
    const existing = await this.db.clubMember.findUnique({
      where: { clubId_userId: { clubId, userId: input.userId } },
    });
    if (existing?.role === 'ADMIN' && actor.role !== 'SUPER_ADMIN')
      throw new ApiError(
        'FORBIDDEN',
        'Only super administrators change administrator memberships',
        403,
      );
    if (input.role === 'ADMIN' && actor.role !== 'SUPER_ADMIN')
      throw new ApiError(
        'FORBIDDEN',
        'Only super administrators assign club administrators',
        403,
      );
    if (input.role === 'ADMIN') {
      const user = await this.db.user.findUnique({
        where: { id: input.userId },
      });
      if (!user || !user.isActive || user.role === 'STUDENT')
        throw new ApiError(
          'VALIDATION_ERROR',
          'An active administrator is required',
        );
    }
    return this.db.clubMember.upsert({
      where: { clubId_userId: { clubId, userId: input.userId } },
      create: { clubId, ...input },
      update: actor.role === 'SUPER_ADMIN' ? { role: input.role } : {},
    });
  }
  @Delete(':userId') async remove(
    @CurrentUser() actor: Actor,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    const member = await this.db.clubMember.findUnique({
      where: { clubId_userId: { clubId, userId } },
    });
    if (member?.role === 'ADMIN' && actor.role !== 'SUPER_ADMIN')
      throw new ApiError(
        'FORBIDDEN',
        'Only super administrators remove club administrators',
        403,
      );
    await this.db.clubMember.deleteMany({
      where: {
        clubId,
        userId,
        ...(actor.role === 'SUPER_ADMIN' ? {} : { role: 'MEMBER' as const }),
      },
    });
    return { deleted: true };
  }
}
import { ApiError } from '../common/http';
@Module({ controllers: [ClubMembersController] })
export class ClubMembersModule {}
