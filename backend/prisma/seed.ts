import 'dotenv/config';
import { PrismaClient, Category, EventStatus, Role } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import bcrypt from 'bcrypt';
import { createHash } from 'crypto';
const db = new PrismaClient({
  adapter: new PrismaPg({
    connectionString: process.env.DATABASE_URL,
    max: 10,
    connectionTimeoutMillis: 5000,
  }),
});
const id = (label: string) => {
  const hex = createHash('sha256')
    .update(`est-development-seed:${label}`)
    .digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
};
async function seed() {
  if (process.env.NODE_ENV === 'production')
    throw new Error('Development seed is forbidden in production');
  const password = process.env.SEED_PASSWORD;
  if (
    !password ||
    !/^(?=.*[A-Za-z])(?=.*[0-9]).{8,72}$/.test(password) ||
    Buffer.byteLength(password) > 72
  )
    throw new Error(
      'Set a strong SEED_PASSWORD (8-72 bytes, letter and number)',
    );
  const passwordHash = await bcrypt.hash(password, 12);
  const users = [
    { email: 'superadmin@est.example.edu', role: Role.SUPER_ADMIN },
    ...[1, 2, 3].map((i) => ({
      email: `clubadmin${i}@est.example.edu`,
      role: Role.CLUB_ADMIN,
    })),
    ...Array.from({ length: 8 }, (_, i) => ({
      email: `student${i + 1}@est.example.edu`,
      role: Role.STUDENT,
    })),
  ];
  for (const [i, user] of users.entries())
    await db.user.upsert({
      where: { email: user.email },
      create: {
        id: id(user.email),
        ...user,
        passwordHash,
        firstName: i > 3 ? 'Student' : 'Administrator',
        lastName: String(i + 1),
        studentId: i > 3 ? `EST-${String(i).padStart(4, '0')}` : undefined,
      },
      update: { passwordHash },
    });
  const categories = Object.values(Category);
  const names = [
    'EST Robotics',
    'EST Science',
    'EST Arts',
    'EST Sports',
    'EST Solidarity',
    'EST Entrepreneurs',
    'Pending Photography Club',
  ];
  for (const [i, name] of names.entries()) {
    const clubId = id(name);
    await db.club.upsert({
      where: { id: clubId },
      create: {
        id: clubId,
        name,
        description: `${name}: campus activities, workshops and student community at EST.`,
        category: categories[i % categories.length],
        status: i === 6 ? 'PENDING' : 'APPROVED',
        isFeatured: i < 3,
      },
      update: {},
    });
    await db.clubMember.upsert({
      where: {
        clubId_userId: { clubId, userId: id(users[1 + (i % 3)].email) },
      },
      create: { clubId, userId: id(users[1 + (i % 3)].email), role: 'ADMIN' },
      update: {},
    });
    for (let j = 4; j < users.length; j++)
      if ((j + i) % 2 === 0 && i < 6)
        await db.clubFollow.upsert({
          where: { clubId_userId: { clubId, userId: id(users[j].email) } },
          create: { clubId, userId: id(users[j].email) },
          update: {},
        });
  }
  const now = Date.now(),
    hours = (n: number) => new Date(now + n * 3600000);
  const titles = [
    'Pending workshop',
    'Rejected proposal',
    'Cancelled meetup',
    'Completed seminar',
    'Ongoing hackathon',
    'Full robotics workshop',
    'Closed registrations',
    'My upcoming event',
    'My cancelled registration',
    'Campus innovation day',
    'Sports tournament',
    'Cultural evening',
    'Community volunteering',
    'Entrepreneurship bootcamp',
    'Science showcase',
  ];
  for (let i = 0; i < 15; i++) {
    const eventId = id(titles[i]);
    const clubId = id(names[i % 6]);
    const status: EventStatus =
      i === 0
        ? 'PENDING_APPROVAL'
        : i === 1
          ? 'REJECTED'
          : i === 2
            ? 'CANCELLED'
            : 'PUBLISHED';
    const start = i === 3 ? -48 : i === 4 ? -1 : (i + 1) * 24;
    await db.event.upsert({
      where: { id: eventId },
      create: {
        id: eventId,
        clubId,
        createdById: id(users[1 + ((i % 6) % 3)].email),
        title: titles[i],
        description: `Discover ${titles[i].toLowerCase()} with fellow EST students. Bring your curiosity and join this campus activity.`,
        category: categories[i % 6],
        location: i % 2 ? 'EST Auditorium' : 'EST Campus - Room A12',
        startsAt: hours(start),
        endsAt: hours(start + 3),
        registrationDeadline: hours(i === 6 ? -2 : start - 2),
        capacity: i === 5 ? 3 : 25 + i * 5,
        status,
        rejectionReason:
          i === 1
            ? 'Please clarify the program and safety arrangements.'
            : null,
      },
      update: {},
    });
    const count = i === 5 ? 3 : i >= 3 ? 2 : 0;
    for (let j = 0; j < count; j++) {
      const userId = id(users[4 + j].email);
      await db.registration.upsert({
        where: { userId_eventId: { userId, eventId } },
        create: {
          id: id(`registration:${i}:${j}`),
          userId,
          eventId,
          status: i === 8 ? 'CANCELLED' : i === 3 ? 'ATTENDED' : 'CONFIRMED',
          cancelledAt: i === 8 ? new Date() : null,
        },
        update: {},
      });
    }
  }
  for (let i = 0; i < 4; i++) {
    await db.announcement.upsert({
      where: { id: id(`announcement:${i}`) },
      create: {
        id: id(`announcement:${i}`),
        title: i === 0 ? 'Welcome to EST Clubs & Events' : `Club news ${i}`,
        body: 'Explore campus activities and register for upcoming events.',
        clubId: i === 0 ? null : id(names[i]),
        authorId: id(users[0].email),
      },
      update: {},
    });
    const userId = id(users[4].email),
      dedupeKey = `seed-notification:${i}`;
    await db.notification.upsert({
      where: { userId_dedupeKey: { userId, dedupeKey } },
      create: {
        userId,
        eventId: id(titles[7]),
        type: 'EVENT_UPDATED',
        title: 'Your campus event',
        body: 'Check the latest event information.',
        dedupeKey,
      },
      update: {},
    });
  }
  console.log(
    'Development seed complete: 12 accounts, 7 clubs, 15 events. Password comes from SEED_PASSWORD.',
  );
}
seed()
  .catch(() => {
    console.error(
      'Seed failed; verify configuration and database availability.',
    );
    process.exitCode = 1;
  })
  .finally(() => db.$disconnect());
