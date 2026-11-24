import { makeIcs } from '../src/calendar/calendar.module';
describe('calendar serialization', () => {
  it('uses UTC, escapes injected lines, folds UTF-8 without splitting characters', () => {
    const value = makeIcs(
      {
        id: 'event',
        title: 'É'.repeat(100) + ',;\nLOCATION:evil',
        description: 'Line 1\nLine 2',
        location: 'Room A',
        startsAt: new Date('2030-01-01T10:00:00Z'),
        endsAt: new Date('2030-01-01T12:00:00Z'),
      },
      new Date('2029-12-01T00:00:00Z'),
    );
    expect(value).toContain('DTSTART:20300101T100000Z');
    expect(value.replace(/\r\n /g, '')).toContain('\\,\\;\\nLOCATION:evil');
    expect(
      value.split('\r\n').every((line) => Buffer.byteLength(line) <= 75),
    ).toBe(true);
    expect(value.endsWith('\r\n')).toBe(true);
  });
});
