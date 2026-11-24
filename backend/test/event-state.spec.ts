import { eventState } from '../src/events/event-state';
import { EventStatus, RegistrationStatus } from '@prisma/client';
describe('event eligibility', () => {
  const now = new Date('2030-01-01T10:00:00Z');
  const event = {
    status: EventStatus.PUBLISHED,
    capacity: 5,
    startsAt: new Date('2030-01-02T10:00:00Z'),
    endsAt: new Date('2030-01-02T12:00:00Z'),
    registrationDeadline: new Date('2030-01-02T08:00:00Z'),
  };
  it('calculates availability on server', () =>
    expect(eventState(event, 4, null, now, 60)).toMatchObject({
      availableSeats: 1,
      registrationState: 'OPEN',
      phase: 'UPCOMING',
    }));
  it('reports a full event', () =>
    expect(eventState(event, 5, null, now, 60).registrationState).toBe('FULL'));
  it('uses current registration and cancellation cutoff', () =>
    expect(
      eventState(
        event,
        1,
        { id: 'r', status: RegistrationStatus.CONFIRMED },
        now,
        60,
      ),
    ).toMatchObject({
      registrationId: 'r',
      registrationState: 'REGISTERED',
      canCancel: true,
    }));
  it('rejects cancellation at the cutoff', () =>
    expect(
      eventState(
        event,
        1,
        { id: 'r', status: RegistrationStatus.CONFIRMED },
        new Date('2030-01-02T09:00:00Z'),
        60,
      ).canCancel,
    ).toBe(false));
  it('reports cancelled registration while reopening action', () =>
    expect(
      eventState(
        event,
        0,
        { id: 'r', status: RegistrationStatus.CANCELLED },
        now,
        60,
      ),
    ).toMatchObject({
      registrationState: 'CANCELLED_BY_ME',
      canRegister: true,
    }));
});
