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
import { Actor, ClubScope, CurrentUser, Roles } from '../common/security';
import {
  ClubQuery,
  ClubStatusDto,
  CreateClubDto,
  UpdateClubDto,
} from './clubs.dto';
import { ClubsService } from './clubs.service';
@ApiTags('Clubs')
@ApiBearerAuth()
@Controller('clubs')
export class ClubsController {
  constructor(private clubs: ClubsService) {}
  @Get() list(@CurrentUser() actor: Actor, @Query() q: ClubQuery) {
    return this.clubs.list(actor, q, actor.role === 'SUPER_ADMIN');
  }
  @Get(':id') detail(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.clubs.detail(actor, id);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @Post() create(
    @CurrentUser() actor: Actor,
    @Body() input: CreateClubDto,
  ) {
    return this.clubs.create(actor, input);
  }
  @Roles('CLUB_ADMIN', 'SUPER_ADMIN') @ClubScope() @Patch(':id') update(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() input: UpdateClubDto,
  ) {
    return this.clubs.update(actor, id, input);
  }
  @Roles('SUPER_ADMIN') @Delete(':id') remove(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.clubs.remove(actor, id);
  }
  @Roles('SUPER_ADMIN') @Patch(':id/status') status(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() input: ClubStatusDto,
  ) {
    return this.clubs.status(id, input);
  }
  @Post(':id/follow') follow(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.clubs.follow(actor, id, true);
  }
  @Delete(':id/follow') unfollow(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.clubs.follow(actor, id, false);
  }
}
@ApiTags('Clubs')
@ApiBearerAuth()
@Controller('me/clubs')
export class MyClubsController {
  constructor(private clubs: ClubsService) {}
  /** Clubs the signed-in user administers (empty for students). */
  @Get() mine(@CurrentUser() actor: Actor) {
    return this.clubs.mine(actor);
  }
}
@Module({
  controllers: [ClubsController, MyClubsController],
  providers: [ClubsService],
  exports: [ClubsService],
})
export class ClubsModule {}
