import {
  Body,
  Controller,
  Delete,
  Get,
  Module,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsEnum, IsString, MaxLength, MinLength } from 'class-validator';
import { Actor, CurrentUser } from '../common/security';
import { page, pagination, PaginationDto } from '../common/pagination';
import { PrismaService } from '../prisma/prisma.service';
import { CONFIG, Configuration } from '../config/environment';
import { FcmPushService, NoopPushService, PushService } from './push.service';
import { NotificationsService } from './notifications.service';
import { ApiError } from '../common/http';
export class DeviceDto {
  @ApiProperty() @IsString() @MinLength(10) @MaxLength(4096) token!: string;
  @ApiProperty({ enum: ['ANDROID', 'IOS', 'WEB'] })
  @IsEnum(['ANDROID', 'IOS', 'WEB'])
  platform!: string;
}
@ApiTags('Notifications')
@ApiBearerAuth()
@Controller()
export class NotificationsController {
  constructor(private db: PrismaService) {}
  @Get('me/notifications') async list(
    @CurrentUser() actor: Actor,
    @Query() q: PaginationDto,
  ) {
    const where = { userId: actor.id };
    const [data, total] = await Promise.all([
      this.db.notification.findMany({ where, ...pagination(q) }),
      this.db.notification.count({ where }),
    ]);
    return page(data, total, q);
  }
  @Get('me/notifications/unread-count') async unread(
    @CurrentUser() actor: Actor,
  ) {
    return {
      count: await this.db.notification.count({
        where: { userId: actor.id, readAt: null },
      }),
    };
  }
  @Patch('notifications/:id/read') async read(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    const result = await this.db.notification.updateMany({
      where: { id, userId: actor.id },
      data: { readAt: new Date() },
    });
    if (!result.count)
      throw new ApiError('NOT_FOUND', 'Notification not found', 404);
    return { read: true };
  }
  @Patch('me/notifications/read-all') async readAll(
    @CurrentUser() actor: Actor,
  ) {
    const result = await this.db.notification.updateMany({
      where: { userId: actor.id, readAt: null },
      data: { readAt: new Date() },
    });
    return { updated: result.count };
  }
  @Post('me/device-tokens') async device(
    @CurrentUser() actor: Actor,
    @Body() input: DeviceDto,
  ) {
    // Authenticated device owners may move their own device between signed-in accounts.
    await this.db.deviceToken.upsert({
      where: { token: input.token },
      create: { userId: actor.id, ...input },
      update: { userId: actor.id, platform: input.platform },
    });
    return { registered: true };
  }
  @Delete('me/device-tokens/:token') async remove(
    @CurrentUser() actor: Actor,
    @Param('token') token: string,
  ) {
    await this.db.deviceToken.deleteMany({
      where: { userId: actor.id, token },
    });
    return { deleted: true };
  }
}
@Module({
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    {
      provide: PushService,
      inject: [CONFIG],
      useFactory: (config: Configuration) =>
        config.firebase ? new FcmPushService(config) : new NoopPushService(),
    },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
