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
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Actor, CurrentUser, Roles } from '../common/security';
import { NotificationsModule } from '../notifications/notifications.module';
import { ClubsModule } from '../clubs/clubs.module';
import { ClubsService } from '../clubs/clubs.service';
import {
  ApprovalDto,
  CreateEventDto,
  EventQuery,
  UpdateEventDto,
} from './events.dto';
import { EventsService } from './events.service';
@ApiTags('Events')
@ApiBearerAuth()
@Controller()
export class EventsController {
  constructor(
    private events: EventsService,
    private clubs: ClubsService,
  ) {}
  @Get('events') list(@CurrentUser() actor: Actor, @Query() q: EventQuery) {
    return this.events.list(actor, q);
  }
  @Get('clubs/:id/events') async clubEvents(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Query() q: EventQuery,
  ) {
    await this.clubs.detail(actor, id);
    return this.events.list(actor, Object.assign(q, { clubId: id }));
  }
  @Get('events/:id') detail(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.events.detail(actor, id);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Post('events') create(
    @CurrentUser() actor: Actor,
    @Body() input: CreateEventDto,
  ) {
    return this.events.create(actor, input);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Patch('events/:id') update(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() input: UpdateEventDto,
  ) {
    return this.events.update(actor, id, input);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Delete('events/:id') remove(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.events.remove(actor, id);
  }
  @Roles('SUPER_ADMIN') @Patch('events/:id/approve') approve(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.events.approve(actor, id, false);
  }
  @Roles('SUPER_ADMIN') @Patch('events/:id/reject') reject(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() input: ApprovalDto,
  ) {
    return this.events.approve(actor, id, true, input.rejectionReason);
  }
}
@Module({
  imports: [NotificationsModule, ClubsModule],
  controllers: [EventsController],
  providers: [EventsService],
  exports: [EventsService],
})
export class EventsModule {}
