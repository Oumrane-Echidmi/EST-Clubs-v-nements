import {
  Controller,
  Get,
  Module,
  Param,
  ParseUUIDPipe,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiProduces, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { Actor, CurrentUser } from '../common/security';
import { EventsModule } from '../events/events.module';
import { EventsService } from '../events/events.service';
export function escapeIcs(value: string) {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/\r?\n/g, '\\n')
    .replace(/,/g, '\\,')
    .replace(/;/g, '\\;')
    .replace(/\r/g, '');
}
export function foldIcs(line: string) {
  let result = '',
    bytes = 0;
  for (const character of line) {
    const size = Buffer.byteLength(character);
    if (bytes + size > 75) {
      result += '\r\n ';
      bytes = 1;
    }
    result += character;
    bytes += size;
  }
  return result;
}
export function makeIcs(
  event: {
    id: string;
    startsAt: Date;
    endsAt: Date;
    title: string;
    description: string;
    location: string;
  },
  now = new Date(),
) {
  const utc = (value: Date) =>
    value
      .toISOString()
      .replace(/[-:]/g, '')
      .replace(/\.\d{3}/, '');
  return (
    [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//EST//Clubs and Events//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      `UID:${event.id}@est-clubs`,
      `DTSTAMP:${utc(now)}`,
      `DTSTART:${utc(event.startsAt)}`,
      `DTEND:${utc(event.endsAt)}`,
      `SUMMARY:${escapeIcs(event.title)}`,
      `DESCRIPTION:${escapeIcs(event.description)}`,
      `LOCATION:${escapeIcs(event.location)}`,
      'END:VEVENT',
      'END:VCALENDAR',
    ]
      .map(foldIcs)
      .join('\r\n') + '\r\n'
  );
}
@ApiTags('Calendar')
@ApiBearerAuth()
@Controller('events')
export class CalendarController {
  constructor(private events: EventsService) {}
  @Get(':id/calendar.ics') @ApiProduces('text/calendar') async calendar(
    @CurrentUser() actor: Actor,
    @Param('id', ParseUUIDPipe) id: string,
    @Res() response: Response,
  ) {
    const event = await this.events.visibleEvent(actor, id);
    response.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="event-${id}.ics"`,
    );
    response.send(makeIcs(event));
  }
}
@Module({ imports: [EventsModule], controllers: [CalendarController] })
export class CalendarModule {}
