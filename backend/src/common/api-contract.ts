import { OpenAPIObject } from '@nestjs/swagger';
import { SchemaObject } from '@nestjs/swagger/dist/interfaces/open-api-spec.interface';
const str = (nullable = false): SchemaObject => ({
  type: 'string',
  ...(nullable ? { nullable: true } : {}),
});
const uuid = (nullable = false): SchemaObject => ({
  ...str(nullable),
  format: 'uuid',
});
const date = (nullable = false): SchemaObject => ({
  ...str(nullable),
  format: 'date-time',
});
const num = (): SchemaObject => ({ type: 'integer' });
const bool = (): SchemaObject => ({ type: 'boolean' });
const enumeration = (...values: string[]): SchemaObject => ({
  type: 'string',
  enum: values,
});
const ref = (name: string): SchemaObject & { $ref: string } => ({
  $ref: `#/components/schemas/${name}`,
});
const array = (items: SchemaObject): SchemaObject => ({ type: 'array', items });
const object = (
  properties: Record<string, SchemaObject>,
  optional: string[] = [],
): SchemaObject => ({
  type: 'object',
  properties,
  required: Object.keys(properties).filter((k) => !optional.includes(k)),
});
const envelope = (data: SchemaObject): SchemaObject => object({ data });
const paginated = (name: string): SchemaObject =>
  object({ data: array(ref(name)), meta: ref('PaginationMeta') });
export function completeContract(document: OpenAPIObject) {
  const timestamps = { createdAt: date(), updatedAt: date() };
  const category = enumeration(
    'TECHNOLOGY',
    'SCIENCE',
    'CULTURE',
    'SPORTS',
    'SOCIAL',
    'ENTREPRENEURSHIP',
  );
  const schemas: Record<string, SchemaObject> = {
    PaginationMeta: object({
      page: num(),
      limit: { type: 'integer', maximum: 50 },
      total: num(),
      totalPages: num(),
    }),
    ApiError: object({ error: object({ code: str(), message: str() }) }),
    User: object({
      id: uuid(),
      email: { type: 'string', format: 'email' },
      firstName: str(),
      lastName: str(),
      studentId: str(true),
      avatarUrl: str(true),
      role: enumeration('STUDENT', 'CLUB_ADMIN', 'SUPER_ADMIN'),
      isActive: bool(),
      notifyNewEvents: bool(),
      notifyRegistrations: bool(),
      notifyEventUpdates: bool(),
      notifyReminders: bool(),
      pushEnabled: bool(),
      ...timestamps,
    }),
    AuthSession: object({
      user: ref('User'),
      accessToken: str(),
      refreshToken: str(),
      expiresIn: num(),
    }),
    Club: object(
      {
        id: uuid(),
        name: str(),
        description: str(),
        category,
        logoUrl: str(true),
        contactEmail: str(true),
        websiteUrl: str(true),
        socialUrl: str(true),
        status: enumeration('PENDING', 'APPROVED', 'REJECTED'),
        rejectionReason: str(true),
        isFeatured: bool(),
        isFollowed: bool(),
        _count: object({ members: num(), followers: num(), events: num() }),
        ...timestamps,
      },
      ['isFollowed', '_count'],
    ),
    Event: object(
      {
        id: uuid(),
        clubId: uuid(),
        createdById: uuid(),
        title: str(),
        description: str(),
        category,
        posterUrl: str(true),
        location: str(),
        startsAt: date(),
        endsAt: date(),
        registrationDeadline: date(),
        capacity: num(),
        status: enumeration(
          'DRAFT',
          'PENDING_APPROVAL',
          'PUBLISHED',
          'REJECTED',
          'CANCELLED',
        ),
        rejectionReason: str(true),
        revision: num(),
        registeredCount: num(),
        availableSeats: num(),
        phase: enumeration('UPCOMING', 'ONGOING', 'ENDED'),
        registrationState: enumeration(
          'OPEN',
          'FULL',
          'DEADLINE_PASSED',
          'NOT_PUBLISHED',
          'ENDED',
          'REGISTERED',
          'CANCELLED_BY_ME',
        ),
        serverTime: date(),
        registrationId: uuid(true),
        canCancel: bool(),
        canRegister: bool(),
        club: object(
          {
            id: uuid(),
            name: str(),
            logoUrl: str(true),
            status: enumeration('PENDING', 'APPROVED', 'REJECTED'),
          },
          ['status'],
        ),
        ...timestamps,
      },
      ['club'],
    ),
    Registration: object(
      {
        id: uuid(),
        userId: uuid(),
        eventId: uuid(),
        status: enumeration('CONFIRMED', 'ATTENDED', 'CANCELLED'),
        version: num(),
        registeredAt: date(),
        cancelledAt: date(true),
        updatedAt: date(),
        event: ref('Event'),
        user: object({
          id: uuid(),
          firstName: str(),
          lastName: str(),
          email: str(),
          studentId: str(true),
        }),
      },
      ['event', 'user'],
    ),
    ClubMember: object(
      {
        id: uuid(),
        userId: uuid(),
        clubId: uuid(),
        role: enumeration('ADMIN', 'MEMBER'),
        joinedAt: date(),
        user: object({
          id: uuid(),
          firstName: str(),
          lastName: str(),
          avatarUrl: str(true),
          email: str(),
        }),
      },
      ['user'],
    ),
    Notification: object({
      id: uuid(),
      userId: uuid(),
      eventId: uuid(true),
      type: enumeration(
        'NEW_EVENT',
        'REGISTRATION_CONFIRMED',
        'REGISTRATION_CANCELLED',
        'EVENT_UPDATED',
        'REMINDER_24H',
        'REMINDER_1H',
      ),
      title: str(),
      body: str(),
      dedupeKey: str(),
      readAt: date(true),
      createdAt: date(),
    }),
    Announcement: object({
      id: uuid(),
      title: str(),
      body: str(),
      clubId: uuid(true),
      authorId: uuid(),
      createdAt: date(),
    }),
    Upload: object({
      url: { type: 'string', format: 'uri' },
      mimeType: enumeration('image/webp'),
      size: num(),
    }),
    ClubDashboard: object({
      clubId: uuid(),
      counts: object({
        members: num(),
        followers: num(),
        events: num(),
        publishedEvents: num(),
        pendingEvents: num(),
        activeRegistrations: num(),
      }),
      eventFillRates: array(
        object({
          eventId: uuid(),
          title: str(),
          startsAt: date(),
          capacity: num(),
          registeredCount: num(),
          availableSeats: num(),
          fillRate: { type: 'number', minimum: 0, maximum: 1 },
        }),
      ),
    }),
    Dashboard: object({
      counts: object({
        users: num(),
        clubs: num(),
        events: num(),
        registrations: num(),
        pendingClubs: num(),
        pendingEvents: num(),
      }),
      dailyRegistrations: array(
        object({ date: { type: 'string', format: 'date' }, count: num() }),
      ),
      topClubs: array(
        object({ id: uuid(), name: str(), registrations: num() }),
      ),
      fillRates: array(
        object({
          eventId: uuid(),
          title: str(),
          capacity: num(),
          registeredCount: num(),
          fillRate: { type: 'number' },
        }),
      ),
    }),
    Home: object({
      upcomingEvents: paginated('Event'),
      featuredClubs: paginated('Club'),
      announcements: paginated('Announcement'),
      recommendedEvents: paginated('Event'),
    }),
  };
  document.components ??= {};
  document.components.schemas = { ...document.components.schemas, ...schemas };
  for (const [path, item] of Object.entries(document.paths)) {
    for (const method of ['get', 'post', 'patch', 'delete'] as const) {
      const operation = item?.[method];
      if (!operation) continue;
      if (path.endsWith('/calendar.ics') || path.includes('/uploads/files/')) {
        operation.responses['200'] = {
          description: 'Raw file (no JSON envelope)',
          content: {
            [path.endsWith('.ics') ? 'text/calendar' : 'image/webp']: {
              schema: { type: 'string', format: 'binary' },
            },
          },
        };
        continue;
      }
      const list =
        (method === 'get' &&
          [
            '/api/clubs',
            '/api/me/clubs',
            '/api/events',
            '/api/me/registrations',
            '/api/me/notifications',
            '/api/announcements',
            '/api/admin/users',
            '/api/admin/clubs',
            '/api/admin/events',
          ].includes(path)) ||
        (method === 'get' &&
          /\/(members|registrations|events)$/.test(path) &&
          !path.includes('/auth/'));
      let data: SchemaObject;
      if (path === '/api/clubs/{id}/dashboard') data = ref('ClubDashboard');
      else if (path === '/api/home') data = ref('Home');
      else if (path === '/api/admin/dashboard') data = ref('Dashboard');
      else if (path === '/api/uploads/image') data = ref('Upload');
      else if (
        path.includes('/auth/') &&
        ['register', 'login', 'refresh'].some((s) => path.endsWith('/' + s))
      )
        data = ref('AuthSession');
      else if (path.endsWith('/unread-count')) data = object({ count: num() });
      else if (path.endsWith('/read-all')) data = object({ updated: num() });
      else if (path.endsWith('/read')) data = object({ read: bool() });
      else if (path.includes('/device-tokens'))
        data = object({
          [method === 'post' ? 'registered' : 'deleted']: bool(),
        });
      else if (path.endsWith('/logout')) data = object({ loggedOut: bool() });
      else if (path.endsWith('/forgot-password'))
        data = object({ message: str() });
      else if (path.endsWith('/reset-password'))
        data = object({ reset: bool() });
      else if (path.endsWith('/password')) data = object({ changed: bool() });
      else if (path.endsWith('/follow')) data = object({ isFollowed: bool() });
      else if (path.includes('/registrations') && method === 'delete')
        data = ref('Registration');
      else if (method === 'delete') data = object({ deleted: bool() });
      else if (
        path === '/api/me' ||
        path.startsWith('/api/me/notification-preferences') ||
        path.endsWith('/auth/me') ||
        path.startsWith('/api/admin/users')
      )
        data = ref('User');
      else if (path.endsWith('/admins') || path.includes('/members'))
        data = ref('ClubMember');
      else if (path.endsWith('/register') || path.includes('/registrations'))
        data = ref('Registration');
      else if (path.includes('/notifications')) data = ref('Notification');
      else if (path.includes('/announcements')) data = ref('Announcement');
      else if (path.includes('/events')) data = ref('Event');
      else data = ref('Club');
      const name =
        '$ref' in data && typeof data.$ref === 'string'
          ? data.$ref.split('/').pop()!
          : undefined;
      const status =
        method === 'post' &&
        ![
          'login',
          'refresh',
          'logout',
          'forgot-password',
          'reset-password',
        ].some((s) => path.endsWith('/' + s))
          ? '201'
          : '200';
      operation.responses[status] = {
        description: 'Success',
        content: {
          'application/json': {
            schema: list && name ? paginated(name) : envelope(data),
          },
        },
      };
      for (const code of [
        '400',
        '401',
        '403',
        '404',
        '409',
        '413',
        '429',
        '500',
      ])
        operation.responses[code] = {
          description: (
            {
              '400': 'VALIDATION_ERROR',
              '401':
                'UNAUTHORIZED / INVALID_CREDENTIALS / INVALID_REFRESH_TOKEN',
              '403': 'FORBIDDEN',
              '404': 'NOT_FOUND',
              '409':
                'EVENT_FULL / ALREADY_REGISTERED / REGISTRATION_CLOSED / CANCELLATION_NOT_ALLOWED / CONFLICT',
              '413': 'FILE_TOO_LARGE',
              '429': 'RATE_LIMITED',
              '500': 'INTERNAL_ERROR',
            } as Record<string, string>
          )[code],
          content: { 'application/json': { schema: ref('ApiError') } },
        };
      const roles =
        path.startsWith('/api/admin/') ||
        path.endsWith('/approve') ||
        path.endsWith('/reject') ||
        path.endsWith('/status') ||
        (path === '/api/clubs/{id}' && method === 'delete')
          ? 'SUPER_ADMIN'
          : path.endsWith('/register')
            ? 'STUDENT'
            : path === '/api/clubs/{id}/dashboard' ||
                (method === 'post' &&
                  (path === '/api/events' ||
                    path === '/api/clubs' ||
                    path === '/api/announcements')) ||
                (['patch', 'delete'].includes(method) &&
                  (path.startsWith('/api/events/') ||
                    path.startsWith('/api/clubs/'))) ||
                path.includes('/members') ||
                (method === 'patch' &&
                  path.startsWith('/api/registrations/')) ||
                (method === 'get' &&
                  path.startsWith('/api/events/') &&
                  path.endsWith('/registrations'))
              ? 'CLUB_ADMIN (own club) or SUPER_ADMIN'
              : path.startsWith('/api/auth/') && !path.endsWith('/me')
                ? 'Public'
                : 'Any active authenticated user';
      operation.description = `Required roles: ${roles}. See API.md for business rules and retry semantics.`;
    }
  }
  return document;
}
