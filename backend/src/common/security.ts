import { isUUID } from 'class-validator';
import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  Global,
  Injectable,
  Module,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PassportModule } from '@nestjs/passport';
import { PassportStrategy, AuthGuard } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Inject } from '@nestjs/common';
import { Role, Prisma } from '@prisma/client';
import { CONFIG, Configuration } from '../config/environment';
import { PrismaService } from '../prisma/prisma.service';
import { ApiError } from './http';
export const publicUserSelect = {
  id: true,
  email: true,
  firstName: true,
  lastName: true,
  studentId: true,
  avatarUrl: true,
  role: true,
  isActive: true,
  notifyNewEvents: true,
  notifyRegistrations: true,
  notifyEventUpdates: true,
  notifyReminders: true,
  pushEnabled: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;
export type Actor = Prisma.UserGetPayload<{ select: typeof publicUserSelect }>;
export const Public = () => SetMetadata('public', true);
export const Roles = (...roles: Role[]) => SetMetadata('roles', roles);
export const ClubScope = (param = 'id') => SetMetadata('clubScope', param);
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): Actor =>
    context.switchToHttp().getRequest().user,
);
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    @Inject(CONFIG) config: Configuration,
    private db: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.secret,
      algorithms: ['HS256'],
      issuer: 'est-clubs',
      audience: 'est-mobile',
    });
  }
  async validate(payload: { sub: string }) {
    if (typeof payload.sub !== 'string')
      throw new ApiError('UNAUTHORIZED', 'Invalid token', 401);
    const user = await this.db.user.findUnique({
      where: { id: payload.sub },
      select: publicUserSelect,
    });
    if (!user?.isActive)
      throw new ApiError('UNAUTHORIZED', 'Account unavailable', 401);
    return user;
  }
}
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }
  canActivate(context: ExecutionContext) {
    if (
      this.reflector.getAllAndOverride<boolean>('public', [
        context.getHandler(),
        context.getClass(),
      ])
    )
      return true;
    return super.canActivate(context);
  }
}
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(context: ExecutionContext) {
    const roles = this.reflector.getAllAndOverride<Role[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);
    const actor = context.switchToHttp().getRequest().user as Actor | undefined;
    if (roles && (!actor || !roles.includes(actor.role)))
      throw new ApiError('FORBIDDEN', 'Insufficient permissions', 403);
    return true;
  }
}
@Injectable()
export class ScopeService {
  constructor(private db: PrismaService) {}
  async assertClub(actor: Actor, clubId: string) {
    if (!isUUID(clubId))
      throw new ApiError('VALIDATION_ERROR', 'Invalid club UUID');
    if (actor.role === 'SUPER_ADMIN') return;
    if (
      actor.role !== 'CLUB_ADMIN' ||
      !(await this.db.clubMember.findFirst({
        where: { clubId, userId: actor.id, role: 'ADMIN' },
      }))
    )
      throw new ApiError('FORBIDDEN', 'Club access denied', 403);
  }
  async clubIds(actor: Actor) {
    return (
      await this.db.clubMember.findMany({
        where: { userId: actor.id, role: 'ADMIN' },
        select: { clubId: true },
      })
    ).map((m) => m.clubId);
  }
}
@Injectable()
export class ClubScopeGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private scope: ScopeService,
  ) {}
  async canActivate(context: ExecutionContext) {
    const key = this.reflector.getAllAndOverride<string>('clubScope', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (key) {
      const req = context.switchToHttp().getRequest();
      await this.scope.assertClub(req.user, req.params[key]);
    }
    return true;
  }
}
@Global()
@Module({
  imports: [PassportModule],
  providers: [JwtStrategy, ScopeService],
  exports: [ScopeService, PassportModule],
})
export class SecurityModule {}
