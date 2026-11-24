import 'dotenv/config';
import { spawnSync } from 'child_process';
const url = process.env.TEST_DATABASE_URL;
if (!url)
  throw new Error(
    'TEST_DATABASE_URL is required; tests never fall back to DATABASE_URL',
  );
const parsed = new URL(url);
if (
  !parsed.pathname.endsWith('_test') ||
  (process.env.DATABASE_URL &&
    new URL(process.env.DATABASE_URL).pathname === parsed.pathname)
)
  throw new Error('Refusing non-isolated test database');
const env = { ...process.env, DATABASE_URL: url, NODE_ENV: 'test' };
for (const args of [
  ['node_modules/typescript/bin/tsc', '-p', 'tsconfig.build.json'],
  ['node_modules/prisma/build/index.js', 'migrate', 'deploy'],
  [
    'node_modules/jest/bin/jest.js',
    '--runInBand',
    '--config',
    'jest-e2e.config.cjs',
  ],
]) {
  if (args[0].includes('jest')) args.push(...process.argv.slice(2));
  const result = spawnSync(process.execPath, args, { env, stdio: 'inherit' });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
