import 'dotenv/config';
import { Global, Module } from '@nestjs/common';
export function validateConfig(env: NodeJS.ProcessEnv) {
  const integer = (name: string, fallback: number, min = 1) => {
    const value = Number(env[name] ?? fallback);
    if (!Number.isSafeInteger(value) || value < min)
      throw new Error(`Invalid ${name}`);
    return value;
  };
  if (!env.DATABASE_URL?.startsWith('postgresql://'))
    throw new Error('DATABASE_URL must be PostgreSQL');
  if (
    !env.JWT_SECRET ||
    env.JWT_SECRET.length < 32 ||
    env.JWT_SECRET.includes('REPLACE_')
  )
    throw new Error('JWT_SECRET must contain at least 32 random characters');
  const origins = (env.CORS_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  for (const origin of origins) {
    if (origin === '*' || new URL(origin).origin !== origin)
      throw new Error('Invalid CORS origin');
  }
  const firebase = [
    env.FIREBASE_PROJECT_ID,
    env.FIREBASE_CLIENT_EMAIL,
    env.FIREBASE_PRIVATE_KEY,
  ];
  if (firebase.some(Boolean) && !firebase.every(Boolean))
    throw new Error('Incomplete Firebase credentials');
  if (env.MAIL_TRANSPORT && !['console', 'smtp'].includes(env.MAIL_TRANSPORT))
    throw new Error('Invalid MAIL_TRANSPORT');
  if (env.MAIL_TRANSPORT === 'smtp' && !env.SMTP_URL)
    throw new Error('SMTP_URL required');
  if (env.NODE_ENV === 'production' && env.MAIL_TRANSPORT !== 'smtp')
    throw new Error('Production requires SMTP');
  const baseUrl = new URL(env.PUBLIC_BASE_URL ?? 'http://localhost:3000');
  const resetUrl = new URL(
    env.RESET_PASSWORD_URL ?? 'http://localhost:8080/reset-password',
  );
  if (
    env.NODE_ENV === 'production' &&
    (baseUrl.protocol !== 'https:' || resetUrl.protocol !== 'https:')
  )
    throw new Error('Production requires HTTPS URLs');
  return {
    databaseUrl: env.DATABASE_URL,
    secret: env.JWT_SECRET,
    port: integer('PORT', 3000),
    origins,
    accessTtl: integer('JWT_ACCESS_TTL_SECONDS', 900),
    refreshDays: integer('REFRESH_TTL_DAYS', 30),
    resetMinutes: integer('RESET_TTL_MINUTES', 30),
    cancellationMinutes: integer('CANCELLATION_CUTOFF_MINUTES', 60, 0),
    baseUrl: baseUrl.origin,
    uploadDir: env.UPLOAD_DIR ?? 'uploads',
    resetUrl: resetUrl.toString(),
    mailTransport: env.MAIL_TRANSPORT ?? 'console',
    smtpUrl: env.SMTP_URL,
    mailFrom: env.MAIL_FROM ?? 'no-reply@example.edu',
    firebase: firebase.every(Boolean)
      ? {
          projectId: firebase[0]!,
          clientEmail: firebase[1]!,
          privateKey: firebase[2]!.replace(/\\n/g, '\n'),
        }
      : null,
  };
}
export const CONFIG = Symbol('CONFIG');
export type Configuration = ReturnType<typeof validateConfig>;
@Global()
@Module({
  providers: [
    { provide: CONFIG, useFactory: () => validateConfig(process.env) },
  ],
  exports: [CONFIG],
})
export class ConfigModule {}
