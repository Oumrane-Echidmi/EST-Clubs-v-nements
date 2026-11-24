import { Body, Controller, Get, HttpCode, Module, Post } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Actor, CurrentUser, Public } from '../common/security';
import { AuthService } from './auth.service';
import {
  EmailDto,
  LoginDto,
  LogoutDto,
  RefreshDto,
  RegisterDto,
  ResetDto,
} from './auth.dto';
import { ConfiguredMailService, MailService } from './mail.service';
@ApiTags('Authentication')
@Controller('auth')
@Throttle({ default: { limit: 10, ttl: 900000 } })
export class AuthController {
  constructor(private auth: AuthService) {}
  @Public() @Post('register') register(@Body() input: RegisterDto) {
    return this.auth.register(input);
  }
  @Public() @Post('login') @HttpCode(200) login(@Body() input: LoginDto) {
    return this.auth.login(input);
  }
  @Public() @Post('refresh') @HttpCode(200) refresh(@Body() input: RefreshDto) {
    return this.auth.refresh(input.refreshToken);
  }
  @Public() @Post('logout') @HttpCode(200) logout(@Body() input: LogoutDto) {
    return this.auth.logout(input.refreshToken, input.deviceToken);
  }
  @Public() @Post('forgot-password') @HttpCode(200) forgot(
    @Body() input: EmailDto,
  ) {
    return this.auth.forgot(input.email);
  }
  @Public() @Post('reset-password') @HttpCode(200) reset(
    @Body() input: ResetDto,
  ) {
    return this.auth.reset(input.token, input.password);
  }
  @ApiBearerAuth() @Get('me') me(@CurrentUser() actor: Actor) {
    return actor;
  }
}
@Module({
  imports: [JwtModule.register({})],
  controllers: [AuthController],
  providers: [
    AuthService,
    { provide: MailService, useClass: ConfiguredMailService },
  ],
  exports: [AuthService],
})
export class AuthModule {}
