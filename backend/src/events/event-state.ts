import { EventStatus, RegistrationStatus } from '@prisma/client';
type EventDates = {
  status: EventStatus;
  capacity: number;
  startsAt: Date;
  endsAt: Date;
  registrationDeadline: Date;
};
export function eventState(
  event: EventDates,
  registeredCount: number,
  registration: { id: string; status: RegistrationStatus } | null,
  now: Date,
  cutoffMinutes: number,
) {
  const phase =
    now >= event.endsAt
      ? 'ENDED'
      : now >= event.startsAt
        ? 'ONGOING'
        : 'UPCOMING';
  const active = registration && registration.status !== 'CANCELLED';
  const availableSeats = Math.max(0, event.capacity - registeredCount);
  const open =
    event.status === 'PUBLISHED' &&
    now < event.registrationDeadline &&
    now < event.startsAt &&
    availableSeats > 0;
  const registrationState = active
    ? 'REGISTERED'
    : event.status !== 'PUBLISHED'
      ? 'NOT_PUBLISHED'
      : phase === 'ENDED'
        ? 'ENDED'
        : now >= event.registrationDeadline || now >= event.startsAt
          ? 'DEADLINE_PASSED'
          : availableSeats === 0
            ? 'FULL'
            : registration?.status === 'CANCELLED'
              ? 'CANCELLED_BY_ME'
              : 'OPEN';
  return {
    registeredCount,
    availableSeats,
    phase,
    registrationState,
    serverTime: now.toISOString(),
    registrationId: registration?.id ?? null,
    canCancel:
      !!active &&
      registration.status === 'CONFIRMED' &&
      event.status === 'PUBLISHED' &&
      now.getTime() < event.startsAt.getTime() - cutoffMinutes * 60000,
    canRegister: !active && open,
  };
}
