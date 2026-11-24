import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { SchedulerRegistry } from '@nestjs/schedule';
import { AppModule } from '../../dist/src/app.module.js';
import { PrismaService } from '../../dist/src/prisma/prisma.service.js';
import { publicUserSelect } from '../../dist/src/common/security.js';
import { NotificationsService } from '../../dist/src/notifications/notifications.service.js';
import { RegistrationsService } from '../../dist/src/registrations/registrations.service.js';

// Parent kills this actual process after the post-commit notification boundary.
try {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });
  for (const job of app.get(SchedulerRegistry).getCronJobs().values())
    job.stop();
  const notifications = app.get(NotificationsService);
  notifications.notify = async () => {
    process.send?.({ phase: 'notification-attempt' });
    await new Promise(() => {});
  };
  const actor = await app.get(PrismaService).user.findUniqueOrThrow({
    where: { id: process.env.OUTBOX_TEST_USER_ID },
    select: publicUserSelect,
  });
  await app
    .get(RegistrationsService)
    .register(actor, process.env.OUTBOX_TEST_EVENT_ID);
  await app.close();
  process.exit(0);
} catch {
  console.error(
    'Registration crash fixture failed before the notification boundary',
  );
  process.exit(1);
}
