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
import { EventsModule } from '../events/events.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaginationDto } from '../common/pagination';
import { RegistrationQuery, RegistrationUpdateDto } from './registrations.dto';
import { RegistrationsService } from './registrations.service';
@ApiTags('Registrations')
@ApiBearerAuth()
@Controller()
export class RegistrationsController {
  constructor(private registrations: RegistrationsService) {}
  @Roles('STUDENT') @Post('events/:id/register') register(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.registrations.register(actor, id);
  }
  @Delete('registrations/:id') cancel(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.registrations.change(actor, id, 'CANCELLED', true);
  }
  @Get('me/registrations') mine(
    @CurrentUser() actor: Actor,
    @Query() q: RegistrationQuery,
  ) {
    return this.registrations.mine(actor, q);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN')
  @Get('events/:id/registrations')
  attendees(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Query() q: PaginationDto,
  ) {
    return this.registrations.attendees(actor, id, q);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Patch('registrations/:id') change(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() input: RegistrationUpdateDto,
  ) {
    return this.registrations.change(actor, id, input.status);
  }
}
@Module({
  imports: [EventsModule, NotificationsModule],
  controllers: [RegistrationsController],
  providers: [RegistrationsService],
})
export class RegistrationsModule {}
