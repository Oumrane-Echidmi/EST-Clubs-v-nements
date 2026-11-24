import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { ConfigModule } from './config/environment';
import { PrismaModule } from './prisma/prisma.service';
import {
  ClubScopeGuard,
  JwtAuthGuard,
  RolesGuard,
  SecurityModule,
} from './common/security';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ClubsModule } from './clubs/clubs.module';
import { ClubMembersModule } from './club-members/club-members.module';
import { EventsModule } from './events/events.module';
import { RegistrationsModule } from './registrations/registrations.module';
import { NotificationsModule } from './notifications/notifications.module';
import { UploadsModule } from './uploads/uploads.module';
import { CalendarModule } from './calendar/calendar.module';
import { AdminModule } from './admin/admin.module';
import { AnnouncementsModule } from './announcements/announcements.module';
import { HomeModule } from './home/home.module';
@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    SecurityModule,
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 120 }]),
    ScheduleModule.forRoot(),
    AuthModule,
    UsersModule,
    ClubsModule,
    ClubMembersModule,
    EventsModule,
    RegistrationsModule,
    NotificationsModule,
    UploadsModule,
    CalendarModule,
    AdminModule,
    AnnouncementsModule,
    HomeModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: ClubScopeGuard },
  ],
})
export class AppModule {}
