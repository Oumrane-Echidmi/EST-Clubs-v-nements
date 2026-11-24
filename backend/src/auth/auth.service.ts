import { Inject, Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import { createHash, randomBytes, randomUUID } from 'crypto';
import bcrypt from 'bcrypt';
import { CONFIG, Configuration } from '../config/environment';
import { PrismaService } from '../prisma/prisma.service';
import { ApiError } from '../common/http';
import { Actor, publicUserSelect } from '../common/security';
import { LoginDto, RegisterDto } from './auth.dto';
import { MailService } from './mail.service';
export const hashToken = (token: string) =>
  createHash('sha256').update(token).digest('hex');
@Injectable()
export class AuthService {
  private logger = new Logger(AuthService.name);
  constructor(
    private db: PrismaService,
    private jwt: JwtService,
    @Inject(CONFIG) private config: Configuration,
    private mail: MailService,
  ) {}
  private async session(
    tx: Prisma.TransactionClient,
    user: Actor,
    familyId: string = randomUUID(),
  ) {
    const refreshToken = randomBytes(48).toString('hex');
    await tx.refreshToken.create({
      data: {
        userId: user.id,
        familyId,
        tokenHash: hashToken(refreshToken),
        expiresAt: new Date(Date.now() + this.config.refreshDays * 86400000),
      },
    });
    return {
      user,
      accessToken: await this.jwt.signAsync(
        { sub: user.id },
        {
          secret: this.config.secret,
          expiresIn: this.config.accessTtl,
          issuer: 'est-clubs',
          audience: 'est-mobile',
          algorithm: 'HS256',
        },
      ),
      refreshToken,
      expiresIn: this.config.accessTtl,
    };
  }
  async register(input: RegisterDto) {
    if (Buffer.byteLength(input.password, 'utf8') > 72)
      throw new ApiError('VALIDATION_ERROR', 'Password exceeds 72 bytes');
    const passwordHash = await bcrypt.hash(input.password, 12);
    return this.db.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email: input.email,
          passwordHash,
          firstName: input.firstName,
          lastName: input.lastName,
          studentId: input.studentId,
          role: 'STUDENT',
        },
        select: publicUserSelect,
      });
      return this.session(tx, user);
    });
  }
  async login(input: LoginDto) {
    const found = await this.db.user.findUnique({
      where: { email: input.email },
    });
    // Perform bcrypt for unknown accounts as well to reduce timing differences.
    const valid = await bcrypt.compare(
      input.password,
      found?.passwordHash ??
        '$2b$12$Tfo4pgeL.CqzhHJN.lmr6uOMqxBAW0agL/9VHm2xkEcLXZKLvtfKu',
    );
    if (!found || !valid || !found.isActive)
      throw new ApiError(
        'INVALID_CREDENTIALS',
        'Invalid email or password',
        401,
      );
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${found.id}::uuid FOR UPDATE`;
      const current = await tx.user.findUniqueOrThrow({
        where: { id: found.id },
      });
      if (!current.isActive || current.passwordHash !== found.passwordHash)
        throw new ApiError(
          'INVALID_CREDENTIALS',
          'Invalid email or password',
          401,
        );
      const user = await tx.user.findUniqueOrThrow({
        where: { id: found.id },
        select: publicUserSelect,
      });
      return this.session(tx, user);
    });
  }
  async refresh(token: string) {
    const tokenHash = hashToken(token);
    const found = await this.db.refreshToken.findUnique({
      where: { tokenHash },
    });
    if (!found)
      throw new ApiError('INVALID_REFRESH_TOKEN', 'Refresh token invalid', 401);
    const result = await this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${found.userId}::uuid FOR UPDATE`;
      const current = await tx.refreshToken.findUniqueOrThrow({
        where: { tokenHash },
      });
      if (current.usedAt || current.revokedAt) {
        await tx.refreshToken.updateMany({
          where: { familyId: current.familyId, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        return null; // Commit revocation before returning an authentication error.
      }
      const user = await tx.user.findUniqueOrThrow({
        where: { id: current.userId },
        select: publicUserSelect,
      });
      if (!user.isActive || current.expiresAt <= new Date()) return null;
      await tx.refreshToken.update({
        where: { id: current.id },
        data: { usedAt: new Date() },
      });
      return this.session(tx, user, current.familyId);
    });
    if (!result)
      throw new ApiError(
        'INVALID_REFRESH_TOKEN',
        'Refresh token invalid or reused',
        401,
      );
    return result;
  }
  async logout(token: string, deviceToken?: string) {
    const current = await this.db.refreshToken.findUnique({
      where: { tokenHash: hashToken(token) },
    });
    if (current)
      await this.db.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${current.userId}::uuid FOR UPDATE`;
        await tx.refreshToken.updateMany({
          where: { familyId: current.familyId },
          data: { revokedAt: new Date() },
        });
        if (deviceToken)
          await tx.deviceToken.deleteMany({
            where: { userId: current.userId, token: deviceToken },
          });
      });
    return { loggedOut: true };
  }
  async forgot(email: string) {
    const user = await this.db.user.findUnique({ where: { email } });
    if (user?.isActive) {
      const token = randomBytes(48).toString('hex');
      await this.db.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${user.id}::uuid FOR UPDATE`;
        await tx.passwordResetToken.updateMany({
          where: { userId: user.id, usedAt: null },
          data: { usedAt: new Date() },
        });
        await tx.passwordResetToken.create({
          data: {
            userId: user.id,
            tokenHash: hashToken(token),
            expiresAt: new Date(Date.now() + this.config.resetMinutes * 60000),
          },
        });
      });
      try {
        await this.mail.sendReset(email, token);
      } catch {
        this.logger.error('Password reset delivery failed');
      }
    }
    return {
      message:
        'If the account exists, password reset instructions have been sent.',
    };
  }
  async reset(token: string, password: string) {
    if (Buffer.byteLength(password, 'utf8') > 72)
      throw new ApiError('VALIDATION_ERROR', 'Password exceeds 72 bytes');
    const found = await this.db.passwordResetToken.findUnique({
      where: { tokenHash: hashToken(token) },
    });
    if (!found)
      throw new ApiError('INVALID_RESET_TOKEN', 'Reset token invalid');
    const passwordHash = await bcrypt.hash(password, 12);
    await this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${found.userId}::uuid FOR UPDATE`;
      const current = await tx.passwordResetToken.findUniqueOrThrow({
        where: { id: found.id },
      });
      const user = await tx.user.findUniqueOrThrow({
        where: { id: found.userId },
      });
      if (current.usedAt || current.expiresAt <= new Date() || !user.isActive)
        throw new ApiError('INVALID_RESET_TOKEN', 'Reset token invalid');
      await tx.user.update({
        where: { id: current.userId },
        data: { passwordHash },
      });
      await tx.passwordResetToken.updateMany({
        where: { userId: current.userId, usedAt: null },
        data: { usedAt: new Date() },
      });
      await tx.refreshToken.updateMany({
        where: { userId: current.userId },
        data: { revokedAt: new Date() },
      });
    });
    return { reset: true };
  }
  async changePassword(userId: string, oldPassword: string, password: string) {
    const user = await this.db.user.findUniqueOrThrow({
      where: { id: userId },
    });
    if (!(await bcrypt.compare(oldPassword, user.passwordHash)))
      throw new ApiError(
        'INVALID_CREDENTIALS',
        'Current password incorrect',
        401,
      );
    if (Buffer.byteLength(password, 'utf8') > 72)
      throw new ApiError('VALIDATION_ERROR', 'Password exceeds 72 bytes');
    const passwordHash = await bcrypt.hash(password, 12);
    await this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId}::uuid FOR UPDATE`;
      const current = await tx.user.findUniqueOrThrow({
        where: { id: userId },
      });
      if (current.passwordHash !== user.passwordHash)
        throw new ApiError('CONFLICT', 'Password changed concurrently', 409);
      await tx.user.update({ where: { id: userId }, data: { passwordHash } });
      await tx.refreshToken.updateMany({
        where: { userId },
        data: { revokedAt: new Date() },
      });
      await tx.passwordResetToken.updateMany({
        where: { userId, usedAt: null },
        data: { usedAt: new Date() },
      });
    });
    return { changed: true };
  }
}
