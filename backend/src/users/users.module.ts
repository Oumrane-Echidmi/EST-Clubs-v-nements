import { Body, Controller, Get, Module, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Actor, CurrentUser, publicUserSelect } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { AuthModule } from '../auth/auth.module';
import { AuthService } from '../auth/auth.service';
import { PasswordDto, PreferencesDto, ProfileDto } from './users.dto';
@ApiTags('Profile')
@ApiBearerAuth()
@Controller('me')
export class UsersController {
  constructor(
    private db: PrismaService,
    private auth: AuthService,
  ) {}
  @Get() me(@CurrentUser() actor: Actor) {
    return actor;
  }
  @Patch() update(@CurrentUser() actor: Actor, @Body() input: ProfileDto) {
    return this.db.user.update({
      where: { id: actor.id },
      data: input,
      select: publicUserSelect,
    });
  }
  @Patch('password') password(
    @CurrentUser() actor: Actor,
    @Body() input: PasswordDto,
  ) {
    return this.auth.changePassword(
      actor.id,
      input.currentPassword,
      input.password,
    );
  }
  @Patch('notification-preferences') preferences(
    @CurrentUser() actor: Actor,
    @Body() input: PreferencesDto,
  ) {
    return this.db.user.update({
      where: { id: actor.id },
      data: input,
      select: publicUserSelect,
    });
  }
}
@Module({ imports: [AuthModule], controllers: [UsersController] })
export class UsersModule {}
